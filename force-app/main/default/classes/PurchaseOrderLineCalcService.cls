// ============================================================================
// PurchaseOrderLineCalcService
// - Handles quantity calculations for Purchase_Order_Line__c.
// - For each line:
//     * Converted_Internal_Quantity__c = Vendor_Quantity__c * Conversion_Factor__c
//     * If Internal_Quantity__c is null, default it to Converted_Internal_Quantity__c.
// - IMPORTANT: Line_Total__c is a formula field:
//     Line_Total__c = Vendor_Quantity__c * Cost_Per_Vendor_Unit__c
//   This class intentionally does NOT touch Line_Total__c.
// ============================================================================
public with sharing class PurchaseOrderLineCalcService {

    public static void calculate(List<Purchase_Order_Line__c> lines) {
        if (lines == null || lines.isEmpty()) return;

        for (Purchase_Order_Line__c pol : lines) {
            // Internal quantity from vendor quantity and conversion factor
            if (pol.Vendor_Quantity__c != null && pol.Conversion_Factor__c != null) {
                Decimal converted = pol.Vendor_Quantity__c * pol.Conversion_Factor__c;
                pol.Converted_Internal_Quantity__c = converted;

                // If internal quantity is blank, default it from converted
                if (pol.Internal_Quantity__c == null) {
                    pol.Internal_Quantity__c = converted;
                }
            }

            // DO NOT touch Line_Total__c here – it is a formula:
            // Line_Total__c = Vendor_Quantity__c * Cost_Per_Vendor_Unit__c
        }
    }
}
