trigger ContractAmendmentNumber_T on Contract_Amendment__c (before insert) {
    Set<Id> contractIds = new Set<Id>();
    for (Contract_Amendment__c ca : Trigger.new) if (ca.Contract__c != null) contractIds.add(ca.Contract__c);
    if (contractIds.isEmpty()) return;

    Map<Id, Integer> counts = new Map<Id, Integer>();
    for (AggregateResult ar : [
        SELECT Contract__c c, COUNT(Id) cnt
        FROM Contract_Amendment__c
        WHERE Contract__c IN :contractIds
        GROUP BY Contract__c
    ]) counts.put((Id)ar.get('c'), (Integer)ar.get('cnt'));

    Map<Id, Contract__c> cons = new Map<Id, Contract__c>([
        SELECT Id, Name, Contract_Title__c, Billing_Group_Key__c
        FROM Contract__c WHERE Id IN :contractIds
    ]);

    for (Contract_Amendment__c ca : Trigger.new) {
        if (ca.Contract__c == null) continue;
        Integer next = (counts.get(ca.Contract__c) == null ? 0 : counts.get(ca.Contract__c)) + 1;
        counts.put(ca.Contract__c, next);
        String base = cons.get(ca.Contract__c).Name;
        ca.Name = base + '-' + String.valueOf(next);
        // keep Billing Group aligned if you want
        if (ca.Billing_Group_Key__c == null) ca.Billing_Group_Key__c = cons.get(ca.Contract__c).Billing_Group_Key__c;
    }
}
