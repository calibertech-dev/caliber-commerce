trigger PaymentApplicationNumber_T on Payment_Application__c (before insert) {
    // Group by master Payment
    Set<Id> paymentIds = new Set<Id>();
    for (Payment_Application__c pa : Trigger.new) if (pa.Payment__c != null) paymentIds.add(pa.Payment__c);
    if (paymentIds.isEmpty()) return;

    // Existing count per Payment
    Map<Id, Integer> counts = new Map<Id, Integer>();
    for (AggregateResult ar : [
        SELECT Payment__c pid, COUNT(Id) c
        FROM Payment_Application__c
        WHERE Payment__c IN :paymentIds
        GROUP BY Payment__c
    ]) counts.put((Id)ar.get('pid'), (Integer)ar.get('c'));

    // Payment names
    Map<Id, Payment__c> pays = new Map<Id, Payment__c>([
        SELECT Id, Name FROM Payment__c WHERE Id IN :paymentIds
    ]);

    for (Payment_Application__c pa : Trigger.new) {
        if (pa.Payment__c == null) continue;
        Integer next = (counts.get(pa.Payment__c) == null ? 0 : counts.get(pa.Payment__c)) + 1;
        counts.put(pa.Payment__c, next);
        // Format: PAY-{00000000}-{n} (use the master Name verbatim to preserve its prefix/format)
        pa.Name = pays.get(pa.Payment__c).Name + '-' + String.valueOf(next);
    }
}
