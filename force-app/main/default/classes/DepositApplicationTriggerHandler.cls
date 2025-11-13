public with sharing class DepositApplicationTriggerHandler {

    // =============== BEFORE ===============
    public static void beforeInsert(List<Deposit_Application__c> newList) {
        ApplicationGuardService.validateApplications((List<SObject>) newList);
        assignNames(newList);
    }
    public static void beforeUpdate(List<Deposit_Application__c> newList, Map<Id, Deposit_Application__c> oldMap) {
        ApplicationGuardService.validateApplications((List<SObject>) newList);
        assignNames(newList);
    }

    private static void assignNames(List<Deposit_Application__c> rows) {
        Set<Id> parentIds = new Set<Id>();
        for (Deposit_Application__c da : rows)
            if (da.Deposit__c != null && String.isBlank(da.Name))
                parentIds.add(da.Deposit__c);
        if (parentIds.isEmpty()) return;

        Map<Id, Deposit__c> parents = new Map<Id, Deposit__c>([
            SELECT Id, Name, Application_Count__c
            FROM Deposit__c
            WHERE Id IN :parentIds
        ]);

        for (Deposit_Application__c da : rows) {
            if (da.Deposit__c == null || String.isNotBlank(da.Name)) continue;
            Deposit__c d = parents.get(da.Deposit__c);
            if (d == null) continue;

            Integer n = d.Application_Count__c == null ? 1 : d.Application_Count__c.intValue();
            da.Name = d.Name + '-' + String.valueOf(n);
        }
    }

    // =============== AFTER ===============
    public static void afterChange(
        List<Deposit_Application__c> newList,
        List<Deposit_Application__c> oldList,
        Boolean isInsert, Boolean isUpdate, Boolean isDelete, Boolean isUndelete
    ) {
        Set<Id> invoiceIds = new Set<Id>();
        if (isInsert || isUpdate || isUndelete)
            for (Deposit_Application__c r : newList) if (r.Invoice__c != null) invoiceIds.add(r.Invoice__c);
        if (isDelete && oldList != null)
            for (Deposit_Application__c r : oldList) if (r.Invoice__c != null) invoiceIds.add(r.Invoice__c);

        if (!invoiceIds.isEmpty()) InvoiceStatusService.recalcForInvoices(invoiceIds);
    }
}
