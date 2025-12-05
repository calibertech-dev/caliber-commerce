public with sharing class ContractTriggerHandler {

    // ====================================================
    // BEFORE INSERT
    // ====================================================
    public static void beforeInsert(List<Contract__c> newList) {
        if (newList == null || newList.isEmpty()) return;
        // BU FIREWALL
        List<SObject> sobjs = new List<SObject>();
        sobjs.addAll(newList);
        BusinessUnitFirewallService.enforceBusinessUnitAccess(sobjs);

        // 1) Service Relationship assignment
        ServiceRelationshipAssignmentService.assign(newList);

        // 2) Contract-specific fee logic
        applyFeeLogic(newList, null);
    }

    // ====================================================
    // BEFORE UPDATE
    // ====================================================
    public static void beforeUpdate(
        List<Contract__c> newList,
        Map<Id, Contract__c> oldMap
    ) {
        if (newList == null || newList.isEmpty()) return;
        // BU FIREWALL
        List<SObject> sobjs = new List<SObject>();
        sobjs.addAll(newList);
        BusinessUnitFirewallService.enforceBusinessUnitAccess(sobjs);

        // 1) Service Relationship assignment
        ServiceRelationshipAssignmentService.assign(newList);

        // 2) Contract-specific fee + written amount logic
        applyFeeLogic(newList, oldMap);
    }

    // ====================================================
    // AFTER INSERT/UPDATE/DELETE/UNDELETE
    // ====================================================
    public static void afterAll(
        List<Contract__c> newList,
        Map<Id, Contract__c> oldMap
    ) {
        // CONTRACT *DOES* participate in the BU Firewall (lookup, not M-D)
        List<SObject> sobjs = new List<SObject>();

        if ((Trigger.isInsert || Trigger.isUpdate || Trigger.isUndelete) && newList != null)
            sobjs.addAll(newList);

        if ((Trigger.isUpdate || Trigger.isDelete) && oldMap != null)
            sobjs.addAll(oldMap.values());

        if (!sobjs.isEmpty()) {
            BusinessUnitObjectSharingService.recalcForRecords(sobjs);
        }

        // No rollups from Contract → Service Relationship at this time.
    }

    // ====================================================
    // INTERNAL LOGIC
    // ====================================================
    private static void applyFeeLogic(
        List<Contract__c> newList,
        Map<Id, Contract__c> oldMap
    ) {
        for (Contract__c c : newList) {
            Contract__c oldC = (oldMap == null ? null : oldMap.get(c.Id));

            Boolean proposalChanged =
                (oldC == null) ||
                (c.Proposal_Amount__c != oldC.Proposal_Amount__c);

            Boolean allowUpdate = !c.Override_Fee__c;

            if (allowUpdate && proposalChanged) {
                c.Contract_Fee__c = c.Proposal_Amount__c;
            }

            Boolean feeChanged =
                (oldC == null) ||
                (c.Contract_Fee__c != oldC.Contract_Fee__c);

            if (feeChanged && c.Contract_Fee__c != null) {
                c.Written_Amount__c = NumberToWordsConverter.convert(c.Contract_Fee__c);
            }
        }
    }
}
