// ============================================================================
// VendorProductTrigger.trigger
// - Entry point for all Vendor_Product__c DML
// - Delegates to VendorProductTriggerHandler for before/after logic
// ============================================================================
trigger VendorProductTrigger on Vendor_Product__c (
    before insert, before update, before delete, 
    after insert, after update, after delete, after undelete
) {
    VendorProductTriggerHandler.run();
}
