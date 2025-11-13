trigger InvoiceTrigger on Invoice__c (before insert, before update, after update) {
    if (Trigger.isBefore) {
        InvoiceTriggerHandler.before(Trigger.new, Trigger.oldMap);
    }
    if (Trigger.isAfter && Trigger.isUpdate) {
        InvoiceTriggerHandler.after(Trigger.new, Trigger.oldMap);
    }
}