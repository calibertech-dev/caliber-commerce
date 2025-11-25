public with sharing class SubscriptionTriggerHandler {

    public static void beforeInsert(List<Subscription__c> newList) {
        if (newList == null || newList.isEmpty()) return;

        // 1) Service Relationship assignment
        ServiceRelationshipAssignmentService.assign(newList);

        // 2) Existing subscription logic (start dates, schedule defaults, etc.)
    }

    public static void beforeUpdate(List<Subscription__c> newList, Map<Id, Subscription__c> oldMap) {
        if (newList == null || newList.isEmpty()) return;

        // 1) Service Relationship assignment
        ServiceRelationshipAssignmentService.assign(newList);

        // 2) Existing subscription update logic
    }

    public static void afterAll(
        List<Subscription__c> newList,
        Map<Id, Subscription__c> oldMap
    ) {
        // Placeholder for:
        // - BU firewall
        // - Subscription-driven invoice creation, if you ever fire that off via trigger (I’d lean to async, but that’s another topic)
    }
}
