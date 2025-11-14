@IsTest
private class PaymentUtilizationServiceTest {
    private static Invoice__c postedInvFromTotal(Decimal total) {
        Invoice__c inv = new Invoice__c(Posting_Status__c='Posted', Status__c='Open', Total_Price__c=total);
        insert inv; return inv;
    }

    @IsTest static void utilization_moves_unapplied_to_partial_to_full() {
        Payment__c pay = new Payment__c(Amount__c=100, Status__c='Settled');
        insert pay;

        // Unapplied
        PaymentUtilizationService.recalc(new Set<Id>{pay.Id});
        pay = [SELECT Payment_Utilization__c FROM Payment__c WHERE Id=:pay.Id];
        System.assertEquals('Unapplied', pay.Payment_Utilization__c);

        // Partially
        Invoice__c inv = postedInvFromTotal(100);
        insert new Payment_Application__c(Payment__c=pay.Id, Invoice__c=inv.Id, Amount__c=60, Status__c='Applied');
        PaymentUtilizationService.recalc(new Set<Id>{pay.Id});
        pay = [SELECT Payment_Utilization__c FROM Payment__c WHERE Id=:pay.Id];
        System.assertEquals('Partially Applied', pay.Payment_Utilization__c);

        // Fully
        insert new Payment_Application__c(Payment__c=pay.Id, Invoice__c=inv.Id, Amount__c=40, Status__c='Applied');
        PaymentUtilizationService.recalc(new Set<Id>{pay.Id});
        pay = [SELECT Payment_Utilization__c FROM Payment__c WHERE Id=:pay.Id];
        System.assertEquals('Fully Applied', pay.Payment_Utilization__c);
    }
}
