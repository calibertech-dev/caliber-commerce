public with sharing class DepositTriggerHandler {

    public static void beforeInsert(List<Deposit__c> newList) {
        if (newList == null || newList.isEmpty()) return;

        // 1) Service Relationship assignment
        ServiceRelationshipAssignmentService.assign(newList);

        // 2) Existing deposit logic (default statuses, linking to Proposal/Contract, etc.)
    }

    public static void beforeUpdate(List<Deposit__c> newList, Map<Id, Deposit__c> oldMap) {
        if (newList == null || newList.isEmpty()) return;

        // 1) Service Relationship assignment
        ServiceRelationshipAssignmentService.assign(newList);

        // 2) Existing deposit update logic
    }

    public static void afterAll(
        List<Deposit__c> newList,
        Map<Id, Deposit__c> oldMap
    ) {
        // --------------------------------------------
        // 1) BU Firewall re-evaluation
        // --------------------------------------------
        List<SObject> sobjs = new List<SObject>();

        if ((Trigger.isInsert || Trigger.isUpdate || Trigger.isUndelete) && newList != null) {
            sobjs.addAll(newList);
        }
        if ((Trigger.isUpdate || Trigger.isDelete) && oldMap != null) {
            sobjs.addAll(oldMap.values());
        }

        if (!sobjs.isEmpty()) {
            BusinessUnitObjectSharingService.recalcForRecords(sobjs);
        }
    }
}
