public with sharing class PaymentApplicationTriggerHandler {

    // ================= BEFORE =================
    public static void beforeInsert(List<Payment_Application__c> newList) {
        ApplicationGuardService.validateApplications((List<SObject>) newList);
        assignNames(newList);
    }
    public static void beforeUpdate(List<Payment_Application__c> newList, Map<Id, Payment_Application__c> oldMap) {
        ApplicationGuardService.validateApplications((List<SObject>) newList);
        assignNames(newList);
    }

    private static void assignNames(List<Payment_Application__c> rows) {
        Set<Id> parentIds = new Set<Id>();
        for (Payment_Application__c pa : rows)
            if (pa.Payment__c != null && String.isBlank(pa.Name))
                parentIds.add(pa.Payment__c);
        if (parentIds.isEmpty()) return;

        Map<Id, Payment__c> parents = new Map<Id, Payment__c>([
            SELECT Id, Name, Application_Count__c
            FROM Payment__c
            WHERE Id IN :parentIds
        ]);

        for (Payment_Application__c pa : rows) {
            if (pa.Payment__c == null || String.isNotBlank(pa.Name)) continue;
            Payment__c p = parents.get(pa.Payment__c);
            if (p == null) continue;

            Integer n = p.Application_Count__c == null ? 1 : p.Application_Count__c.intValue();
            pa.Name = p.Name + '-' + String.valueOf(n);
        }
    }

    // ================= AFTER =================
    public static void afterChange(
        List<Payment_Application__c> newList,
        List<Payment_Application__c> oldList,
        Boolean isInsert, Boolean isUpdate, Boolean isDelete, Boolean isUndelete
    ) {
        // collect parent Payment ids
        Set<Id> paymentIds = new Set<Id>();
        if (isInsert || isUpdate || isUndelete)
            for (Payment_Application__c r : newList) if (r.Payment__c != null) paymentIds.add(r.Payment__c);
        if (isDelete && oldList != null)
            for (Payment_Application__c r : oldList) if (r.Payment__c != null) paymentIds.add(r.Payment__c);

        // utilization (not collection) update
        if (!paymentIds.isEmpty()) PaymentUtilizationService.recalc(paymentIds);

        // invoice headers
        Set<Id> invoiceIds = new Set<Id>();
        if (isInsert || isUpdate || isUndelete)
            for (Payment_Application__c r : newList) if (r.Invoice__c != null) invoiceIds.add(r.Invoice__c);
        if (isDelete && oldList != null)
            for (Payment_Application__c r : oldList) if (r.Invoice__c != null) invoiceIds.add(r.Invoice__c);
        if (!invoiceIds.isEmpty()) InvoiceStatusService.recalcForInvoices(invoiceIds);
    }
}
