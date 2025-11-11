public with sharing class DepositPolicyService {
    // =========================
    // Config / Field Conventions
    // =========================
    // Adjust these if your Proposal field APIs differ.
    private static final String F_PROPOSAL_TOTAL  = 'Total_Amount__c';   // fallback to Subtotal if missing
    private static final String F_PROPOSAL_SUBTOT = 'Subtotal__c';
    private static final String F_PROPOSAL_BU     = 'Business_Unit__c';  // Lookup(Id)
    private static final String F_PROPOSAL_ACCT   = 'Account__c';        // Lookup(Id)
    private static final String F_PROPOSAL_NAME   = 'Name';

    // =========================
    // Public DTOs
    // =========================
    public class PolicyResult {
        @AuraEnabled public Boolean found;
        @AuraEnabled public Id       proposalId;
        @AuraEnabled public Decimal  basisAmount;           // Total or Subtotal value used
        @AuraEnabled public String   basis;                 // "Total" | "Subtotal"
        @AuraEnabled public Decimal  depositPercent;        // e.g., 20
        @AuraEnabled public Decimal  depositAmount;         // currency
        @AuraEnabled public Decimal  retainagePercent;      // e.g., 10 (optional)
        @AuraEnabled public String   businessUnitId;        // Id stored in CMDT
        @AuraEnabled public String   policyDeveloperName;   // CMDT record name
        @AuraEnabled public String   policyLabel;           // CMDT label
        @AuraEnabled public String   reason;                // why/which rule matched
    }

    // ==========
    // Test hooks
    // ==========
    @TestVisible private static List<Deposit_Policy__mdt> policyOverride; // If set, use these instead of SOQL
    @TestVisible private static Boolean dryRun = false; // If true, skip creating Deposit__c

    // =========================
    // Public entry points
    // =========================

    /** Resolve policy and (optionally) create a Deposit__c record. */
    public static PolicyResult applyPolicy(Id proposalId, Boolean createDeposit) {
        SObject prop = [
            SELECT Id, AccountId, Business_Unit__c, Name,
                   Total_Amount__c, Subtotal__c
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

    /** Resolve policy only (no DML). */
    public static PolicyResult previewPolicy(Id proposalId) {
        SObject prop = [
            SELECT Id, AccountId, Business_Unit__c, Name,
                   Total_Amount__c, Subtotal__c
            FROM Proposal__c
            WHERE Id = :proposalId
            LIMIT 1
        ];
        return resolvePolicyInternal(prop);
    }

    // =========================
    // Invocable (for Flows)
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

    @InvocableMethod(label='Apply Deposit Policy' description='Resolves Deposit Policy CMDT for a Proposal and (optionally) creates Deposit__c')
    public static List<ApplyOutput> invocableApply(List<ApplyInput> inputs) {
        List<ApplyOutput> outs = new List<ApplyOutput>();
        for (ApplyInput in : inputs) {
            ApplyOutput out = new ApplyOutput();
            try {
                PolicyResult pr = applyPolicy(in.proposalId, /*createDeposit*/ (in.createDeposit == null ? true : in.createDeposit));
                out.depositCreated = pr.found && !dryRun && (in.createDeposit == null || in.createDeposit);
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

        // Basis amount selection
        Decimal total    = (Decimal) proposal.get(F_PROPOSAL_TOTAL);
        Decimal subtotal = (Decimal) proposal.get(F_PROPOSAL_SUBTOT);
        Boolean hasTotal = (total != null);
        Boolean useTotal = hasTotal; // prefer Total if present; else Subtotal
        res.basisAmount  = useTotal ? (total == null ? 0 : total) : (subtotal == null ? 0 : subtotal);
        res.basis        = useTotal ? 'Total' : 'Subtotal';

        // BU Id on Proposal (Lookup → Id), convert to 18-char string to match CMDT text
        Id buLookupId = (Id) proposal.get(F_PROPOSAL_BU);
        String buIdStr = buLookupId == null ? null : (String)buLookupId;

        // Load candidate policies
        List<Deposit_Policy__mdt> policies = (policyOverride != null)
            ? policyOverride
            : [
                SELECT DeveloperName, Label,
                       Active__c, Basis__c,
                       Business_Unit_Id__c,
                       Deposit_Percent__c,
                       Min_Amount__c, Max_Amount__c,
                       Priority__c, Retainage_Percent__c
                FROM Deposit_Policy__mdt
                WHERE Active__c = true
                ORDER BY Priority__c DESC, Min_Amount__c DESC
              ];

        Deposit_Policy__mdt chosen;
        for (Deposit_Policy__mdt p : policies) {
            // BU match: exact BU id OR global (blank)
            Boolean buMatch = (String.isBlank(p.Business_Unit_Id__c) || (buIdStr != null && p.Business_Unit_Id__c == buIdStr));
            if (!buMatch) continue;

            // Amount range
            Decimal minAmt = p.Min_Amount__c == null ? 0 : p.Min_Amount__c;
            Decimal maxAmt = p.Max_Amount__c;
            Boolean inRange = (res.basisAmount >= minAmt) && (maxAmt == null || res.basisAmount <= maxAmt);
            if (!inRange) continue;

            // Basis override at policy level (optional)
            String basis = String.isBlank(p.Basis__c) ? res.basis : p.Basis__c;
            if (basis != res.basis) {
                // recompute basisAmount if needed
                if (basis == 'Subtotal' && subtotal != null) {
                    res.basis = 'Subtotal';
                    res.basisAmount = subtotal;
                } else if (basis == 'Total' && total != null) {
                    res.basis = 'Total';
                    res.basisAmount = total;
                }
            }
            chosen = p;
            break; // thanks to ORDER BY, first match wins
        }

        if (chosen == null) {
            res.found = false;
            res.reason = 'No active policy matched BU and amount range';
            return res;
        }

        res.found            = true;
        res.policyDeveloperName = chosen.DeveloperName;
        res.policyLabel      = chosen.Label;
        res.businessUnitId   = chosen.Business_Unit_Id__c;
        res.depositPercent   = (chosen.Deposit_Percent__c == null ? 0 : chosen.Deposit_Percent__c);
        res.retainagePercent = (chosen.Retainage_Percent__c == null ? 0 : chosen.Retainage_Percent__c);
        res.depositAmount    = roundCurrency(res.basisAmount * (res.depositPercent / 100));

        res.reason = 'Matched ' + res.policyDeveloperName + ' at ' + res.depositPercent + '% on ' + res.basis;
        return res;
    }

    private static Decimal roundCurrency(Decimal d) {
        return (d == null) ? 0 : d.setScale(2, System.RoundingMode.HALF_UP);
    }

    private static Deposit__c buildDepositRecord(SObject proposal, PolicyResult res) {
        Deposit__c d = new Deposit__c();
        d.Proposal__c       = (Id)proposal.get('Id');
        d.Account__c        = (Id)proposal.get(F_PROPOSAL_ACCT);
        d.Business_Unit__c  = (Id)proposal.get(F_PROPOSAL_BU);
        d.Policy_Name__c    = res.policyDeveloperName; // Text field to snapshot
        d.Basis__c          = res.basis;               // Picklist (Total/Subtotal)
        d.Percent__c        = res.depositPercent;      // Number(5,2)
        d.Amount__c         = res.depositAmount;       // Currency(16,2)
        d.Status__c         = 'Planned';               // Planned | Paid | Applied | Refunded
        d.Description__c    = 'Deposit for ' + (String)proposal.get(F_PROPOSAL_NAME);
        return d;
    }
}
