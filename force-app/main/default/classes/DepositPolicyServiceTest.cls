@IsTest
private class DepositPolicyServiceTest {
    @IsTest
    static void preview_and_apply_policy_works() {
        // Arrange
        Account a = new Account(Name='Acme'); insert a;
        Legal_Entity__c le = new Legal_Entity__c(Name = 'Test Legal Entity'); 
        insert le;

        Business_Unit__c bu = new Business_Unit__c(
            Name='CHS',
            Customer_Service_Email__c='test@gmail.com',
            Customer_Service_Phone__c='555-555-5555',
            Short_Code__c='CHS',
            Legal_Entity__c = le.Id
            ); 
        insert bu;

        Proposal__c p = new Proposal__c(
            Account__c = a.Id,
            Business_Unit__c = bu.Id,
            Subtotal__c = 6000,
            Billing_Group_Key__c = 'BGK-001',
            Public_Hash__c = 'PHASH-001'
        );
        insert p;

        // In-memory policy override (no CMDT DML)
        DepositPolicyService.policyOverride = new List<Deposit_Policy__mdt>{
            mockPolicy('Global_20pct_Over_2000', 'Total', null, 2000, 4999.99, 20, 10, 10),
            mockPolicy('Global_30pct_Over_5000', 'Total', null, 5000, null,   30, 20,  0)
        };

        // Act: preview
        DepositPolicyService.dryRun = true;
        DepositPolicyService.PolicyResult pr = DepositPolicyService.previewPolicy(p.Id);

        // Assert: preview
        System.assertEquals(true, pr.found, 'Expected a policy match; DTO=' + JSON.serialize(pr));
        System.assertEquals('Total', pr.basis, 'Basis should be "Total" when policy requests it and total/subtotal logic picks available basis. DTO=' + JSON.serialize(pr));
        System.assertEquals(30, pr.depositPercent, 'Expected 30% policy to match. DTO=' + JSON.serialize(pr));
        System.assertEquals(1800, pr.depositAmount, 'Expected 30% of 6000 = 1800. DTO=' + JSON.serialize(pr));

        // Act: apply (creates Deposit)
        DepositPolicyService.dryRun = false;
        try {
            DepositPolicyService.applyPolicy(p.Id, true);
        } catch (Exception e) {
            System.assert(false, 'applyPolicy threw: ' + e.getTypeName() + ': ' + e.getMessage() + '\nStack: ' + e.getStackTraceString());
        }

        // Assert: deposit persisted
        Deposit__c dep = [
            SELECT Amount__c, Percent__c, Status__c, Basis__c,
                   Policy_Name__c, Proposal__c, Billing_Group_Key__c, Public_Hash__c
            FROM Deposit__c WHERE Proposal__c = :p.Id LIMIT 1
        ];
        System.assertEquals(1800, dep.Amount__c, 'Deposit amount mismatch');
        System.assertEquals(30, dep.Percent__c, 'Deposit percent mismatch');
        System.assertEquals('Draft', dep.Status__c, 'Status mismatch');
        System.assertEquals('Total', dep.Basis__c, 'Basis mismatch');
        System.assertEquals('BGK-001', dep.Billing_Group_Key__c, 'Group key mismatch');
        System.assertNotEquals(null, dep.Public_Hash__c, 'Public hash should be generated');

        // Cleanup override
        DepositPolicyService.policyOverride = null;
    }

    private static Deposit_Policy__mdt mockPolicy(
        String devName, String basis, String buId, Decimal minAmt, Decimal maxAmt,
        Decimal pct, Integer priority, Decimal retainagePct
    ) {
        Deposit_Policy__mdt m = new Deposit_Policy__mdt();
        m.DeveloperName        = devName;
        m.Label                = devName;
        m.Is_Active__c         = true;
        m.Basis__c             = basis;
        m.Business_Unit_Id__c  = buId;
        m.Min_Amount__c        = minAmt;
        m.Max_Amount__c        = maxAmt;
        m.Deposit_Percent__c   = pct;       // whole-number percent
        m.Priority__c          = priority;
        m.Retainage_Percent__c = retainagePct;
        return m;
    }
}
