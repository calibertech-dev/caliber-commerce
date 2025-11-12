trigger Contract_Fee_T on Contract__c (before insert, before update) {
    for (Contract__c c : Trigger.new) {
        Contract__c oldC = Trigger.isUpdate ? Trigger.oldMap.get(c.Id) : null;

        // Only recalc if not overridden and Proposal_Amount__c actually changed
        Boolean proposalChanged = (oldC == null) || (c.Proposal_Amount__c != oldC.Proposal_Amount__c);
        Boolean allowUpdate = !c.Override_Fee__c;

        if (allowUpdate && proposalChanged) {
            c.Contract_Fee__c = c.Proposal_Amount__c; // mirror automatically
        }
    }
}
