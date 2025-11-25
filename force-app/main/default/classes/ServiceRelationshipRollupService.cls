public with sharing class ServiceRelationshipRollupService {

    public static void recalc(Set<Id> serviceRelationshipIds) {
        if (serviceRelationshipIds == null || serviceRelationshipIds.isEmpty()) {
            return;
        }

        // Roll up invoices
        InvoiceRollupResult invoiceResult = rollupInvoices(serviceRelationshipIds);

        // Roll up payments
        PaymentRollupResult paymentResult = rollupPayments(serviceRelationshipIds);

        // Merge results into Service_Relationship__c updates
        List<Service_Relationship__c> updates = new List<Service_Relationship__c>();
        for (Id srId : serviceRelationshipIds) {
            Service_Relationship__c sr = new Service_Relationship__c(Id = srId);

            // Invoices
            sr.Open_Balance__c      = invoiceResult.openBalanceBySr.get(srId);
            sr.Lifetime_Revenue__c  = invoiceResult.lifetimeRevenueBySr.get(srId);
            sr.Total_Invoices__c    = invoiceResult.totalInvoicesBySr.get(srId);
            sr.Last_Invoice_Date__c = invoiceResult.lastInvoiceDateBySr.get(srId);

            // Payments
            sr.Total_Payments__c    = paymentResult.totalPaymentsBySr.get(srId);
            sr.Last_Payment_Date__c = paymentResult.lastPaymentDateBySr.get(srId);

            updates.add(sr);
        }

        if (!updates.isEmpty()) {
            update updates;
        }
    }

    // ---------- DTOs ----------

    private class InvoiceRollupResult {
        Map<Id, Decimal> openBalanceBySr      = new Map<Id, Decimal>();
        Map<Id, Decimal> lifetimeRevenueBySr  = new Map<Id, Decimal>();
        Map<Id, Integer> totalInvoicesBySr    = new Map<Id, Integer>();
        Map<Id, Date>    lastInvoiceDateBySr  = new Map<Id, Date>();
    }

    private class PaymentRollupResult {
        Map<Id, Decimal> totalPaymentsBySr    = new Map<Id, Decimal>();
        Map<Id, Date>    lastPaymentDateBySr  = new Map<Id, Date>();
    }

    // ---------- Invoice rollups ----------

    /**
     * Invoice rollup logic:
     *
     * Open Balance:
     *   SUM(Amount_Due__c)
     *   WHERE Service_Relationship__c IN :srIds
     *     AND Posting_Status__c = 'Posted'
     *     AND Status__c IN ('Open', 'Partially Paid')
     *
     * Lifetime Revenue:
     *   SUM(Total_Amount__c)
     *   WHERE Service_Relationship__c IN :srIds
     *     AND Posting_Status__c = 'Posted'
     *
     * Total Invoices:
     *   COUNT()
     *   WHERE Service_Relationship__c IN :srIds
     *     AND Posting_Status__c = 'Posted'
     *
     * Last Invoice Date:
     *   MAX(Invoice_Date__c)
     *   WHERE Service_Relationship__c IN :srIds
     *     AND Posting_Status__c = 'Posted'
     */
    private static InvoiceRollupResult rollupInvoices(Set<Id> serviceRelationshipIds) {
        InvoiceRollupResult result = new InvoiceRollupResult();

        // Initialize maps
        for (Id srId : serviceRelationshipIds) {
            result.openBalanceBySr.put(srId, 0);
            result.lifetimeRevenueBySr.put(srId, 0);
            result.totalInvoicesBySr.put(srId, 0);
            result.lastInvoiceDateBySr.put(srId, null);
        }

        // Open balance: Posted AND Status in (Open, Partially Paid)
        for (AggregateResult ar : [
            SELECT Service_Relationship__c srId,
                   SUM(Amount_Due__c) sumOpen
            FROM Invoice__c
            WHERE Service_Relationship__c IN :serviceRelationshipIds
              AND Posting_Status__c = 'Posted'
              AND Status__c IN ('Open', 'Partially Paid')
            GROUP BY Service_Relationship__c
        ]) {
            Id srId = (Id) ar.get('srId');
            Decimal sumOpen = (Decimal) ar.get('sumOpen');
            result.openBalanceBySr.put(srId, sumOpen == null ? 0 : sumOpen);
        }

        // Lifetime revenue and invoice counts: all Posted invoices
        for (AggregateResult ar : [
            SELECT Service_Relationship__c srId,
                   SUM(Total_Amount__c) sumAmount,
                   COUNT(Id) cnt,
                   MAX(Invoice_Date__c) maxDate
            FROM Invoice__c
            WHERE Service_Relationship__c IN :serviceRelationshipIds
              AND Posting_Status__c = 'Posted'
            GROUP BY Service_Relationship__c
        ]) {
            Id srId = (Id) ar.get('srId');
            Decimal sumAmount = (Decimal) ar.get('sumAmount');
            Integer cnt       = (Integer) ar.get('cnt');
            Date maxDate      = (Date) ar.get('maxDate');

            result.lifetimeRevenueBySr.put(srId, sumAmount == null ? 0 : sumAmount);
            result.totalInvoicesBySr.put(srId, cnt == null ? 0 : cnt);
            result.lastInvoiceDateBySr.put(srId, maxDate);
        }

        return result;
    }

    // ---------- Payment rollups ----------

    /**
     * Payment rollup logic:
     *
     * Total Payments:
     *   SUM(Amount__c)
     *   WHERE Service_Relationship__c IN :srIds
     *     AND Payment_Utilization__c IN ('Partially Applied', 'Fully Applied')
     *     AND Status__c IN ('Received', 'Captured', 'Settled', 'Deposited')
     *
     * Last Payment Date:
     *   MAX(Payment_Date__c) under same filter, stored as Date
     */
    private static PaymentRollupResult rollupPayments(Set<Id> serviceRelationshipIds) {
        PaymentRollupResult result = new PaymentRollupResult();

        for (Id srId : serviceRelationshipIds) {
            result.totalPaymentsBySr.put(srId, 0);
            result.lastPaymentDateBySr.put(srId, null);
        }

        for (AggregateResult ar : [
            SELECT Service_Relationship__c srId,
                   SUM(Amount__c) sumAmount,
                   MAX(Payment_Date__c) maxPaymentDateTime
            FROM Payment__c
            WHERE Service_Relationship__c IN :serviceRelationshipIds
              AND Payment_Utilization__c IN ('Partially Applied', 'Fully Applied')
              AND Status__c IN ('Received', 'Captured', 'Settled', 'Deposited')
            GROUP BY Service_Relationship__c
        ]) {
            Id srId = (Id) ar.get('srId');
            Decimal sumAmount   = (Decimal) ar.get('sumAmount');
            Datetime maxPayment = (Datetime) ar.get('maxPaymentDateTime');

            result.totalPaymentsBySr.put(srId, sumAmount == null ? 0 : sumAmount);

            if (maxPayment != null) {
                result.lastPaymentDateBySr.put(srId, maxPayment.date());
            }
        }

        return result;
    }
}
