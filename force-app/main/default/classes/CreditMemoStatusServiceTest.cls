@IsTest
private class CreditMemoStatusServiceTest {
    private static Invoice__c postedInvFromTotal(Decimal total) {
        Invoice__c inv = new Invoice__c(Posting_Status__c='Posted', Status__c='Open', Total_Price__c=total);
        insert inv; return inv;
    }
    private static Credit_Memo__c creditMemoWithTotal(Decimal total) {
        Credit_Memo__c cm = new Credit_Memo__c(Status__c='Open');
        insert cm;
        insert new Credit_Memo_Line__c(Credit_Memo__c=cm.Id, Quantity__c=1, Unit_Price__c=total);
        return cm;
    }

    @IsTest static void status_moves_open_to_partial_to_applied() {
        Credit_Memo__c cm = creditMemoWithTotal(150);
        CreditMemoStatusService.recalc(new Set<Id>{cm.Id});
        cm = [SELECT Status__c FROM Credit_Memo__c WHERE Id=:cm.Id];
        System.assertEquals('Open', cm.Status__c);

        Invoice__c inv = postedInvFromTotal(200);
        insert new Credit_Memo_Application__c(Credit_Memo__c=cm.Id, Invoice__c=inv.Id, Amount__c=140, Status__c='Applied');
        CreditMemoStatusService.recalc(new Set<Id>{cm.Id});
        cm = [SELECT Status__c FROM Credit_Memo__c WHERE Id=:cm.Id];
        System.assertEquals('Partially Applied', cm.Status__c);

        insert new Credit_Memo_Application__c(Credit_Memo__c=cm.Id, Invoice__c=inv.Id, Amount__c=10, Status__c='Applied');
        CreditMemoStatusService.recalc(new Set<Id>{cm.Id});
        cm = [SELECT Status__c FROM Credit_Memo__c WHERE Id=:cm.Id];
        System.assertEquals('Applied', cm.Status__c);
    }
}
