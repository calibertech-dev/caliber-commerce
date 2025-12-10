// ============================================================================
// PurchaseOrderLineDefaultsService
// - Responsible for deriving PO line defaults FROM Product_Sourcing_Option__c,
//   Vendor_Product__c, and Product_UOM__c.
// - Triggers when Product_Sourcing_Option__c is set or changed.
// - Fills in (if blank):
//     * Product__c, Vendor__c, Vendor_Product__c
//     * Conversion_Factor__c, Vendor_UOM__c, Vendor_Quantity__c
//     * Cost_Per_Vendor_Unit__c (contract cost in range, else base cost)
//     * Internal_UOM__c (default Product_UOM__c)
//     * Description__c (from Vendor_Product__c.Vendor_Description__c)
// - SOQL failures are logged and rethrown.
// ============================================================================
public with sharing class PurchaseOrderLineDefaultsService {

    public static void applyDefaults(List<Purchase_Order_Line__c> newList) {
        applyDefaults(newList, null);
    }

    public static void applyDefaults(
        List<Purchase_Order_Line__c> newList,
        List<Purchase_Order_Line__c> oldList
    ) {
        if (newList == null || newList.isEmpty()) return;

        Boolean isInsert = (oldList == null);

        // Collect Product_Sourcing_Option__c Ids that are new/changed
        Set<Id> psoIds = new Set<Id>();
        for (Integer i = 0; i < newList.size(); i++) {
            Purchase_Order_Line__c pol = newList[i];

            if (isInsert) {
                if (pol.Product_Sourcing_Option__c != null) {
                    psoIds.add(pol.Product_Sourcing_Option__c);
                }
            } else {
                Purchase_Order_Line__c oldPol = oldList[i];
                if (pol.Product_Sourcing_Option__c != oldPol.Product_Sourcing_Option__c &&
                    pol.Product_Sourcing_Option__c != null) {
                    psoIds.add(pol.Product_Sourcing_Option__c);
                }
            }
        }

        if (psoIds.isEmpty()) {
            return;
        }

        Map<Id, Product_Sourcing_Option__c> psoById = new Map<Id, Product_Sourcing_Option__c>();
        Map<Id, Vendor_Product__c> vpById = new Map<Id, Vendor_Product__c>();
        Map<Id, Product_UOM__c> defaultUomByProduct = new Map<Id, Product_UOM__c>();

        try {
            // Pull PSOs for the lines we care about
            psoById = new Map<Id, Product_Sourcing_Option__c>(
                [
                    SELECT Id,
                           Business_Unit__c,
                           Product__c,
                           Vendor__c,
                           Vendor_Product__c,
                           Min_Order_Quantity__c,
                           Contract_Cost_Per_Vendor_Unit__c,
                           Contract_Discount_Percent__c,
                           Effective_From__c,
                           Effective_To__c
                    FROM Product_Sourcing_Option__c
                    WHERE Id IN :psoIds
                ]
            );

            // Collect Vendor_Product and Product Ids
            Set<Id> vendorProductIds = new Set<Id>();
            Set<Id> productIds = new Set<Id>();

            for (Product_Sourcing_Option__c pso : psoById.values()) {
                if (pso.Vendor_Product__c != null) {
                    vendorProductIds.add(pso.Vendor_Product__c);
                }
                if (pso.Product__c != null) {
                    productIds.add(pso.Product__c);
                }
            }

            if (!vendorProductIds.isEmpty()) {
                vpById = new Map<Id, Vendor_Product__c>(
                    [
                        SELECT Id,
                               Vendor__c,
                               Product__c,
                               Conversion_Factor__c,
                               Vendor_UOM__c,
                               Min_Order_Quantity__c,
                               Base_Cost_Per_Vendor_Unit__c,
                               Vendor_Description__c
                        FROM Vendor_Product__c
                        WHERE Id IN :vendorProductIds
                    ]
                );
            }

            if (!productIds.isEmpty()) {
                // Default internal UOM per product (Is_Default__c & Is_Active__c)
                List<Product_UOM__c> uoms = [
                    SELECT Id,
                           Product__c,
                           Unit_of_Measure__c,
                           Conversion_to_Base__c,
                           Is_Active__c,
                           Is_Default__c
                    FROM Product_UOM__c
                    WHERE Product__c IN :productIds
                      AND Is_Active__c = true
                      AND Is_Default__c = true
                ];
                for (Product_UOM__c u : uoms) {
                    // One default per product – if there are multiple, last-in wins
                    defaultUomByProduct.put(u.Product__c, u);
                }
            }
        } catch (Exception ex) {
            ErrorLogService.log(
                '[Caliber Commerce] PO Line defaults',
                'Failed querying Product_Sourcing_Option__c / Vendor_Product__c / Product_UOM__c while applying defaults.',
                String.valueOf(ErrorLogService.Severity.ERROR),
                null,
                ex,
                JSON.serialize(newList),
                'APEX',
                'PurchaseOrderLineDefaultsService',
                'applyDefaults',
                null,
                'Purchase_Order_Line__c'
            );
            throw ex;
        }

        Date today = Date.today();

        // Apply derived values for each line with a PSO
        for (Purchase_Order_Line__c pol : newList) {
            if (pol.Product_Sourcing_Option__c == null) continue;

            Product_Sourcing_Option__c pso = psoById.get(pol.Product_Sourcing_Option__c);
            if (pso == null) continue;

            Vendor_Product__c vp = (pso.Vendor_Product__c != null)
                ? vpById.get(pso.Vendor_Product__c)
                : null;

            // ---- Identifiers (Product, Vendor, VP) ----
            if (pol.Product__c == null && pso.Product__c != null) {
                pol.Product__c = pso.Product__c;
            }
            if (pol.Vendor__c == null && pso.Vendor__c != null) {
                pol.Vendor__c = pso.Vendor__c;
            }
            if (pol.Vendor_Product__c == null && pso.Vendor_Product__c != null) {
                pol.Vendor_Product__c = pso.Vendor_Product__c;
            }

            // ---- Vendor-side quantities & UOM from Vendor_Product__c ----
            if (vp != null) {
                if (pol.Conversion_Factor__c == null && vp.Conversion_Factor__c != null) {
                    pol.Conversion_Factor__c = vp.Conversion_Factor__c;
                }
                if (pol.Vendor_UOM__c == null && vp.Vendor_UOM__c != null) {
                    pol.Vendor_UOM__c = vp.Vendor_UOM__c;
                }
                if (pol.Vendor_Quantity__c == null && vp.Min_Order_Quantity__c != null) {
                    pol.Vendor_Quantity__c = vp.Min_Order_Quantity__c;
                }
            }

            // ---- If PSO has a specific min order, prefer that if vendor qty still null ----
            if (pol.Vendor_Quantity__c == null && pso.Min_Order_Quantity__c != null) {
                pol.Vendor_Quantity__c = pso.Min_Order_Quantity__c;
            }

            // ---- Cost: contract cost if in effective range, else base cost from Vendor_Product__c ----
            if (pol.Cost_Per_Vendor_Unit__c == null) {
                Boolean contractInRange = false;
                if (pso.Contract_Cost_Per_Vendor_Unit__c != null) {
                    Boolean fromOk = (pso.Effective_From__c == null || pso.Effective_From__c <= today);
                    Boolean toOk   = (pso.Effective_To__c   == null || pso.Effective_To__c   >= today);
                    contractInRange = fromOk && toOk;
                }
                if (contractInRange) {
                    pol.Cost_Per_Vendor_Unit__c = pso.Contract_Cost_Per_Vendor_Unit__c;
                } else if (vp != null && vp.Base_Cost_Per_Vendor_Unit__c != null) {
                    pol.Cost_Per_Vendor_Unit__c = vp.Base_Cost_Per_Vendor_Unit__c;
                }
            }

            // ---- Internal UOM: from Product_UOM default ----
            if (pol.Internal_UOM__c == null && pol.Product__c != null) {
                Product_UOM__c defaultUom = defaultUomByProduct.get(pol.Product__c);
                if (defaultUom != null && defaultUom.Unit_of_Measure__c != null) {
                    pol.Internal_UOM__c = defaultUom.Unit_of_Measure__c;
                }
            }

            // ---- Description: fall back to vendor description if blank ----
            if (pol.Description__c == null && vp != null && vp.Vendor_Description__c != null) {
                pol.Description__c = vp.Vendor_Description__c;
            }
        }
    }
}
