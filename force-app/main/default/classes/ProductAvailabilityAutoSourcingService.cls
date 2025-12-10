// ============================================================================
// ProductAvailabilityAutoSourcingService
// - Creates Product_Sourcing_Option__c records when a Product_Availability__c
//   becomes "eligible", defined as:
//     * Is_Active__c = true
//     * Allow_Purchase__c = true
//     * Auto_Create_Sourcing_Options__c = true
//     * Business_Unit__c != null
//     * Product__c != null
// - On INSERT: any row that is eligible now.
// - On UPDATE: only when transitioning from not-eligible -> eligible.
// - For each eligible PA, and for each active Vendor_Product__c for that
//   Product__c, creates a PSO per BU if one does not already exist.
// - Failures are logged and do NOT block the PA DML.
// ============================================================================
public with sharing class ProductAvailabilityAutoSourcingService {

    public static void autoCreateSourcingOptions(
        List<Product_Availability__c> newList,
        List<Product_Availability__c> oldList
    ) {
        if (newList == null || newList.isEmpty()) return;

        try {
            Boolean isInsert = (oldList == null);

            // 1) Identify Product_Availability__c records that should trigger auto-sourcing
            List<Product_Availability__c> eligible = new List<Product_Availability__c>();

            for (Integer i = 0; i < newList.size(); i++) {
                Product_Availability__c pa = newList[i];

                Boolean nowEligible =
                    pa.Is_Active__c == true &&
                    pa.Allow_Purchase__c == true &&
                    pa.Auto_Create_Sourcing_Options__c == true &&
                    pa.Business_Unit__c != null &&
                    pa.Product__c != null;

                if (isInsert) {
                    // New records: if they're already eligible, we act on them.
                    if (nowEligible) {
                        eligible.add(pa);
                    }
                } else {
                    Product_Availability__c oldPa = oldList[i];
                    Boolean wasEligible =
                        oldPa.Is_Active__c == true &&
                        oldPa.Allow_Purchase__c == true &&
                        oldPa.Auto_Create_Sourcing_Options__c == true &&
                        oldPa.Business_Unit__c != null &&
                        oldPa.Product__c != null;

                    // Only trigger when transitioning from not-eligible → eligible
                    if (!wasEligible && nowEligible) {
                        eligible.add(pa);
                    }
                }
            }

            if (eligible.isEmpty()) {
                return;
            }

            // 2) Collect BU and Product ids
            Set<Id> buIds = new Set<Id>();
            Set<Id> productIds = new Set<Id>();

            for (Product_Availability__c pa : eligible) {
                buIds.add(pa.Business_Unit__c);
                productIds.add(pa.Product__c);
            }

            if (buIds.isEmpty() || productIds.isEmpty()) {
                return;
            }

            // 3) Find all active Vendor_Product__c for these Products
            List<Vendor_Product__c> vendorProducts = [
                SELECT Id,
                       Vendor__c,
                       Product__c,
                       Min_Order_Quantity__c,
                       Is_Active__c
                FROM Vendor_Product__c
                WHERE Product__c IN :productIds
                  AND Is_Active__c = true
            ];

            if (vendorProducts.isEmpty()) {
                return;
            }

            Set<Id> vendorProductIds = new Set<Id>();
            for (Vendor_Product__c vp : vendorProducts) {
                vendorProductIds.add(vp.Id);
            }

            // 4) Find existing Product_Sourcing_Option__c for these BUs + Vendor_Products
            List<Product_Sourcing_Option__c> existingPso = [
                SELECT Id, Business_Unit__c, Vendor_Product__c
                FROM Product_Sourcing_Option__c
                WHERE Business_Unit__c IN :buIds
                  AND Vendor_Product__c IN :vendorProductIds
            ];

            Set<String> existingKeys = new Set<String>();
            for (Product_Sourcing_Option__c pso : existingPso) {
                String key = pso.Business_Unit__c + '::' + pso.Vendor_Product__c;
                existingKeys.add(key);
            }

            // 5) Group Vendor_Product__c by Product__c for fast lookup
            Map<Id, List<Vendor_Product__c>> vpByProduct = new Map<Id, List<Vendor_Product__c>>();
            for (Vendor_Product__c vp : vendorProducts) {
                List<Vendor_Product__c> bucket = vpByProduct.get(vp.Product__c);
                if (bucket == null) {
                    bucket = new List<Vendor_Product__c>();
                    vpByProduct.put(vp.Product__c, bucket);
                }
                bucket.add(vp);
            }

            // 6) Create missing Product_Sourcing_Option__c records
            List<Product_Sourcing_Option__c> toInsert = new List<Product_Sourcing_Option__c>();

            for (Product_Availability__c pa : eligible) {
                List<Vendor_Product__c> vpList = vpByProduct.get(pa.Product__c);
                if (vpList == null || vpList.isEmpty()) continue;

                for (Vendor_Product__c vp : vpList) {
                    if (vp.Vendor__c == null) continue;

                    String key = pa.Business_Unit__c + '::' + vp.Id;
                    if (existingKeys.contains(key)) {
                        // Already have a PSO for this BU + Vendor_Product
                        continue;
                    }

                    Product_Sourcing_Option__c newPso = new Product_Sourcing_Option__c();
                    newPso.Business_Unit__c      = pa.Business_Unit__c;
                    newPso.Product__c            = vp.Product__c;
                    newPso.Vendor_Product__c     = vp.Id;
                    newPso.Vendor__c             = vp.Vendor__c;
                    newPso.Min_Order_Quantity__c = vp.Min_Order_Quantity__c;
                    newPso.Is_Active__c          = true;
                    // Leave Is_Default__c null – defaults should be explicit decisions.

                    toInsert.add(newPso);
                }
            }

            if (!toInsert.isEmpty()) {
                insert toInsert;
            }

        } catch (Exception ex) {
            // Log but do not block Product_Availability__c insert/update
            ErrorLogService.log(
                '[Caliber Core] Product Availability auto sourcing',
                'Failed to auto-create Product Sourcing Options for Product Availability changes.',
                String.valueOf(ErrorLogService.Severity.ERROR),
                null,
                ex,
                JSON.serialize(newList),
                'APEX',
                'ProductAvailabilityAutoSourcingService',
                'autoCreateSourcingOptions',
                null,
                'Product_Availability__c'
            );
        }
    }
}
