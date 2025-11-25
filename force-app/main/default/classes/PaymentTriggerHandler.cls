public with sharing class PaymentTriggerHandler {

    public static void beforeInsert(List<Payment__c> newList) {
        if (newList == null || newList.isEmpty()) return;

        // 1) Service Relationship assignment
        ServiceRelationshipAssignmentService.assign(newList);

        // 2) Existing payment logic (status normalization, utilization defaults, etc.)
        //    TODO: move your current before-insert Payment logic here.
    }

    public static void beforeUpdate(List<Payment__c> newList, Map<Id, Payment__c> oldMap) {
        if (newList == null || newList.isEmpty()) return;

        // 1) Service Relationship assignment
        ServiceRelationshipAssignmentService.assign(newList);

        // 2) Existing payment before-update logic
        //    TODO: move your current before-update Payment logic here.
    }

    public static void afterAll(
        List<Payment__c> newList,
        Map<Id, Payment__c> oldMap
    ) {
        // Placeholder for:
        // - Later BU firewall share updates
        // - Payment-driven rollups on Service_Relationship__c (Total_Payments__c, Last_Payment_Date__c, etc.)
    }
}
