// ============================================================================
// ProductSourcingOptionDefaultsService
// - Responsible for "filling in" PSO fields based on the Vendor_Product__c
//   reference.
// - On INSERT:
//     * Defaults Is_Active__c to true if null.
//     * For PSOs with Vendor_Product__c set, populates:
//         - Vendor__c from Vendor_Product__c.Vendor__c
//         - Product__c from Vendor_Product__c.Product__c
//         - Min_Order_Quantity__c from Vendor_Product__c.Min_Order_Quantity__c
// - On UPDATE:
//     * If Vendor_Product__c changes, re-derives the above fields, but only
//       where PSO fields are currently null, so users can override.
// - SOQL failures are logged and rethrown.
// ============================================================================
public with sharing class ProductSourcingOptionDefaultsService {

    public static void applyDefaults(List<Product_Sourcing_Option__c> newList) {
        applyDefaults(newList, null);
    }

    public static void applyDefaults(
        List<Product_Sourcing_Option__c> newList,
        List<Product_Sourcing_Option__c> oldList
    ) {
        if (newList == null || newList.isEmpty()) return;

        Boolean isInsert = (oldList == null);
        Set<Id> vendorProductIds = new Set<Id>();

        // Determine which Vendor_Product__c records we need to query
        for (Integer i = 0; i < newList.size(); i++) {
            Product_Sourcing_Option__c pso = newList[i];

            // Default Is_Active__c on insert if not explicitly set
            if (isInsert && pso.Is_Active__c == null) {
                pso.Is_Active__c = true;
            }

            // Track Vendor_Product__c changes that require re-deriving fields
            if (isInsert) {
                if (pso.Vendor_Product__c != null) {
                    vendorProductIds.add(pso.Vendor_Product__c);
                }
            } else {
                Product_Sourcing_Option__c oldPso = oldList[i];
                if (pso.Vendor_Product__c != oldPso.Vendor_Product__c &&
                    pso.Vendor_Product__c != null) {
                    vendorProductIds.add(pso.Vendor_Product__c);
                }
            }
        }

        Map<Id, Vendor_Product__c> vendorProductById = new Map<Id, Vendor_Product__c>();
        if (!vendorProductIds.isEmpty()) {
            try {
                vendorProductById = new Map<Id, Vendor_Product__c>(
                    [
                        SELECT Id,
                               Vendor__c,
                               Product__c,
                               Min_Order_Quantity__c
                        FROM Vendor_Product__c
                        WHERE Id IN :vendorProductIds
                    ]
                );
            } catch (Exception ex) {
                // This is a system-level failure: log it and rethrow.
                ErrorLogService.log(
                    '[Caliber Core] Product Sourcing Option defaults',
                    'Failed to query Vendor_Product__c while applying defaults.',
                    String.valueOf(ErrorLogService.Severity.ERROR),
                    null,
                    ex,
                    JSON.serialize(newList),
                    'APEX',
                    'ProductSourcingOptionDefaultsService',
                    'applyDefaults',
                    null,
                    'Product_Sourcing_Option__c'
                );
                throw ex;
            }
        }

        // Apply defaults from Vendor_Product__c whenever PSO has a VP reference
        for (Product_Sourcing_Option__c pso : newList) {
            if (pso.Vendor_Product__c == null) continue;

            Vendor_Product__c vp = vendorProductById.get(pso.Vendor_Product__c);
            if (vp == null) continue;

            // Only overwrite if target is null – user can override manually if they want.
            if (pso.Vendor__c == null && vp.Vendor__c != null) {
                pso.Vendor__c = vp.Vendor__c;
            }
            if (pso.Product__c == null && vp.Product__c != null) {
                pso.Product__c = vp.Product__c;
            }
            if (pso.Min_Order_Quantity__c == null && vp.Min_Order_Quantity__c != null) {
                pso.Min_Order_Quantity__c = vp.Min_Order_Quantity__c;
            }
        }
    }
}
