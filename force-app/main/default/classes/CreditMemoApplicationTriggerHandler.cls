public with sharing class CreditMemoApplicationTriggerHandler {

    // =============== BEFORE ===============
    public static void beforeInsert(List<Credit_Memo_Application__c> newList) {
        ApplicationGuardService.validateApplications((List<SObject>) newList);
        assignNames(newList);
    }
    public static void beforeUpdate(List<Credit_Memo_Application__c> newList, Map<Id, Credit_Memo_Application__c> oldMap) {
        ApplicationGuardService.validateApplications((List<SObject>) newList);
        assignNames(newList);
    }

    private static void assignNames(List<Credit_Memo_Application__c> rows) {
        Set<Id> parentIds = new Set<Id>();
        for (Credit_Memo_Application__c ca : rows)
            if (ca.Credit_Memo__c != null && String.isBlank(ca.Name))
                parentIds.add(ca.Credit_Memo__c);
        if (parentIds.isEmpty()) return;

        Map<Id, Credit_Memo__c> parents = new Map<Id, Credit_Memo__c>([
            SELECT Id, Name, Application_Count__c
            FROM Credit_Memo__c
            WHERE Id IN :parentIds
        ]);

        for (Credit_Memo_Application__c ca : rows) {
            if (ca.Credit_Memo__c == null || String.isNotBlank(ca.Name)) continue;
            Credit_Memo__c cm = parents.get(ca.Credit_Memo__c);
            if (cm == null) continue;

            Integer n = cm.Application_Count__c == null ? 1 : cm.Application_Count__c.intValue();
            ca.Name = cm.Name + '-' + String.valueOf(n);
        }
    }

    // =============== AFTER ===============
    public static void afterChange(
        List<Credit_Memo_Application__c> newList,
        List<Credit_Memo_Application__c> oldList,
        Boolean isInsert, Boolean isUpdate, Boolean isDelete, Boolean isUndelete
    ) {
        // parent credit memos → status update
        Set<Id> cmIds = new Set<Id>();
        if (isInsert || isUpdate || isUndelete)
            for (Credit_Memo_Application__c r : newList) if (r.Credit_Memo__c != null) cmIds.add(r.Credit_Memo__c);
        if (isDelete && oldList != null)
            for (Credit_Memo_Application__c r : oldList) if (r.Credit_Memo__c != null) cmIds.add(r.Credit_Memo__c);
        if (!cmIds.isEmpty()) CreditMemoStatusService.recalc(cmIds);

        // invoice headers
        Set<Id> invoiceIds = new Set<Id>();
        if (isInsert || isUpdate || isUndelete)
            for (Credit_Memo_Application__c r : newList) if (r.Invoice__c != null) invoiceIds.add(r.Invoice__c);
        if (isDelete && oldList != null)
            for (Credit_Memo_Application__c r : oldList) if (r.Invoice__c != null) invoiceIds.add(r.Invoice__c);
        if (!invoiceIds.isEmpty()) InvoiceStatusService.recalcForInvoices(invoiceIds);
    }
}
