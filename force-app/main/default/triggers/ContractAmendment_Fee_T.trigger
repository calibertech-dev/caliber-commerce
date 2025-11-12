trigger ContractAmendment_Fee_T on Contract_Amendment__c (before insert, before update) {
    for (Contract_Amendment__c a : Trigger.new) {
        Contract_Amendment__c oldA = Trigger.isUpdate ? Trigger.oldMap.get(a.Id) : null;

        Boolean proposalChanged = (oldA == null) || (a.Proposal_Amount__c != oldA.Proposal_Amount__c);
        Boolean allowUpdate = !a.Override_Fee__c;

        if (allowUpdate && proposalChanged) {
            a.Contract_Fee__c = a.Proposal_Amount__c;
        }
    }
}
