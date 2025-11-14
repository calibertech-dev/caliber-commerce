public with sharing class DepositPolicyService {
    // =========================
    // Config / Field APIs
    // =========================
    private static final String F_PROPOSAL_TOTAL      = 'Total_Amount__c';
    private static final String F_PROPOSAL_SUBTOTAL   = 'Subtotal__c';
    private static final String F_PROPOSAL_BU         = 'Business_Unit__c';   // Lookup(Id)
    private static final String F_PROPOSAL_ACCT       = 'Account__c';         // Lookup(Id)
    private static final String F_PROPOSAL_NAME       = 'Name';
    private static final String F_PROPOSAL_GROUPKEY   = 'Billing_Group_Key__c';
    private static final String F_PROPOSAL_PUBHASH    = 'Public_Hash__c';

    // =========================
    // Public DTO
    // =========================
    public class PolicyResult {
        @AuraEnabled public Boolean found;
        @AuraEnabled public Id       proposalId;
        @AuraEnabled public Decimal  basisAmount;
        @AuraEnabled public String   basis;                 // "Total" | "Subtotal"
        @AuraEnabled public Decimal  depositPercent;        // 20 = 20%
        @AuraEnabled public Decimal  depositAmount;         // currency
        @AuraEnabled public Decimal  retainagePercent;      // optional
        @AuraEnabled public String   businessUnitId;
        @AuraEnabled public String   policyDeveloperName;
        @AuraEnabled public String   policyLabel;
        @AuraEnabled public String   reason;
    }

    // ========== Test hooks
    @TestVisible private static List<Deposit_Policy__mdt> policyOverride;
    @TestVisible private static Boolean dryRun = false;

    // =========================
    // Public API
    // =========================
    public static PolicyResult applyPolicy(Id proposalId, Boolean createDeposit) {
        SObject prop = [
            SELECT Id, Account__c, Business_Unit__c, Name,
                   Total_Amount__c, Subtotal__c,
                   Billing_Group_Key__c, Public_Hash__c
            FROM Proposal__c
            WHERE Id = :proposalId
            LIMIT 1
        ];
        PolicyResult res = resolvePolicyInternal(prop);
        if (!res.found) return res;

        if (createDeposit && !dryRun) {
            insert buildDepositRecord(prop, res);
        }
        return res;
    }

    public static PolicyResult previewPolicy(Id proposalId) {
        SObject prop = [
            SELECT Id, Account__c, Business_Unit__c, Name,
                   Total_Amount__c, Subtotal__c,
                   Billing_Group_Key__c, Public_Hash__c
            FROM Proposal__c
            WHERE Id = :proposalId
            LIMIT 1
        ];
        return resolvePolicyInternal(prop);
    }

    // =========================
    // Invocable for Flow (optional)
    // =========================
    public class ApplyInput {
        @InvocableVariable(required=true) public Id proposalId;
        @InvocableVariable public Boolean createDeposit = true;
    }
    public class ApplyOutput {
        @InvocableVariable public Boolean depositCreated;
        @InvocableVariable public Decimal depositAmount;
        @InvocableVariable public Decimal depositPercent;
        @InvocableVariable public String  basis;
        @InvocableVariable public String  policyName;
        @InvocableVariable public String  message;
    }

    @InvocableMethod(label='Apply Deposit Policy' description='Resolve Deposit Policy CMDT and optionally create Deposit__c')
    public static List<ApplyOutput> invocableApply(List<ApplyInput> inputs) {
        List<ApplyOutput> outs = new List<ApplyOutput>();
        for (ApplyInput inRec : inputs) {
            ApplyOutput out = new ApplyOutput();
            try {
                PolicyResult pr = applyPolicy(inRec.proposalId, (inRec.createDeposit == null ? true : inRec.createDeposit));
                out.depositCreated = pr.found && !dryRun && (inRec.createDeposit == null || inRec.createDeposit);
                out.depositAmount  = pr.depositAmount;
                out.depositPercent = pr.depositPercent;
                out.basis          = pr.basis;
                out.policyName     = pr.policyLabel;
                out.message        = pr.found ? 'Policy applied' : 'No matching policy';
            } catch (Exception e) {
                out.depositCreated = false;
                out.message = 'Error: ' + e.getMessage();
            }
            outs.add(out);
        }
        return outs;
    }

    // =========================
    // Internals
    // =========================
    private static PolicyResult resolvePolicyInternal(SObject proposal) {
        PolicyResult res = new PolicyResult();
        res.proposalId = (Id)proposal.get('Id');

        Decimal total    = (Decimal) proposal.get(F_PROPOSAL_TOTAL);
        Decimal subtotal = (Decimal) proposal.get(F_PROPOSAL_SUBTOTAL);

        // Initial "generic" basis: prefer Total if present, else Subtotal
        Boolean useTotal = (total != null);
        res.basisAmount  = (useTotal ? (total == null ? 0 : total)
                                    : (subtotal == null ? 0 : subtotal));
        res.basis        = useTotal ? 'Total' : 'Subtotal';

        Id buLookupId = (Id) proposal.get(F_PROPOSAL_BU);
        String buIdStr = buLookupId == null ? null : (String)buLookupId;

        List<Deposit_Policy__mdt> policies = (policyOverride != null)
            ? policyOverride
            : [
                SELECT DeveloperName, Label,
                    Is_Active__c, Basis__c,
                    Business_Unit_Id__c, Deposit_Percent__c,
                    Min_Amount__c, Max_Amount__c,
                    Priority__c, Retainage_Percent__c
                FROM Deposit_Policy__mdt
                WHERE Is_Active__c = true
                ORDER BY Priority__c DESC, Min_Amount__c DESC
            ];

        Deposit_Policy__mdt chosen;

        for (Deposit_Policy__mdt p : policies) {
            // BU match first
            Boolean buMatch = (String.isBlank(p.Business_Unit_Id__c)
                            || (buIdStr != null && p.Business_Unit_Id__c == buIdStr));
            if (!buMatch) continue;

            // Determine requested basis (policy wins if it specifies one)
            String requestedBasis = String.isBlank(p.Basis__c) ? res.basis : p.Basis__c;

            // Compute candidate basis amount with fallback between Total/Subtotal
            Decimal candidateAmount;
            if (requestedBasis == 'Total') {
                // Prefer Total; fall back to Subtotal if Total is null
                candidateAmount = (total != null)
                    ? total
                    : (subtotal != null ? subtotal : 0);
            } else if (requestedBasis == 'Subtotal') {
                // Prefer Subtotal; fall back to Total if Subtotal is null
                candidateAmount = (subtotal != null)
                    ? subtotal
                    : (total != null ? total : 0);
            } else {
                // Weird/unsupported value: fall back to current res basis/amount
                requestedBasis = res.basis;
                candidateAmount = res.basisAmount;
            }

            // Range check against the candidate amount
            Decimal minAmt = (p.Min_Amount__c == null ? 0 : p.Min_Amount__c);
            Decimal maxAmt = p.Max_Amount__c;
            Boolean inRange = (candidateAmount >= minAmt) &&
                            (maxAmt == null || candidateAmount <= maxAmt);
            if (!inRange) continue;

            // This policy wins
            chosen = p;
            res.basis       = requestedBasis;   // <- respect policy Basis__c
            res.basisAmount = candidateAmount;  // <- amount from chosen basis with fallback
            break;
        }

        if (chosen == null) {
            res.found = false;
            res.reason = 'No active policy matched BU and amount range';
            return res;
        }

        res.found               = true;
        res.policyDeveloperName = chosen.DeveloperName;
        res.policyLabel         = chosen.Label;
        res.businessUnitId      = chosen.Business_Unit_Id__c;
        res.depositPercent      = (chosen.Deposit_Percent__c == null ? 0 : chosen.Deposit_Percent__c);
        res.retainagePercent    = (chosen.Retainage_Percent__c == null ? 0 : chosen.Retainage_Percent__c);
        res.depositAmount       = roundCurrency(res.basisAmount * (res.depositPercent / 100));
        res.reason              = 'Matched ' + res.policyDeveloperName +
                                ' at ' + res.depositPercent + '% on ' + res.basis;
        return res;
    }


    private static Decimal roundCurrency(Decimal d) {
        return (d == null) ? 0 : d.setScale(2, System.RoundingMode.HALF_UP);
    }

    private static Deposit__c buildDepositRecord(SObject proposal, PolicyResult res) {
        Deposit__c d = new Deposit__c();
        d.Proposal__c          = (Id)proposal.get('Id');
        d.Account__c           = (Id)proposal.get(F_PROPOSAL_ACCT);
        d.Business_Unit__c     = (Id)proposal.get(F_PROPOSAL_BU);
        d.Policy_Name__c       = res.policyDeveloperName;
        d.Basis__c             = res.basis;               // "Total"|"Subtotal"
        d.Percent__c           = res.depositPercent;      // 20 => 20%
        d.Amount__c            = res.depositAmount;       // currency
        d.Status__c            = 'Draft';                 // Draft | Paid | Applied | Refunded
        d.Description__c       = 'Deposit for ' + (String)proposal.get(F_PROPOSAL_NAME);
        d.Billing_Group_Key__c = (String)proposal.get(F_PROPOSAL_GROUPKEY);
        // Inherit or generate a public hash
        // d.Public_Hash__c    = (String)proposal.get(F_PROPOSAL_PUBHASH);
        d.Public_Hash__c       = UrlTokenService.makeUrlSafeToken(22);
        return d;
    }
}
