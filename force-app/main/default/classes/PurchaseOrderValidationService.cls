// ============================================================================
// PurchaseOrderValidationService
// - Enforces structural rules on Purchase_Order__c:
//   1) You cannot change Business_Unit__c if the PO has any line items.
//   2) You cannot delete a PO that has any line items.
// - Uses addError() for expected business validation; no ErrorLog.
// ============================================================================
public with sharing class PurchaseOrderValidationService {

    // Prevent BU change when PO has lines
    public static void preventBusinessUnitChangeWithLines(
        List<Purchase_Order__c> newList,
        List<Purchase_Order__c> oldList
    ) {
        if (newList == null || newList.isEmpty() || oldList == null) return;

        Set<Id> poIdsWithBuChange = new Set<Id>();
        Map<Id, Purchase_Order__c> poById = new Map<Id, Purchase_Order__c>();

        for (Integer i = 0; i < newList.size(); i++) {
            Purchase_Order__c poNew = newList[i];
            Purchase_Order__c poOld = oldList[i];

            if (poNew.Id == null) continue;

            poById.put(poNew.Id, poNew);

            if (poNew.Business_Unit__c != poOld.Business_Unit__c &&
                poOld.Business_Unit__c != null) {
                poIdsWithBuChange.add(poNew.Id);
            }
        }

        if (poIdsWithBuChange.isEmpty()) return;

        Set<Id> poIdsWithLines = new Set<Id>();
        for (AggregateResult ar : [
            SELECT Purchase_Order__c poId, COUNT(Id) cnt
            FROM Purchase_Order_Line__c
            WHERE Purchase_Order__c IN :poIdsWithBuChange
            GROUP BY Purchase_Order__c
            HAVING COUNT(Id) > 0
        ]) {
            poIdsWithLines.add((Id) ar.get('poId'));
        }

        for (Id poId : poIdsWithLines) {
            Purchase_Order__c po = poById.get(poId);
            if (po != null) {
                po.Business_Unit__c.addError(
                    'Cannot change Business Unit on a Purchase Order that has line items.'
                );
            }
        }
    }

    // Prevent delete when PO has lines
    public static void preventDeleteWhenLinesExist(List<Purchase_Order__c> oldList) {
        if (oldList == null || oldList.isEmpty()) return;

        Set<Id> poIds = new Set<Id>();
        Map<Id, Purchase_Order__c> poById = new Map<Id, Purchase_Order__c>();

        for (Purchase_Order__c po : oldList) {
            if (po.Id == null) continue;
            poIds.add(po.Id);
            poById.put(po.Id, po);
        }

        if (poIds.isEmpty()) return;

        Set<Id> poIdsWithLines = new Set<Id>();
        for (AggregateResult ar : [
            SELECT Purchase_Order__c poId, COUNT(Id) cnt
            FROM Purchase_Order_Line__c
            WHERE Purchase_Order__c IN :poIds
            GROUP BY Purchase_Order__c
            HAVING COUNT(Id) > 0
        ]) {
            poIdsWithLines.add((Id) ar.get('poId'));
        }

        for (Id poId : poIdsWithLines) {
            Purchase_Order__c po = poById.get(poId);
            if (po != null) {
                po.addError('Cannot delete a Purchase Order that has line items.');
            }
        }
    }
}
