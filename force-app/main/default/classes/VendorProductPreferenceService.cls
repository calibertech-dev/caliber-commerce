// ============================================================================
// VendorProductPreferenceService
// - Enforces the rule:
//   "For any given Product__c, there can be at most ONE active preferred
//    Vendor_Product__c (Is_Preferred__c = true AND Is_Active__c = true)."
// - Applies both:
//   1) Within the current transaction (multiple records in Trigger.new)
//   2) Against existing DB records
// - Uses addError() to block invalid DML (no ErrorLog here because this is
//   expected business validation, not a system failure).
// ============================================================================
public with sharing class VendorProductPreferenceService {

    public static void enforceSinglePreferred(
        List<Vendor_Product__c> newList,
        List<Vendor_Product__c> oldList
    ) {
        if (newList == null || newList.isEmpty()) return;

        // NOTE: isInsert is currently not used, but kept for clarity if we
        // later want different behavior on insert vs update.
        Boolean isInsert = (oldList == null);

        // In-scope preferred+active records grouped by Product__c
        Map<Id, List<Vendor_Product__c>> preferredByProduct = new Map<Id, List<Vendor_Product__c>>();
        Set<Id> productIdsWithPreferred = new Set<Id>();
        Set<Id> scopeIds = new Set<Id>(); // records in THIS DML operation

        for (Integer i = 0; i < newList.size(); i++) {
            Vendor_Product__c vp = newList[i];

            Boolean isPreferred = (vp.Is_Preferred__c == true);
            Boolean isActive    = (vp.Is_Active__c == true);

            // We only care about records that are both preferred AND active
            if (!isPreferred || !isActive) continue;
            if (vp.Product__c == null)     continue;

            productIdsWithPreferred.add(vp.Product__c);

            if (vp.Id != null) {
                scopeIds.add(vp.Id);
            }

            List<Vendor_Product__c> bucket = preferredByProduct.get(vp.Product__c);
            if (bucket == null) {
                bucket = new List<Vendor_Product__c>();
                preferredByProduct.put(vp.Product__c, bucket);
            }
            bucket.add(vp);
        }

        if (productIdsWithPreferred.isEmpty()) {
            // Nothing in this transaction is attempting to be active+preferred
            return;
        }

        // --------------------------------------------------------------------
        // 1) In-scope duplicates (multiple active preferred rows for same
        //    Product__c within the SAME DML operation).
        // --------------------------------------------------------------------
        for (List<Vendor_Product__c> bucket : preferredByProduct.values()) {
            if (bucket.size() > 1) {
                for (Vendor_Product__c vp : bucket) {
                    vp.Is_Preferred__c.addError(
                        'Only one preferred vendor product is allowed per product (within this operation).'
                    );
                }
            }
        }

        // --------------------------------------------------------------------
        // 2) Conflicts with existing ACTIVE preferred records in the database
        //    for the same Product__c.
        // --------------------------------------------------------------------
        List<Vendor_Product__c> existingPreferred = [
            SELECT Id, Product__c
            FROM Vendor_Product__c
            WHERE Product__c IN :productIdsWithPreferred
              AND Is_Preferred__c = true
              AND Is_Active__c = true
              AND Id NOT IN :scopeIds
        ];

        Set<Id> productsWithExistingPreferred = new Set<Id>();
        for (Vendor_Product__c existing : existingPreferred) {
            productsWithExistingPreferred.add(existing.Product__c);
        }

        for (Vendor_Product__c vp : newList) {
            Boolean isPreferred = (vp.Is_Preferred__c == true);
            Boolean isActive    = (vp.Is_Active__c == true);

            if (isPreferred &&
                isActive &&
                vp.Product__c != null &&
                productsWithExistingPreferred.contains(vp.Product__c)) {

                vp.Is_Preferred__c.addError(
                    'Only one preferred vendor product is allowed per product.'
                );
            }
        }
    }
}
