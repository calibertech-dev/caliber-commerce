trigger CreditMemoApplicationTrigger on Credit_Memo_Application__c (
    before insert, before update,
    after insert, after update, after delete, after undelete
) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) CreditMemoApplicationTriggerHandler.beforeInsert(Trigger.new);
        if (Trigger.isUpdate) CreditMemoApplicationTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
    } else {
        CreditMemoApplicationTriggerHandler.afterChange(
            Trigger.new, Trigger.old, Trigger.isInsert, Trigger.isUpdate, Trigger.isDelete, Trigger.isUndelete
        );
    }
}
