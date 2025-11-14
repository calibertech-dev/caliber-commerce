@IsTest
private class ApplicationNamingTest {
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

    @IsTest static void payment_application_name_uses_parent_name_and_count() {
        Payment__c p = new Payment__c(Amount__c=100, Status__c='Settled');
        insert p; p = [SELECT Id, Name FROM Payment__c WHERE Id=:p.Id];

        Invoice__c inv = postedInvFromTotal(100);

        Payment_Application__c a1 = new Payment_Application__c(Payment__c=p.Id, Invoice__c=inv.Id, Amount__c=10, Status__c='Applied');
        insert a1; a1 = [SELECT Name FROM Payment_Application__c WHERE Id=:a1.Id];
        System.assert(a1.Name.startsWith(p.Name + '-'));

        Payment_Application__c a2 = new Payment_Application__c(Payment__c=p.Id, Invoice__c=inv.Id, Amount__c=5, Status__c='Applied');
        insert a2; a2 = [SELECT Name FROM Payment_Application__c WHERE Id=:a2.Id];
        System.assert(a2.Name.startsWith(p.Name + '-'));
    }

    @IsTest static void deposit_and_creditmemo_application_naming() {
        Deposit__c d = new Deposit__c(Amount__c=200, Status__c='Received');
        insert d; d = [SELECT Id, Name FROM Deposit__c WHERE Id=:d.Id];

        Credit_Memo__c cm = creditMemoWithTotal(100);
        cm = [SELECT Id, Name FROM Credit_Memo__c WHERE Id=:cm.Id];

        Invoice__c inv = postedInvFromTotal(200);

        Deposit_Application__c da = new Deposit_Application__c(Deposit__c=d.Id, Invoice__c=inv.Id, Amount__c=50, Status__c='Applied');
        insert da; da = [SELECT Name FROM Deposit_Application__c WHERE Id=:da.Id];
        System.assert(da.Name.startsWith(d.Name + '-'));

        Credit_Memo_Application__c ca = new Credit_Memo_Application__c(Credit_Memo__c=cm.Id, Invoice__c=inv.Id, Amount__c=20, Status__c='Applied');
        insert ca; ca = [SELECT Name FROM Credit_Memo_Application__c WHERE Id=:ca.Id];
        System.assert(ca.Name.startsWith(cm.Name + '-'));
    }
}
