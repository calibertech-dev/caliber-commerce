public with sharing class PaymentUtilizationService {
    public static void recalc(Set<Id> paymentIds) {
        if (paymentIds == null || paymentIds.isEmpty()) return;
        List<Payment__c> ups = new List<Payment__c>();
        for (Payment__c p : [
            SELECT Id, Amount__c, Remaining_Amount__c, Payment_Utilization__c
            FROM Payment__c WHERE Id IN :paymentIds
        ]) {
            Decimal total = p.Amount__c == null ? 0 : p.Amount__c;
            Decimal rem   = p.Remaining_Amount__c == null ? 0 : p.Remaining_Amount__c;
            String util   = (rem <= 0) ? 'Fully Applied' : (rem < total ? 'Partially Applied' : 'Unapplied');
            if (p.Payment_Utilization__c != util) {
                ups.add(new Payment__c(Id=p.Id, Payment_Utilization__c=util));
            }
        }
        if (!ups.isEmpty()) update ups;
    }
}
