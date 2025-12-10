// ============================================================================
// VendorProductTriggerHandler
// - Routes before/after work for Vendor_Product__c
// - BEFORE: enforces single preferred vendor product per Product
// - AFTER:  auto-creates Product_Sourcing_Option__c when appropriate
// ============================================================================
public with sharing class VendorProductTriggerHandler {

    public static void run() {
        if (Trigger.isBefore) {
            handleBefore();
        }
        if (Trigger.isAfter) {
            handleAfter();
        }
    }

    private static void handleBefore() {
        if (Trigger.operationType == System.TriggerOperation.BEFORE_INSERT) {
            // Enforce "at most one active preferred Vendor_Product__c per Product__c"
            VendorProductPreferenceService.enforceSinglePreferred(Trigger.new, null);
        } else if (Trigger.operationType == System.TriggerOperation.BEFORE_UPDATE) {
            VendorProductPreferenceService.enforceSinglePreferred(Trigger.new, Trigger.old);
        }
    }

    private static void handleAfter() {
        if (Trigger.operationType == System.TriggerOperation.AFTER_INSERT) {
            // For new Vendor_Product__c rows, auto-create PSOs where
            // Product_Availability__c says we should.
            VendorProductAutoSourcingService.createForNewVendorProducts(Trigger.new);
        }
    }
}
