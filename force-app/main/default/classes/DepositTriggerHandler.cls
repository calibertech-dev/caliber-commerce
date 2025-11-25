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
        // Placeholder for:
        // - BU firewall
        // - Deposit rollups (if/when we want them to affect SR balances)
    }
}
