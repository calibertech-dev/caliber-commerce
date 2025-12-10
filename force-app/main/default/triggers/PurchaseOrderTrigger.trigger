// ============================================================================
// PurchaseOrderTrigger.trigger
// - BEFORE UPDATE: prevent Business_Unit__c changes when lines exist.
// - BEFORE DELETE: prevent delete when lines exist.
// ============================================================================
trigger PurchaseOrderTrigger on Purchase_Order__c (
    before update, before delete
) {
    PurchaseOrderTriggerHandler.run();
}
