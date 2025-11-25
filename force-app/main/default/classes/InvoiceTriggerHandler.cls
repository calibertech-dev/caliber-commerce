public with sharing class InvoiceTriggerHandler {

    // ====================================================
    // BEFORE (insert/update)
    // ====================================================
    public static void beforeInsert(List<Invoice__c> newList) {
        if (newList == null || newList.isEmpty()) return;

        // 1) Assign Service Relationship
        ServiceRelationshipAssignmentService.assign(newList);

        // 2) Existing Invoice BEFORE logic
        InvoicePostingService.handleBefore(newList, null);
        InvoiceTermsService.applyTermsDates(newList, null);
    }

    public static void beforeUpdate(List<Invoice__c> newList, Map<Id, Invoice__c> oldMap) {
        if (newList == null || newList.isEmpty()) return;

        // 1) Assign Service Relationship
        ServiceRelationshipAssignmentService.assign(newList);

        // 2) Existing Invoice BEFORE logic
        InvoicePostingService.handleBefore(newList, oldMap);
        InvoiceTermsService.applyTermsDates(newList, oldMap);
    }


    // ====================================================
    // AFTER (insert/update/delete/undelete)
    // ====================================================
    public static void afterAll(
        List<Invoice__c> newList,
        Map<Id, Invoice__c> oldMap
    ) {
        // --------------------------------------------
        // 1) Re-evaluate status for posted invoices
        // --------------------------------------------
        if (Trigger.isInsert || Trigger.isUpdate) {
            Set<Id> ids = new Set<Id>();

            for (Invoice__c inv : newList) {
                Invoice__c oldInv = (oldMap == null ? null : oldMap.get(inv.Id));

                // New → Posted
                Boolean toPosted =
                    oldInv != null &&
                    oldInv.Posting_Status__c != 'Posted' &&
                    inv.Posting_Status__c == 'Posted';

                // Posted → Posted (amount changed, etc.)
                Boolean stayedPosted =
                    oldInv != null &&
                    oldInv.Posting_Status__c == 'Posted' &&
                    inv.Posting_Status__c == 'Posted';

                if (toPosted || stayedPosted) {
                    ids.add(inv.Id);
                }
            }

            if (!ids.isEmpty()) {
                InvoiceStatusService.recalcForInvoices(ids);
            }
        }

        // --------------------------------------------
        // 2) Placeholder for BU Firewall (not active yet)
        // --------------------------------------------
        // List<SObject> sobjs = new List<SObject>();
        // if (Trigger.isInsert || Trigger.isUpdate || Trigger.isUndelete) sobjs.addAll(newList);
        // if (Trigger.isUpdate || Trigger.isDelete) sobjs.addAll(oldMap.values());
        // BusinessUnitObjectSharingService.recalcForRecords(sobjs);

        // --------------------------------------------
        // 3) Placeholder for rollup impact on Service Relationship
        // --------------------------------------------
        // ServiceRelationshipRollupService.recalcForInvoices(newList, oldMap);
    }
}
