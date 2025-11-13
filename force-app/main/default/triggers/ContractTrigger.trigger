trigger ContractTrigger on Contract__c (before insert, before update) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            ContractTriggerHandler.beforeInsert(Trigger.new);
        }
        if (Trigger.isUpdate) {
            ContractTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
        }
    }
}
