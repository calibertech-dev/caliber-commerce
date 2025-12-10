// ============================================================================
// PurchaseOrderLineTrigger.trigger
// - BEFORE: apply defaults from Product_Sourcing_Option__c / Vendor_Product__c,
//           then run quantity calculations.
// - AFTER:  recompute header rollups for any POs affected by line changes.
// ============================================================================
trigger PurchaseOrderLineTrigger on Purchase_Order_Line__c (
    before insert, before update,
    after insert, after update, after delete, after undelete
) {
    PurchaseOrderLineTriggerHandler.run();
}
