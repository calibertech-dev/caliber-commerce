trigger CreditMemoTrigger on Credit_Memo__c (
    before insert, before update,
    after insert, after update, after delete, after undelete
) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            CreditMemoTriggerHandler.beforeInsert(Trigger.new);
        }
        if (Trigger.isUpdate) {
            CreditMemoTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
        }
    }

    if (Trigger.isAfter) {
        CreditMemoTriggerHandler.afterAll(Trigger.new, Trigger.oldMap);
    }
}
