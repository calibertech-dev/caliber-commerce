public with sharing class SubscriptionTriggerHandler {

    public static void beforeInsert(List<Subscription__c> newList) {
        if (newList == null || newList.isEmpty()) return;

        // BU FIREWALL
        List<SObject> sobjs = new List<SObject>();
        sobjs.addAll(newList);
        BusinessUnitFirewallService.enforceBusinessUnitAccess(sobjs);

        // 1) Service Relationship assignment
        ServiceRelationshipAssignmentService.assign(newList);

        // 2) Existing subscription logic (start dates, schedule defaults, etc.)
    }

    public static void beforeUpdate(List<Subscription__c> newList, Map<Id, Subscription__c> oldMap) {
        if (newList == null || newList.isEmpty()) return;

        // BU FIREWALL
        List<SObject> sobjs = new List<SObject>();
        sobjs.addAll(newList);
        BusinessUnitFirewallService.enforceBusinessUnitAccess(sobjs);

        // 1) Service Relationship assignment
        ServiceRelationshipAssignmentService.assign(newList);

        // 2) Existing subscription update logic
    }

    public static void afterAll(
        List<Subscription__c> newList,
        Map<Id, Subscription__c> oldMap
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
