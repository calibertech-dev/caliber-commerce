// ============================================================================
// ProductSourcingOptionTriggerHandler
// - BEFORE INSERT/UPDATE:
//     * applyDefaults: fill in Vendor__c, Product__c, MOQ from Vendor_Product__c
//       if Vendor_Product__c is set and those fields are blank.
//     * validate: enforce uniqueness of PSO per (BU, Vendor_Product) and
//       single default PSO per (BU, Product).
// - AFTER: reserved for future behaviors (e.g., logging/audits).
// ============================================================================
public with sharing class ProductSourcingOptionTriggerHandler {

    public static void run() {
        if (Trigger.isBefore) {
            handleBefore(Trigger.operationType, Trigger.new, Trigger.old);
        }
        if (Trigger.isAfter) {
            handleAfter(Trigger.operationType, Trigger.new, Trigger.old);
        }
    }

    private static void handleBefore(
        System.TriggerOperation operationType,
        List<Product_Sourcing_Option__c> newList,
        List<Product_Sourcing_Option__c> oldList
    ) {
        switch on operationType {
            when BEFORE_INSERT {
                ProductSourcingOptionDefaultsService.applyDefaults(newList);
                ProductSourcingOptionValidationService.validate(newList);
            }
            when BEFORE_UPDATE {
                ProductSourcingOptionDefaultsService.applyDefaults(newList, oldList);
                ProductSourcingOptionValidationService.validate(newList, oldList);
            }
            when BEFORE_DELETE {
                // If you want "in use" checks later (e.g. PSO on existing POs),
                // they can go in a dedicated DeleteValidationService.
            }
            when else {
                // no-op
            }
        }
    }

    private static void handleAfter(
        System.TriggerOperation operationType,
        List<Product_Sourcing_Option__c> newList,
        List<Product_Sourcing_Option__c> oldList
    ) {
        switch on operationType {
            when AFTER_INSERT {
                // Future extension point (e.g., logging, integration hooks).
            }
            when AFTER_UPDATE {
                // Future extension point.
            }
            when AFTER_DELETE {
                // Future extension point.
            }
            when AFTER_UNDELETE {
                // Future extension point.
            }
            when else {
                // no-op
            }
        }
    }
}
