public with sharing class DepositUtilizationService {
    public static void recalc(Set<Id> depositIds) {
        if (depositIds == null || depositIds.isEmpty()) return;
        List<Deposit__c> ups = new List<Deposit__c>();
        for (Deposit__c d : [
            SELECT Id, Amount__c, Remaining_Amount__c, Deposit_Utilization__c
            FROM Deposit__c WHERE Id IN :depositIds
        ]) {
            Decimal total = d.Amount__c == null ? 0 : d.Amount__c;
            Decimal rem   = d.Remaining_Amount__c == null ? 0 : d.Remaining_Amount__c;
            String util   = (rem <= 0) ? 'Fully Applied' : (rem < total ? 'Partially Applied' : 'Unapplied');
            if (d.Deposit_Utilization__c != util) {
                ups.add(new Deposit__c(Id=d.Id, Deposit_Utilization__c=util));
            }
        }
        if (!ups.isEmpty()) update ups;
    }
}
