public with sharing class PaymentTriggerHandler {

    // ====================================================
    // BEFORE (insert)
    // ====================================================
    public static void beforeInsert(List<Payment__c> newList) {
        if (newList == null || newList.isEmpty()) return;

        // BU FIREWALL
        List<SObject> sobjs = new List<SObject>();
        sobjs.addAll(newList);
        BusinessUnitFirewallService.enforceBusinessUnitAccess(sobjs);

        // 1) Service Relationship assignment
        ServiceRelationshipAssignmentService.assign(newList);

        // 2) Existing payment logic goes here
        // PaymentStatusService.handleBefore(newList, null);
        // PaymentUtilizationService.initDefaults(newList);
        // etc.
    }


    // ====================================================
    // BEFORE (update)
    // ====================================================
    public static void beforeUpdate(
        List<Payment__c> newList,
        Map<Id, Payment__c> oldMap
    ) {
        if (newList == null || newList.isEmpty()) return;

        // BU FIREWALL
        List<SObject> sobjs = new List<SObject>();
        sobjs.addAll(newList);
        BusinessUnitFirewallService.enforceBusinessUnitAccess(sobjs);

        // 1) Service Relationship assignment
        ServiceRelationshipAssignmentService.assign(newList);

        // 2) Existing before-update logic
        // PaymentStatusService.handleBefore(newList, oldMap);
        // PaymentUtilizationService.syncUtilization(newList, oldMap);
    }


    // ====================================================
    // AFTER (insert/update/delete/undelete)
    // ====================================================
    public static void afterAll(
        List<Payment__c> newList,
        Map<Id, Payment__c> oldMap
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


        // --------------------------------------------
        // 2) Service Relationship Rollups
        // --------------------------------------------
        Set<Id> srIds = new Set<Id>();

        if (newList != null) {
            for (Payment__c p : newList) {
                if (p.Service_Relationship__c != null) {
                    srIds.add(p.Service_Relationship__c);
                }
            }
        }

        if (oldMap != null) {
            for (Payment__c oldP : oldMap.values()) {
                if (oldP.Service_Relationship__c != null) {
                    srIds.add(oldP.Service_Relationship__c);
                }
            }
        }

        if (!srIds.isEmpty()) {
            ServiceRelationshipRollupService.recalc(srIds);
        }
    }
}
