@IsTest
private class ServiceRelationshipRollupServiceTest {

    @IsTest
    static void recalc_rollsUpInvoicesAndPayments() {
        // === Arrange: core records ===
        Account acc = new Account(Name = 'Rollup Test Account');
        insert acc;

        Legal_Entity__c le = new Legal_Entity__c(Name = 'Test Legal Entity'); 
        insert le;

        Business_Unit__c bu = new Business_Unit__c(
            Name                      = 'Rollup BU',
            Short_Code__c             = 'RBU',
            Customer_Service_Email__c = 'support@example.com',
            Customer_Service_Phone__c = '555-555-5555',
            Legal_Entity__c           = le.Id
        );
        insert bu;

        Service_Relationship__c sr = new Service_Relationship__c(
            Account__c       = acc.Id,
            Business_Unit__c = bu.Id
        );
        insert sr;

        // Dates for invoices
        Date d1       = Date.today().addDays(-10);
        Date d2       = Date.today().addDays(-5);
        Date d3       = Date.today().addDays(-1);
        Date dIgnored = Date.today().addDays(-3);

        // === Arrange: Invoices ===
        // Subtotals are input; formulas compute Total_Amount__c / Amount_Due__c.
        Invoice__c invOpen = new Invoice__c(
            Service_Relationship__c = sr.Id,
            Subtotal__c             = 100,
            Invoice_Date__c         = d1,
            Status__c               = 'Open',
            Posting_Status__c       = 'Posted'
        );

        Invoice__c invPartial = new Invoice__c(
            Service_Relationship__c = sr.Id,
            Subtotal__c             = 200,
            Invoice_Date__c         = d2,
            Status__c               = 'Partially Paid',
            Posting_Status__c       = 'Posted'
        );

        Invoice__c invPaid = new Invoice__c(
            Service_Relationship__c = sr.Id,
            Subtotal__c             = 300,
            Invoice_Date__c         = d3,
            Status__c               = 'Paid',
            Posting_Status__c       = 'Posted'
        );

        // NOT Posted – should be ignored completely
        Invoice__c invUnposted = new Invoice__c(
            Service_Relationship__c = sr.Id,
            Subtotal__c             = 999,
            Invoice_Date__c         = dIgnored,
            Status__c               = 'Open',
            Posting_Status__c       = 'Draft'
        );

        insert new List<Invoice__c>{ invOpen, invPartial, invPaid, invUnposted };

        // Re-query invoices to get formula values (Total_Amount__c, Amount_Due__c)
        Map<Id, Invoice__c> invoicesById = new Map<Id, Invoice__c>(
            [SELECT Id,
                    Service_Relationship__c,
                    Total_Amount__c,
                    Amount_Due__c,
                    Invoice_Date__c,
                    Status__c,
                    Posting_Status__c
             FROM Invoice__c
             WHERE Service_Relationship__c = :sr.Id]
        );

        invOpen     = invoicesById.get(invOpen.Id);
        invPartial  = invoicesById.get(invPartial.Id);
        invPaid     = invoicesById.get(invPaid.Id);
        invUnposted = invoicesById.get(invUnposted.Id);

        // Compute expected invoice rollups from the queried data
        Decimal expectedOpenBalance = 0;
        Decimal expectedLifetimeRevenue = 0;
        Integer expectedInvoiceCount = 0;
        Date expectedLastInvoiceDate = null;

        for (Invoice__c inv : invoicesById.values()) {
            if (inv.Posting_Status__c == 'Posted') {
                // Lifetime revenue = sum of Total_Amount__c for all Posted invoices
                expectedLifetimeRevenue += (inv.Total_Amount__c == null ? 0 : inv.Total_Amount__c);
                expectedInvoiceCount++;

                // Last invoice date among Posted
                if (expectedLastInvoiceDate == null ||
                    (inv.Invoice_Date__c != null && inv.Invoice_Date__c > expectedLastInvoiceDate)) {
                    expectedLastInvoiceDate = inv.Invoice_Date__c;
                }

                // Open balance = sum of Amount_Due__c for Posted + (Open, Partially Paid)
                if (inv.Status__c == 'Open' || inv.Status__c == 'Partially Paid') {
                    expectedOpenBalance += (inv.Amount_Due__c == null ? 0 : inv.Amount_Due__c);
                }
            }
        }

        // === Arrange: Payments ===
        Datetime p1        = Datetime.now().addDays(-4);
        Datetime p2        = Datetime.now().addDays(-2);
        Datetime pIgnored1 = Datetime.now().addDays(-3);
        Datetime pIgnored2 = Datetime.now().addDays(-1);

        // Valid: Partially Applied + good status
        Payment__c payPartial = new Payment__c(
            Service_Relationship__c = sr.Id,
            Amount__c               = 80,
            Payment_Utilization__c  = 'Partially Applied',
            Status__c               = 'Received',
            Payment_Date__c         = p1
        );

        // Valid: Fully Applied + good status
        Payment__c payFull = new Payment__c(
            Service_Relationship__c = sr.Id,
            Amount__c               = 120,
            Payment_Utilization__c  = 'Fully Applied',
            Status__c               = 'Settled',
            Payment_Date__c         = p2
        );

        // Ignored: Unapplied
        Payment__c payUnapplied = new Payment__c(
            Service_Relationship__c = sr.Id,
            Amount__c               = 999,
            Payment_Utilization__c  = 'Unapplied',
            Status__c               = 'Received',
            Payment_Date__c         = pIgnored1
        );

        // Ignored: bad status (Failed)
        Payment__c payFailed = new Payment__c(
            Service_Relationship__c = sr.Id,
            Amount__c               = 999,
            Payment_Utilization__c  = 'Fully Applied',
            Status__c               = 'Failed',
            Payment_Date__c         = pIgnored2
        );

        insert new List<Payment__c>{ payPartial, payFull, payUnapplied, payFailed };

        // Expected payment rollups
        Decimal expectedTotalPayments = 80 + 120;
        Date expectedLastPaymentDate = p2.date();

        // === Act ===
        Test.startTest();
        ServiceRelationshipRollupService.recalc(new Set<Id>{ sr.Id });
        Test.stopTest();

        // === Assert ===
        Service_Relationship__c refreshed = [
            SELECT Open_Balance__c,
                   Lifetime_Revenue__c,
                   Total_Invoices__c,
                   Last_Invoice_Date__c,
                   Total_Payments__c,
                   Last_Payment_Date__c
            FROM Service_Relationship__c
            WHERE Id = :sr.Id
            LIMIT 1
        ];

        System.assertEquals(
            expectedOpenBalance,
            refreshed.Open_Balance__c,
            'Open_Balance__c should match sum of Amount_Due__c for Posted + (Open/Partially Paid).'
        );
        System.assertEquals(
            expectedLifetimeRevenue,
            refreshed.Lifetime_Revenue__c,
            'Lifetime_Revenue__c should sum Total_Amount__c for all Posted invoices.'
        );
        System.assertEquals(
            expectedInvoiceCount,
            refreshed.Total_Invoices__c,
            'Total_Invoices__c should count Posted invoices.'
        );
        System.assertEquals(
            expectedLastInvoiceDate,
            refreshed.Last_Invoice_Date__c,
            'Last_Invoice_Date__c should be the latest Invoice_Date__c of Posted invoices.'
        );

        System.assertEquals(
            expectedTotalPayments,
            refreshed.Total_Payments__c,
            'Total_Payments__c should sum valid payments only.'
        );
        System.assertEquals(
            expectedLastPaymentDate,
            refreshed.Last_Payment_Date__c,
            'Last_Payment_Date__c should be the date of the latest valid payment.'
        );
    }
}
