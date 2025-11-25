public with sharing class ProposalTriggerHandler {

    public static void beforeInsert(List<Proposal__c> newList) {
        if (newList == null || newList.isEmpty()) return;

        // 1) Service Relationship assignment
        ServiceRelationshipAssignmentService.assign(newList);

        // 2) Existing Proposal logic (numbering, deposit policy linking, fulfillment route init, etc.)
    }

    public static void beforeUpdate(List<Proposal__c> newList, Map<Id, Proposal__c> oldMap) {
        if (newList == null || newList.isEmpty()) return;

        // 1) Service Relationship assignment
        ServiceRelationshipAssignmentService.assign(newList);

        // 2) Existing Proposal update logic
    }

    public static void afterAll(
        List<Proposal__c> newList,
        Map<Id, Proposal__c> oldMap
    ) {
        // Placeholder for:
        // - BU firewall
        // - Anything that needs to recalc after insert/update/delete
    }
}
