@IsTest
private class DepositPolicyService_Tests {
    @IsTest
    static void preview_and_apply_policy_works() {
        Account a = new Account(Name='Acme'); insert a;
        Business_Unit__c bu = new Business_Unit__c(Name='CHS'); insert bu;

        Proposal__c p = new Proposal__c(
            Name='P-001',
            Account__c = a.Id,
            Business_Unit__c = bu.Id,
            Total_Amount__c = 6000,
            Subtotal__c = 6000,
            Billing_Group_Key__c = 'BGK-001',
            Public_Hash__c = 'PHASH-001'
        );
        insert p;

        DepositPolicyService.policyOverride = new List<Deposit_Policy__mdt>{
            mockPolicy('Global_20pct_Over_2000', 'Total', null, 2000, 4999.99, 20, 10, 10),
            mockPolicy('Global_30pct_Over_5000', 'Total', null, 5000, null,   30,  20,  0)
        };

        // Preview
        DepositPolicyService.dryRun = true;
        var pr = DepositPolicyService.previewPolicy(p.Id);
        System.assertEquals(true, pr.found);
        System.assertEquals(30, pr.depositPercent);
        System.assertEquals(1800, pr.depositAmount);

        // Apply
        DepositPolicyService.dryRun = false;
        DepositPolicyService.applyPolicy(p.Id, true);

        Deposit__c dep = [
            SELECT Amount__c, Percent__c, Status__c, Basis__c,
                   Policy_Name__c, Proposal__c, Billing_Group_Key__c, Public_Hash__c
            FROM Deposit__c WHERE Proposal__c = :p.Id LIMIT 1
        ];
        System.assertEquals(1800, dep.Amount__c);
        System.assertEquals(30, dep.Percent__c);
        System.assertEquals('Draft', dep.Status__c);
        System.assertEquals('Total', dep.Basis__c);
        System.assertEquals('BGK-001', dep.Billing_Group_Key__c);
        System.assertNotEquals(null, dep.Public_Hash__c);

        DepositPolicyService.policyOverride = null;
    }

    private static Deposit_Policy__mdt mockPolicy(
        String devName, String basis, String buId, Decimal minAmt, Decimal maxAmt,
        Decimal pct, Integer priority, Decimal retainagePct
    ) {
        Deposit_Policy__mdt m = new Deposit_Policy__mdt();
        m.DeveloperName         = devName;
        m.Label                 = devName;
        m.Active__c             = true;
        m.Basis__c              = basis;
        m.Business_Unit_Id__c   = buId;
        m.Min_Amount__c         = minAmt;
        m.Max_Amount__c         = maxAmt;
        m.Deposit_Percent__c    = pct;       // whole-number percent
        m.Priority__c           = priority;
        m.Retainage_Percent__c  = retainagePct;
        return m;
    }
}