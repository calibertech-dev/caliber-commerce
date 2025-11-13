trigger PaymentApplicationTrigger on Payment_Application__c (
    before insert, before update,
    after insert, after update, after delete, after undelete
) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) PaymentApplicationTriggerHandler.beforeInsert(Trigger.new);
        if (Trigger.isUpdate) PaymentApplicationTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
    } else {
        PaymentApplicationTriggerHandler.afterChange(
            Trigger.new, Trigger.old, Trigger.isInsert, Trigger.isUpdate, Trigger.isDelete, Trigger.isUndelete
        );
    }
}
