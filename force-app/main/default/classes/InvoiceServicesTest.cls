@IsTest
private class InvoiceServicesTest {

    private static Invoice__c mk(String terms, String postingStatus, Date invoiceDate, Date dueDate) {
        Invoice__c inv = new Invoice__c();
        inv.Terms__c = terms;
        inv.Posting_Status__c = postingStatus;
        inv.Invoice_Date__c = invoiceDate;
        inv.Due_Date__c = dueDate;
        // Add any required fields your object enforces here.
        return inv;
    }

    @IsTest
    static void insert_net30_sets_due_from_today_when_no_invoice_date() {
        Test.setFixedSearchResults(new Id[]{}); // keep test deterministic
        Test.startTest();
        Date today = Date.today();

        Invoice__c inv = mk('Net 30', 'Unposted', null, null);
        insert inv;

        Invoice__c got = [SELECT Terms__c, Invoice_Date__c, Due_Date__c FROM Invoice__c WHERE Id = :inv.Id];
        System.assertEquals('Net 30', got.Terms__c);
        System.assertEquals(null, got.Invoice_Date__c, 'Invoice date should not be set on insert when not posted');
        System.assertEquals(today.addDays(30), got.Due_Date__c, 'Due date should be today + 30 when invoice date is blank');
        Test.stopTest();
    }

    @IsTest
    static void posting_sets_invoice_date_once_and_recomputes_due() {
        Date today = Date.today();

        Invoice__c inv = mk('Net 15', 'Unposted', null, null);
        insert inv;

        // Post it
        inv.Posting_Status__c = 'Posted';
        update inv;

        Invoice__c got = [SELECT Posting_Status__c, Invoice_Date__c, Due_Date__c, Terms__c FROM Invoice__c WHERE Id = :inv.Id];
        System.assertEquals('Posted', got.Posting_Status__c);
        System.assertEquals(today, got.Invoice_Date__c, 'Invoice date set on posting if blank');
        System.assertEquals(today.addDays(15), got.Due_Date__c, 'Due date based on the invoice date + 15');

        // Flip status around; invoice date should NOT be overwritten
        got.Posting_Status__c = 'Unposted Adjust';
        update got;
        got.Posting_Status__c = 'Posted';
        Date original = got.Invoice_Date__c;
        update got;

        got = [SELECT Invoice_Date__c FROM Invoice__c WHERE Id = :got.Id];
        System.assertEquals(original, got.Invoice_Date__c, 'Invoice date should not be overwritten on re-post');
    }

    @IsTest
    static void changing_terms_recalculates_due() {
        Date today = Date.today();

        Invoice__c inv = mk('Net 7', 'Unposted', today, null);
        insert inv;

        Invoice__c got = [SELECT Due_Date__c FROM Invoice__c WHERE Id = :inv.Id];
        System.assertEquals(today.addDays(7), got.Due_Date__c);

        inv.Terms__c = 'Net 45';
        update inv;

        got = [SELECT Due_Date__c FROM Invoice__c WHERE Id = :inv.Id];
        System.assertEquals(today.addDays(45), got.Due_Date__c, 'Due date adjusts when terms change');
    }

    @IsTest
    static void custom_terms_disables_due_automation_even_if_invoice_date_changes() {
        Date today = Date.today();

        Invoice__c inv = mk('Custom', 'Unposted', today, today.addDays(3));
        insert inv;

        // Change invoice date; due date should remain untouched because Terms = Custom
        inv.Invoice_Date__c = today.addDays(10);
        update inv;

        Invoice__c got = [SELECT Terms__c, Invoice_Date__c, Due_Date__c FROM Invoice__c WHERE Id = :inv.Id];
        System.assertEquals('Custom', got.Terms__c);
        System.assertEquals(today.addDays(10), got.Invoice_Date__c);
        System.assertEquals(today.addDays(3),  got.Due_Date__c, 'Due date unchanged under Custom terms');
    }

    @IsTest
    static void inserted_as_posted_sets_invoice_date_and_due() {
        Date today = Date.today();

        Invoice__c inv = mk('Due on Receipt', 'Posted', null, null);
        insert inv;

        inv = [SELECT Invoice_Date__c, Due_Date__c, Terms__c FROM Invoice__c WHERE Id = :inv.Id];
        System.assertEquals(today, inv.Invoice_Date__c, 'Posted at insert: set invoice date');
        System.assertEquals(today, inv.Due_Date__c,     'Due on Receipt = today');
    }
}
