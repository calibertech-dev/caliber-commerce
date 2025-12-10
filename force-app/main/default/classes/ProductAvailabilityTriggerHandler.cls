// ============================================================================
// ProductAvailabilityTriggerHandler
// - AFTER INSERT: auto-source for newly created eligible Product_Availability__c
// - AFTER UPDATE: auto-source only when PA transitions from not-eligible to
//   eligible (per Allow_Purchase__c, Auto_Create_Sourcing_Options__c, Is_Active__c).
// ============================================================================
public with sharing class ProductAvailabilityTriggerHandler {

    public static void run() {
        if (Trigger.isAfter) {
            handleAfter(Trigger.operationType, Trigger.new, Trigger.old);
        }
    }

    private static void handleAfter(
        System.TriggerOperation operationType,
        List<Product_Availability__c> newList,
        List<Product_Availability__c> oldList
    ) {
        switch on operationType {
            when AFTER_INSERT {
                ProductAvailabilityAutoSourcingService.autoCreateSourcingOptions(newList, null);
            }
            when AFTER_UPDATE {
                ProductAvailabilityAutoSourcingService.autoCreateSourcingOptions(newList, oldList);
            }
            when else {
                // no-op
            }
        }
    }
}
