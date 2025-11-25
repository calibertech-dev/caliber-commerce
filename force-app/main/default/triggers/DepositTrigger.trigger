trigger DepositTrigger on Deposit__c (
    before insert, before update,
    after insert, after update, after delete, after undelete
) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            DepositTriggerHandler.beforeInsert(Trigger.new);
        }
        if (Trigger.isUpdate) {
            DepositTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
        }
    }

    if (Trigger.isAfter) {
        DepositTriggerHandler.afterAll(Trigger.new, Trigger.oldMap);
    }
}
