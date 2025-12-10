// ============================================================================
// PurchaseOrderRollupService
// - Responsible for rolling up line-level data to Purchase_Order__c:
//     * Subtotal__c (sum of Line_Total__c, ignoring cancelled lines)
//     * Total_Internal_Quantity__c (sum of Internal_Quantity__c, ignoring cancelled)
//     * Received_Internal_Quantity__c (sum of Received_Quantity_Internal__c, ignoring cancelled)
//     * Status__c derived from line statuses and quantities:
//         - 'Cancelled': all lines Cancelled
//         - 'Received': all non-cancelled lines fully received by qty
//         - 'Partially_Received': mix of received/partially-received lines
//         - 'Ordered': at least one Ordered line, but nothing received
//         - 'Draft': lines exist but no meaningful status yet
// - Uses ErrorLogService for system failures.
// ============================================================================
public with sharing class PurchaseOrderRollupService {

    public static void recalculateForLines(
        List<Purchase_Order_Line__c> newList,
        List<Purchase_Order_Line__c> oldList,
        System.TriggerOperation op
    ) {
        Set<Id> poIds = new Set<Id>();

        // Determine which Purchase Orders were touched based on operation
        if (op == System.TriggerOperation.AFTER_INSERT ||
            op == System.TriggerOperation.AFTER_UPDATE ||
            op == System.TriggerOperation.AFTER_UNDELETE) {

            if (newList != null) {
                for (Purchase_Order_Line__c pol : newList) {
                    if (pol.Purchase_Order__c != null) {
                        poIds.add(pol.Purchase_Order__c);
                    }
                }
            }
        }

        if (op == System.TriggerOperation.AFTER_DELETE) {
            if (oldList != null) {
                for (Purchase_Order_Line__c pol : oldList) {
                    if (pol.Purchase_Order__c != null) {
                        poIds.add(pol.Purchase_Order__c);
                    }
                }
            }
        }

        if (poIds.isEmpty()) return;

        recalculateForPurchaseOrders(poIds);
    }

    public static void recalculateForPurchaseOrders(Set<Id> poIds) {
        if (poIds == null || poIds.isEmpty()) return;

        Map<Id, Purchase_Order__c> poById = new Map<Id, Purchase_Order__c>(
            [
                SELECT Id, Status__c
                FROM Purchase_Order__c
                WHERE Id IN :poIds
            ]
        );

        if (poById.isEmpty()) return;

        // Aggregate line data per PO
        Map<Id, AggregateData> aggByPoId = new Map<Id, AggregateData>();

        try {
            for (Purchase_Order_Line__c pol : [
                SELECT Id,
                       Purchase_Order__c,
                       Line_Total__c,
                       Internal_Quantity__c,
                       Received_Quantity_Internal__c,
                       Status__c
                FROM Purchase_Order_Line__c
                WHERE Purchase_Order__c IN :poIds
            ]) {
                if (pol.Purchase_Order__c == null) continue;

                AggregateData agg = aggByPoId.get(pol.Purchase_Order__c);
                if (agg == null) {
                    agg = new AggregateData();
                    aggByPoId.put(pol.Purchase_Order__c, agg);
                }

                agg.anyLines = true;

                Boolean isCancelled = (pol.Status__c == 'Cancelled');

                // Totals ignore cancelled lines
                if (!isCancelled) {
                    if (pol.Line_Total__c != null) {
                        agg.subtotal += pol.Line_Total__c;
                    }
                    if (pol.Internal_Quantity__c != null) {
                        agg.totalInternalQty += pol.Internal_Quantity__c;
                    }
                    if (pol.Received_Quantity_Internal__c != null) {
                        agg.totalReceivedInternalQty += pol.Received_Quantity_Internal__c;
                    }
                }

                // Status flags (consider all lines, even cancelled, for lifecycle)
                if (pol.Status__c == 'Cancelled') {
                    agg.hasCancelled = true;
                    // allCancelled stays true unless we see a non-cancelled line
                } else {
                    agg.allCancelled = false;
                }

                if (pol.Status__c == 'Received') {
                    agg.anyReceived = true;
                }
                if (pol.Status__c == 'Partially_Received') {
                    agg.anyPartiallyReceived = true;
                }
                if (pol.Status__c == 'Ordered') {
                    agg.anyOrdered = true;
                }

                // Quantity-based "all received" check on non-cancelled lines
                if (!isCancelled) {
                    if (pol.Internal_Quantity__c != null &&
                        pol.Received_Quantity_Internal__c != null &&
                        pol.Received_Quantity_Internal__c >= pol.Internal_Quantity__c) {
                        // fully received line – fine
                    } else {
                        agg.allReceivedByQty = false;
                    }
                }
            }

        } catch (Exception ex) {
            ErrorLogService.log(
                '[Caliber Commerce] PO rollup',
                'Failed to roll up Purchase Order totals from lines.',
                String.valueOf(ErrorLogService.Severity.ERROR),
                null,
                ex,
                JSON.serialize(new List<Id>(poIds)),
                'APEX',
                'PurchaseOrderRollupService',
                'recalculateForPurchaseOrders',
                null,
                'Purchase_Order__c'
            );
            throw ex;
        }

        List<Purchase_Order__c> toUpdate = new List<Purchase_Order__c>();

        for (Id poId : poById.keySet()) {
            Purchase_Order__c po = poById.get(poId);
            AggregateData agg = aggByPoId.get(poId);

            if (agg == null || !agg.anyLines) {
                // No lines – zero out rollup fields and leave Status__c alone
                // (or "Draft" via validation/defaults elsewhere)
                po.Subtotal__c                   = 0;
                po.Total_Internal_Quantity__c    = 0;
                po.Received_Internal_Quantity__c = 0;
                toUpdate.add(po);
                continue;
            }

            // Set monetary & quantity rollups
            po.Subtotal__c                   = agg.subtotal;
            po.Total_Internal_Quantity__c    = agg.totalInternalQty;
            po.Received_Internal_Quantity__c = agg.totalReceivedInternalQty;

            // Derive Status__c from line state.
            String newStatus;

            if (agg.allCancelled && agg.anyLines) {
                newStatus = 'Cancelled';
            } else if (agg.allReceivedByQty && agg.totalInternalQty > 0) {
                newStatus = 'Received';
            } else if (agg.anyPartiallyReceived || (agg.anyReceived && agg.totalReceivedInternalQty > 0)) {
                newStatus = 'Partially_Received';
            } else if (agg.anyOrdered) {
                newStatus = 'Ordered';
            } else {
                // Fallback if lines exist but none are ordered/received/cancelled in a meaningful way
                newStatus = 'Draft';
            }

            po.Status__c = newStatus;
            toUpdate.add(po);
        }

        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }

    // Helper aggregation bucket per PO
    private class AggregateData {
        Decimal subtotal                 = 0;
        Decimal totalInternalQty         = 0;
        Decimal totalReceivedInternalQty = 0;

        Boolean anyLines              = false;
        Boolean anyOrdered            = false;
        Boolean anyReceived           = false;
        Boolean anyPartiallyReceived  = false;
        Boolean hasCancelled          = false;

        Boolean allCancelled          = true;  // assume true until we see non-cancelled
        Boolean allReceivedByQty      = true;  // assume true until we see a not-fully-received non-cancelled line
    }
}
