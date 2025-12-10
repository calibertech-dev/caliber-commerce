// ============================================================================
// VendorProductAutoSourcingService
// - AFTER INSERT on Vendor_Product__c, auto-creates Product_Sourcing_Option__c
//   records where Product_Availability__c says we should.
// - Behavior:
//   For each new Vendor_Product__c (vp):
//     For each Product_Availability__c (pa) with:
//       - pa.Product__c = vp.Product__c
//       - pa.Business_Unit__c != null
//       - pa.Allow_Purchase__c = true
//       - pa.Auto_Create_Sourcing_Options__c = true
//       - pa.Is_Active__c = true
//       If no PSO exists for (BU, Vendor_Product):
//         Create PSO with BU, Product, Vendor, Vendor_Product, Min_Order_Quantity__c.
// - Failures are logged via ErrorLogService and DO NOT block insert.
// ============================================================================
public with sharing class VendorProductAutoSourcingService {

    public static void createForNewVendorProducts(List<Vendor_Product__c> newList) {
        if (newList == null || newList.isEmpty()) return;

        try {
            Set<Id> productIds = new Set<Id>();
            Set<Id> vendorProductIds = new Set<Id>();

            for (Vendor_Product__c vp : newList) {
                if (vp.Product__c != null) {
                    productIds.add(vp.Product__c);
                }
                if (vp.Id != null) {
                    vendorProductIds.add(vp.Id);
                }
            }

            if (productIds.isEmpty() || vendorProductIds.isEmpty()) {
                return;
            }

            // Product Availability: which BUs should auto-create sourcing options?
            List<Product_Availability__c> availabilities = [
                SELECT Id,
                       Business_Unit__c,
                       Product__c,
                       Allow_Purchase__c,
                       Auto_Create_Sourcing_Options__c,
                       Is_Active__c
                FROM Product_Availability__c
                WHERE Product__c IN :productIds
                  AND Allow_Purchase__c = true
                  AND Auto_Create_Sourcing_Options__c = true
                  AND Is_Active__c = true
            ];

            if (availabilities.isEmpty()) {
                return;
            }

            // Track which BUs we care about (for existing PSO lookup)
            Set<Id> buIds = new Set<Id>();
            for (Product_Availability__c pa : availabilities) {
                if (pa.Business_Unit__c != null) {
                    buIds.add(pa.Business_Unit__c);
                }
            }

            if (buIds.isEmpty()) {
                return;
            }

            // Existing Product Sourcing Options for (BU, Vendor_Product) combos
            List<Product_Sourcing_Option__c> existingPso = [
                SELECT Id, Business_Unit__c, Vendor_Product__c
                FROM Product_Sourcing_Option__c
                WHERE Vendor_Product__c IN :vendorProductIds
                  AND Business_Unit__c IN :buIds
            ];

            Set<String> existingKeys = new Set<String>();
            for (Product_Sourcing_Option__c pso : existingPso) {
                String key = pso.Business_Unit__c + '::' + pso.Vendor_Product__c;
                existingKeys.add(key);
            }

            // Group Product_Availability by Product__c for fast lookup
            Map<Id, List<Product_Availability__c>> paByProduct = new Map<Id, List<Product_Availability__c>>();
            for (Product_Availability__c pa : availabilities) {
                List<Product_Availability__c> bucket = paByProduct.get(pa.Product__c);
                if (bucket == null) {
                    bucket = new List<Product_Availability__c>();
                    paByProduct.put(pa.Product__c, bucket);
                }
                bucket.add(pa);
            }

            List<Product_Sourcing_Option__c> toInsert = new List<Product_Sourcing_Option__c>();

            for (Vendor_Product__c vp : newList) {
                if (vp.Id == null || vp.Product__c == null || vp.Vendor__c == null) {
                    // Cannot create a sourcing option without these identifiers
                    continue;
                }

                List<Product_Availability__c> paList = paByProduct.get(vp.Product__c);
                if (paList == null || paList.isEmpty()) {
                    continue;
                }

                for (Product_Availability__c pa : paList) {
                    if (pa.Business_Unit__c == null) continue;

                    String key = pa.Business_Unit__c + '::' + vp.Id;
                    if (existingKeys.contains(key)) {
                        // Already have a sourcing option for this BU + Vendor_Product
                        continue;
                    }

                    Product_Sourcing_Option__c newPso = new Product_Sourcing_Option__c();
                    newPso.Business_Unit__c         = pa.Business_Unit__c;
                    newPso.Product__c               = vp.Product__c;
                    newPso.Vendor_Product__c        = vp.Id;
                    newPso.Vendor__c                = vp.Vendor__c;
                    newPso.Min_Order_Quantity__c    = vp.Min_Order_Quantity__c;
                    newPso.Is_Active__c             = true;
                    // Intentionally not setting Is_Default__c – defaults should be explicit.

                    toInsert.add(newPso);
                }
            }

            if (!toInsert.isEmpty()) {
                insert toInsert;
            }

        } catch (Exception ex) {
            // Log but do NOT block Vendor_Product__c insert
            ErrorLogService.log(
                '[Caliber Core] Vendor Product auto sourcing',
                'Failed to auto-create Product Sourcing Options for new Vendor Products.',
                String.valueOf(ErrorLogService.Severity.ERROR),
                null,
                ex,
                JSON.serialize(newList),
                'APEX',
                'VendorProductAutoSourcingService',
                'createForNewVendorProducts',
                null,
                'Vendor_Product__c'
            );
        }
    }
}
