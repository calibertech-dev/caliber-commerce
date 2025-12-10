// ============================================================================
// ProductSourcingOptionValidationService
// - Enforces uniqueness and default rules for PSO:
//   1) No duplicate PSO in a single transaction for (Business_Unit__c, Vendor_Product__c).
//   2) No duplicate default PSO in a single transaction for (Business_Unit__c, Product__c).
//   3) No existing PSO in the org for the same (Business_Unit__c, Vendor_Product__c).
//   4) No existing default PSO in the org for the same (Business_Unit__c, Product__c).
// - Uses addError() to block DML; no ErrorLog because this is expected
//   business validation.
// ============================================================================
public with sharing class ProductSourcingOptionValidationService {

    public static void validate(List<Product_Sourcing_Option__c> newList) {
        validate(newList, null);
    }

    public static void validate(
        List<Product_Sourcing_Option__c> newList,
        List<Product_Sourcing_Option__c> oldList
    ) {
        if (newList == null || newList.isEmpty()) return;

        // -------------------------------------------------------------
        // 1) In-scope duplicates for (Business_Unit__c, Vendor_Product__c)
        // -------------------------------------------------------------
        Map<String, List<Product_Sourcing_Option__c>> byBuVp = new Map<String, List<Product_Sourcing_Option__c>>();

        for (Product_Sourcing_Option__c pso : newList) {
            if (pso.Business_Unit__c == null || pso.Vendor_Product__c == null) continue;

            String key = pso.Business_Unit__c + '::' + pso.Vendor_Product__c;
            List<Product_Sourcing_Option__c> bucket = byBuVp.get(key);
            if (bucket == null) {
                bucket = new List<Product_Sourcing_Option__c>();
                byBuVp.put(key, bucket);
            }
            bucket.add(pso);
        }

        for (List<Product_Sourcing_Option__c> bucket : byBuVp.values()) {
            if (bucket.size() > 1) {
                for (Product_Sourcing_Option__c pso : bucket) {
                    pso.Vendor_Product__c.addError(
                        'Duplicate Product Sourcing Option for this Business Unit and Vendor Product in this operation.'
                    );
                }
            }
        }

        // ----------------------------------------------------------------
        // 2) In-scope duplicates for defaults per (Business_Unit__c, Product__c)
        // ----------------------------------------------------------------
        Map<String, List<Product_Sourcing_Option__c>> defaultByBuProd = new Map<String, List<Product_Sourcing_Option__c>>();

        for (Product_Sourcing_Option__c pso : newList) {
            if (pso.Is_Default__c != true) continue;
            if (pso.Business_Unit__c == null || pso.Product__c == null) continue;

            String key = pso.Business_Unit__c + '::' + pso.Product__c;
            List<Product_Sourcing_Option__c> bucket = defaultByBuProd.get(key);
            if (bucket == null) {
                bucket = new List<Product_Sourcing_Option__c>();
                defaultByBuProd.put(key, bucket);
            }
            bucket.add(pso);
        }

        for (List<Product_Sourcing_Option__c> bucket : defaultByBuProd.values()) {
            if (bucket.size() > 1) {
                for (Product_Sourcing_Option__c pso : bucket) {
                    pso.Is_Default__c.addError(
                        'Only one default Product Sourcing Option is allowed per Business Unit and Product in a single operation.'
                    );
                }
            }
        }

        // ----------------------------------------------------------------
        // 3) Cross-org uniqueness for (Business_Unit__c, Vendor_Product__c)
        // ----------------------------------------------------------------
        Set<Id> buIdsForBuVp = new Set<Id>();
        Set<Id> vpIdsForBuVp = new Set<Id>();
        Set<Id> scopeIds = new Set<Id>();

        for (Product_Sourcing_Option__c pso : newList) {
            if (pso.Business_Unit__c != null) {
                buIdsForBuVp.add(pso.Business_Unit__c);
            }
            if (pso.Vendor_Product__c != null) {
                vpIdsForBuVp.add(pso.Vendor_Product__c);
            }
            if (pso.Id != null) {
                scopeIds.add(pso.Id);
            }
        }

        if (!buIdsForBuVp.isEmpty() && !vpIdsForBuVp.isEmpty()) {
            List<Product_Sourcing_Option__c> existing = [
                SELECT Id, Business_Unit__c, Vendor_Product__c
                FROM Product_Sourcing_Option__c
                WHERE Business_Unit__c IN :buIdsForBuVp
                  AND Vendor_Product__c IN :vpIdsForBuVp
                  AND Id NOT IN :scopeIds
            ];

            Set<String> existingKeys = new Set<String>();
            for (Product_Sourcing_Option__c e : existing) {
                existingKeys.add(e.Business_Unit__c + '::' + e.Vendor_Product__c);
            }

            for (Product_Sourcing_Option__c pso : newList) {
                if (pso.Business_Unit__c == null || pso.Vendor_Product__c == null) continue;
                String key = pso.Business_Unit__c + '::' + pso.Vendor_Product__c;
                if (existingKeys.contains(key)) {
                    pso.Vendor_Product__c.addError(
                        'A Product Sourcing Option already exists for this Business Unit and Vendor Product.'
                    );
                }
            }
        }

        // ----------------------------------------------------------------
        // 4) Cross-org uniqueness for defaults per (Business_Unit__c, Product__c)
        // ----------------------------------------------------------------
        Set<Id> buIdsForDefault = new Set<Id>();
        Set<Id> prodIdsForDefault = new Set<Id>();
        Set<Id> scopeIdsDefaults = new Set<Id>();

        for (Product_Sourcing_Option__c pso : newList) {
            if (pso.Is_Default__c != true) continue;
            if (pso.Business_Unit__c != null) {
                buIdsForDefault.add(pso.Business_Unit__c);
            }
            if (pso.Product__c != null) {
                prodIdsForDefault.add(pso.Product__c);
            }
            if (pso.Id != null) {
                scopeIdsDefaults.add(pso.Id);
            }
        }

        if (!buIdsForDefault.isEmpty() && !prodIdsForDefault.isEmpty()) {
            List<Product_Sourcing_Option__c> existingDefaults = [
                SELECT Id, Business_Unit__c, Product__c
                FROM Product_Sourcing_Option__c
                WHERE Is_Default__c = true
                  AND Business_Unit__c IN :buIdsForDefault
                  AND Product__c IN :prodIdsForDefault
                  AND Id NOT IN :scopeIdsDefaults
            ];

            Set<String> existingDefaultKeys = new Set<String>();
            for (Product_Sourcing_Option__c e : existingDefaults) {
                existingDefaultKeys.add(e.Business_Unit__c + '::' + e.Product__c);
            }

            for (Product_Sourcing_Option__c pso : newList) {
                if (pso.Is_Default__c != true) continue;
                if (pso.Business_Unit__c == null || pso.Product__c == null) continue;

                String key = pso.Business_Unit__c + '::' + pso.Product__c;
                if (existingDefaultKeys.contains(key)) {
                    pso.Is_Default__c.addError(
                        'Only one default Product Sourcing Option is allowed per Business Unit and Product.'
                    );
                }
            }
        }
    }
}
