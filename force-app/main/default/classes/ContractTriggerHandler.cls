public with sharing class ContractTriggerHandler {

    public static void beforeInsert(List<Contract__c> newList) {
        applyFeeLogic(newList, null);
    }

    public static void beforeUpdate(List<Contract__c> newList, Map<Id, Contract__c> oldMap) {
        applyFeeLogic(newList, oldMap);
    }

    private static void applyFeeLogic(List<Contract__c> newList, Map<Id, Contract__c> oldMap) {
        for (Contract__c c : newList) {
            Contract__c oldC = (oldMap == null) ? null : oldMap.get(c.Id);

            Boolean proposalChanged = (oldC == null) ||
                                    (c.Proposal_Amount__c != oldC.Proposal_Amount__c);
            Boolean allowUpdate = !c.Override_Fee__c;

            if (allowUpdate && proposalChanged) {
                c.Contract_Fee__c = c.Proposal_Amount__c;
            }

            // --- NEW LOGIC: update words when fee changes ---
            Boolean feeChanged = (oldC == null) ||
                                (c.Contract_Fee__c != oldC.Contract_Fee__c);

            if (feeChanged && c.Contract_Fee__c != null) {
                c.Written_Amount__c = NumberToWordsConverter.convert(c.Contract_Fee__c);
            }
        }
    }

}
