trigger ProposalTrigger on Proposal__c (
    before insert, before update,
    after insert, after update, after delete, after undelete
) {
    if (Trigger.isBefore) {
        if (Trigger.isInsert) {
            ProposalTriggerHandler.beforeInsert(Trigger.new);
        }
        if (Trigger.isUpdate) {
            ProposalTriggerHandler.beforeUpdate(Trigger.new, Trigger.oldMap);
        }
    }

    if (Trigger.isAfter) {
        ProposalTriggerHandler.afterAll(Trigger.new, Trigger.oldMap);
    }
}
