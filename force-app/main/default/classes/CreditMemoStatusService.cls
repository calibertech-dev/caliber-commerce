public with sharing class CreditMemoStatusService {
    public static void recalc(Set<Id> cmIds) {
        if (cmIds == null || cmIds.isEmpty()) return;
        List<Credit_Memo__c> ups = new List<Credit_Memo__c>();
        for (Credit_Memo__c cm : [
            SELECT Id, Total_Amount__c, Remaining_Amount__c, Status__c
            FROM Credit_Memo__c WHERE Id IN :cmIds
        ]) {
            Decimal total = cm.Total_Amount__c == null ? 0 : cm.Total_Amount__c;
            Decimal rem   = cm.Remaining_Amount__c == null ? 0 : cm.Remaining_Amount__c;
            String next   = (rem <= 0) ? 'Applied' : (rem < total ? 'Partially Applied' : 'Open');
            if (cm.Status__c != next) ups.add(new Credit_Memo__c(Id=cm.Id, Status__c=next));
        }
        if (!ups.isEmpty()) update ups;
    }
}
