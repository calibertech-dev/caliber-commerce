@IsTest
private class DepositUtilizationServiceTest {
    private static Invoice__c postedInvFromTotal(Decimal total) {
        Invoice__c inv = new Invoice__c(Posting_Status__c='Posted', Status__c='Open', Total_Price__c=total);
        insert inv; return inv;
    }

    @IsTest static void utilization_moves_unapplied_to_partial_to_full() {
        Deposit__c dep = new Deposit__c(Amount__c=200, Status__c='Received');
        insert dep;

        DepositUtilizationService.recalc(new Set<Id>{dep.Id});
        dep = [SELECT Deposit_Utilization__c FROM Deposit__c WHERE Id=:dep.Id];
        System.assertEquals('Unapplied', dep.Deposit_Utilization__c);

        Invoice__c inv = postedInvFromTotal(200);
        insert new Deposit_Application__c(Deposit__c=dep.Id, Invoice__c=inv.Id, Amount__c=75, Status__c='Applied');
        DepositUtilizationService.recalc(new Set<Id>{dep.Id});
        dep = [SELECT Deposit_Utilization__c FROM Deposit__c WHERE Id=:dep.Id];
        System.assertEquals('Partially Applied', dep.Deposit_Utilization__c);

        insert new Deposit_Application__c(Deposit__c=dep.Id, Invoice__c=inv.Id, Amount__c=125, Status__c='Applied');
        DepositUtilizationService.recalc(new Set<Id>{dep.Id});
        dep = [SELECT Deposit_Utilization__c FROM Deposit__c WHERE Id=:dep.Id];
        System.assertEquals('Fully Applied', dep.Deposit_Utilization__c);
    }
}
