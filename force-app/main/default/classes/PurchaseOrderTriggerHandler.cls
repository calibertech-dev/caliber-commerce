// ============================================================================
// PurchaseOrderTriggerHandler
// - Routes BEFORE logic for Purchase_Order__c to the validation service.
// ============================================================================
public with sharing class PurchaseOrderTriggerHandler {

    public static void run() {
        if (Trigger.isBefore) {
            handleBefore(Trigger.operationType, Trigger.new, Trigger.old);
        }
    }

    private static void handleBefore(
        System.TriggerOperation operationType,
        List<Purchase_Order__c> newList,
        List<Purchase_Order__c> oldList
    ) {
        switch on operationType {
            when BEFORE_UPDATE {
                PurchaseOrderValidationService.preventBusinessUnitChangeWithLines(newList, oldList);
            }
            when BEFORE_DELETE {
                PurchaseOrderValidationService.preventDeleteWhenLinesExist(oldList);
            }
            when else {
                // no-op
            }
        }
    }
}
