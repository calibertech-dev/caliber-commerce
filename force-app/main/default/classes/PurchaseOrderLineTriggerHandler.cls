// ============================================================================
// PurchaseOrderLineTriggerHandler
// - BEFORE INSERT/UPDATE:
//     * PurchaseOrderLineDefaultsService.applyDefaults
//         - Fill in Product__c, Vendor__c, Vendor_Product__c, Vendor/UOM,
//           MOQ, cost, internal UOM, etc.
//     * PurchaseOrderLineCalcService.calculate
//         - Compute Converted_Internal_Quantity__c and default Internal_Quantity__c.
// - AFTER INSERT/UPDATE/DELETE/UNDELETE:
//     * PurchaseOrderRollupService.recalculateForLines
//         - Recomputes header-level subtotal, quantities, and Status__c.
// ============================================================================
public with sharing class PurchaseOrderLineTriggerHandler {

    public static void run() {
        if (Trigger.isBefore) {
            handleBefore(Trigger.operationType, Trigger.new, Trigger.old);
        }
        if (Trigger.isAfter) {
            handleAfter(Trigger.operationType, Trigger.new, Trigger.old);
        }
    }

    private static void handleBefore(
        System.TriggerOperation operationType,
        List<Purchase_Order_Line__c> newList,
        List<Purchase_Order_Line__c> oldList
    ) {
        switch on operationType {
            when BEFORE_INSERT {
                PurchaseOrderLineDefaultsService.applyDefaults(newList);
                PurchaseOrderLineCalcService.calculate(newList);
            }
            when BEFORE_UPDATE {
                PurchaseOrderLineDefaultsService.applyDefaults(newList, oldList);
                PurchaseOrderLineCalcService.calculate(newList);
            }
            when else {
                // no-op
            }
        }
    }

    private static void handleAfter(
        System.TriggerOperation operationType,
        List<Purchase_Order_Line__c> newList,
        List<Purchase_Order_Line__c> oldList
    ) {
        switch on operationType {
            when AFTER_INSERT, AFTER_UPDATE, AFTER_UNDELETE, AFTER_DELETE {
                PurchaseOrderRollupService.recalculateForLines(
                    newList,
                    oldList,
                    operationType
                );
            }
            when else {
                // no-op
            }
        }
    }
}
