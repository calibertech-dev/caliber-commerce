trigger ContractAmendmentTrigger on Contract_Amendment__c (before insert, before update) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            ContractAmendmentTriggerHandler.beforeInsert(Trigger.new);
        }
        if (Trigger.isUpdate) {
            ContractAmendmentTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}
