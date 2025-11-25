trigger PaymentTrigger on Payment__c (
    before insert, before update,
    after insert, after update, after delete, after undelete
) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            PaymentTriggerHandler.beforeInsert(Trigger.new);
        }
        if (Trigger.isUpdate) {
            PaymentTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
        }
    }

    if (Trigger.isAfter) {
        PaymentTriggerHandler.afterAll(Trigger.new, Trigger.oldMap);
    }
}
