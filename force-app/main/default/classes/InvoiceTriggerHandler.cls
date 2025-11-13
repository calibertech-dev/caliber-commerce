public with sharing class InvoiceTriggerHandler {
    public static void before(List<Invoice__c> newList, Map<Id, Invoice__c> oldMap) {
        InvoicePostingService.handleBefore(newList, oldMap);   // stamp Invoice_Date__c on first post
        InvoiceTermsService.applyTermsDates(newList, oldMap);  // compute Due_Date__c unless Custom
    }
    public static void after(List<Invoice__c> newList, Map<Id, Invoice__c> oldMap) {
        // Re-evaluate status when Posted or already Posted (header changed)
        Set<Id> ids = new Set<Id>();
        for (Invoice__c inv : newList) {
            Invoice__c oldInv = oldMap.get(inv.Id);
            Boolean toPosted    = oldInv.Posting_Status__c != 'Posted' && inv.Posting_Status__c == 'Posted';
            Boolean stayedPosted = oldInv.Posting_Status__c == 'Posted' && inv.Posting_Status__c == 'Posted';
            if (toPosted || stayedPosted) ids.add(inv.Id);
        }
        if (!ids.isEmpty()) InvoiceStatusService.recalcForInvoices(ids);
    }
}
