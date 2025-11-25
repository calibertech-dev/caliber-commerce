trigger SubscriptionTrigger on Subscription__c (
    before insert, before update,
    after insert, after update, after delete, after undelete
) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            SubscriptionTriggerHandler.beforeInsert(Trigger.new);
        }
        if (Trigger.isUpdate) {
            SubscriptionTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
        }
    }

    if (Trigger.isAfter) {
        SubscriptionTriggerHandler.afterAll(Trigger.new, Trigger.oldMap);
    }
}
