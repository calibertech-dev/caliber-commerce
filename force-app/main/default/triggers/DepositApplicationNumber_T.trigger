trigger DepositApplicationNumber_T on Deposit_Application__c (before insert) {
    Set<Id> depIds = new Set<Id>();
    for (Deposit_Application__c da : Trigger.new) if (da.Deposit__c != null) depIds.add(da.Deposit__c);
    if (depIds.isEmpty()) return;

    Map<Id, Integer> counts = new Map<Id, Integer>();
    for (AggregateResult ar : [
        SELECT Deposit__c did, COUNT(Id) c
        FROM Deposit_Application__c
        WHERE Deposit__c IN :depIds
        GROUP BY Deposit__c
    ]) counts.put((Id)ar.get('did'), (Integer)ar.get('c'));

    Map<Id, Deposit__c> deps = new Map<Id, Deposit__c>([
        SELECT Id, Name FROM Deposit__c WHERE Id IN :depIds
    ]);

    for (Deposit_Application__c da : Trigger.new) {
        if (da.Deposit__c == null) continue;
        Integer next = (counts.get(da.Deposit__c) == null ? 0 : counts.get(da.Deposit__c)) + 1;
        counts.put(da.Deposit__c, next);
        // Format: DEP-{00000000}-{n} (uses the master Name verbatim)
        da.Name = deps.get(da.Deposit__c).Name + '-' + String.valueOf(next);
    }
}
