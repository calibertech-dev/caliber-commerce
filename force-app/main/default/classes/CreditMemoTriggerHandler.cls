public with sharing class CreditMemoTriggerHandler {

    public static void beforeInsert(List<Credit_Memo__c> newList) {
        if (newList == null || newList.isEmpty()) return;

        // 1) Service Relationship assignment
        ServiceRelationshipAssignmentService.assign(newList);

        // 2) Existing credit memo logic (defaults, linking, etc.)
    }

    public static void beforeUpdate(List<Credit_Memo__c> newList, Map<Id, Credit_Memo__c> oldMap) {
        if (newList == null || newList.isEmpty()) return;

        // 1) Service Relationship assignment
        ServiceRelationshipAssignmentService.assign(newList);

        // 2) Existing credit memo update logic
    }

    public static void afterAll(
        List<Credit_Memo__c> newList,
        Map<Id, Credit_Memo__c> oldMap
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
