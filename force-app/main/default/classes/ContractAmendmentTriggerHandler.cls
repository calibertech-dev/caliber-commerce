public with sharing class ContractAmendmentTriggerHandler {

    public static void beforeInsert(List<Contract_Amendment__c> newList) {
        if (newList == null || newList.isEmpty()) return;

        // 1) Service Relationship assignment
        ServiceRelationshipAssignmentService.assign(newList);

        // 2) Fee + numbering logic
        applyFeeLogic(newList, null);
        assignNumbers(newList);
    }

    public static void beforeUpdate(List<Contract_Amendment__c> newList,
                                    Map<Id, Contract_Amendment__c> oldMap) {
        if (newList == null || newList.isEmpty()) return;

        // 1) Service Relationship assignment
        ServiceRelationshipAssignmentService.assign(newList);

        // 2) Fee logic
        applyFeeLogic(newList, oldMap);
    }

    // ---------- Fee Logic ----------
    private static void applyFeeLogic(List<Contract_Amendment__c> newList,
                                      Map<Id, Contract_Amendment__c> oldMap) {
        for (Contract_Amendment__c a : newList) {
            Contract_Amendment__c oldA = (oldMap == null) ? null : oldMap.get(a.Id);

            Boolean proposalChanged = (oldA == null) ||
                                      (a.Proposal_Amount__c != oldA.Proposal_Amount__c);
            Boolean allowUpdate    = !a.Override_Fee__c;

            if (allowUpdate && proposalChanged) {
                a.Contract_Fee__c = a.Proposal_Amount__c;
            }
        }
    }

    // ---------- Numbering Logic ----------
    private static void assignNumbers(List<Contract_Amendment__c> newList) {
        Set<Id> contractIds = new Set<Id>();
        for (Contract_Amendment__c ca : newList) {
            if (ca.Contract__c != null) {
                contractIds.add(ca.Contract__c);
            }
        }
        if (contractIds.isEmpty()) {
            return;
        }

        Map<Id, Integer> counts = new Map<Id, Integer>();
        for (AggregateResult ar : [
            SELECT Contract__c c, COUNT(Id) cnt
            FROM Contract_Amendment__c
            WHERE Contract__c IN :contractIds
            GROUP BY Contract__c
        ]) {
            counts.put((Id) ar.get('c'), (Integer) ar.get('cnt'));
        }

        Map<Id, Contract__c> cons = new Map<Id, Contract__c>([
            SELECT Id, Name, Contract_Title__c, Billing_Group_Key__c
            FROM Contract__c
            WHERE Id IN :contractIds
        ]);

        for (Contract_Amendment__c ca : newList) {
            if (ca.Contract__c == null) continue;

            Integer next = (counts.get(ca.Contract__c) == null ? 0 : counts.get(ca.Contract__c)) + 1;
            counts.put(ca.Contract__c, next);

            String baseName = cons.get(ca.Contract__c).Name;
            ca.Name = baseName + '-' + String.valueOf(next);

            if (ca.Billing_Group_Key__c == null) {
                ca.Billing_Group_Key__c = cons.get(ca.Contract__c).Billing_Group_Key__c;
            }
        }
    }
}
