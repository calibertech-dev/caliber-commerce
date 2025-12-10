// ============================================================================
// ProductSourcingOptionTrigger.trigger
// - Entry point for Product_Sourcing_Option__c DML
// - BEFORE: apply defaults and validation
// - AFTER:  currently no behavior, but handler is wired for future use
// ============================================================================
trigger ProductSourcingOptionTrigger on Product_Sourcing_Option__c (
    before insert, before update, before delete,
    after insert, after update, after delete, after undelete
) {
    ProductSourcingOptionTriggerHandler.run();
}
