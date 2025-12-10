// ============================================================================
// ProductAvailabilityTrigger.trigger
// - AFTER INSERT/UPDATE on Product_Availability__c
// - Delegates to ProductAvailabilityTriggerHandler
// ============================================================================
trigger ProductAvailabilityTrigger on Product_Availability__c (
    after insert, after update
) {
    ProductAvailabilityTriggerHandler.run();
}
