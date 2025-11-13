trigger DepositApplicationTrigger on Deposit_Application__c (
    before insert, before update,
    after insert, after update, after delete, after undelete
) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) DepositApplicationTriggerHandler.beforeInsert(Trigger.new);
        if (Trigger.isUpdate) DepositApplicationTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
    } else {
        DepositApplicationTriggerHandler.afterChange(
            Trigger.new, Trigger.old, Trigger.isInsert, Trigger.isUpdate, Trigger.isDelete, Trigger.isUndelete
        );
    }
}
