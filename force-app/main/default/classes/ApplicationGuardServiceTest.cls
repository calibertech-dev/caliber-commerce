@IsTest
private class ApplicationGuardServiceTest {
    private static Invoice__c postedInvFromTotal(Decimal total) {
        Invoice__c inv = new Invoice__c(Posting_Status__c='Posted', Status__c='Open', Total_Price__c=total);
        insert inv; return inv;
    }
    private static Invoice__c unpostedInvFromTotal(Decimal total) {
        Invoice__c inv = new Invoice__c(Posting_Status__c='Unposted', Status__c='Draft', Total_Price__c=total);
        insert inv; return inv;
    }
    private static Payment__c makePayment(Decimal amt) {
        Payment__c p = new Payment__c(Amount__c=amt, Status__c='Settled');
        insert p; return p;
    }

    @IsTest static void blocks_unposted_invoice() {
        Invoice__c inv = unpostedInvFromTotal(100);
        Payment__c p = makePayment(500);

        try {
            insert new Payment_Application__c(Payment__c=p.Id, Invoice__c=inv.Id, Amount__c=100, Status__c='Applied');
            System.assert(false, 'Expected guard rejection for unposted invoice');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('Unposted'));
        }
    }

    @IsTest static void blocks_zero_or_negative_amounts() {
        Invoice__c inv = postedInvFromTotal(100);
        Payment__c p = makePayment(500);

        try { insert new Payment_Application__c(Payment__c=p.Id, Invoice__c=inv.Id, Amount__c=0,  Status__c='Applied'); System.assert(false); }
        catch (DmlException e) { System.assert(e.getMessage().contains('greater than 0')); }

        try { insert new Payment_Application__c(Payment__c=p.Id, Invoice__c=inv.Id, Amount__c=-1, Status__c='Applied'); System.assert(false); }
        catch (DmlException e) { System.assert(e.getMessage().contains('greater than 0')); }
    }

    @IsTest static void blocks_overapply_and_allows_exact() {
        Invoice__c inv = postedInvFromTotal(100);
        Payment__c p   = makePayment(500);

        // 1) Over-apply in a single insert → must FAIL
        try {
            insert new Payment_Application__c(
                Payment__c=p.Id, Invoice__c=inv.Id, Amount__c=101, Status__c='Applied'
            );
            System.assert(false, 'Expected guard to block over-apply > Amount Due');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('exceeds the invoice Amount Due'));
        }

        // 2) Exact match → must PASS
        insert new Payment_Application__c(
            Payment__c=p.Id, Invoice__c=inv.Id, Amount__c=100, Status__c='Applied'
        );
    }


    @IsTest static void reduce_existing_application_is_ok() {
        Invoice__c inv = postedInvFromTotal(100);
        Payment__c p = makePayment(500);

        // Insert at 60
        Payment_Application__c pa = new Payment_Application__c(Payment__c=p.Id, Invoice__c=inv.Id, Amount__c=60, Status__c='Applied');
        insert pa;

        // Reducing to 45 must be allowed
        pa.Amount__c = 45;
        update pa;
    }
}
