@IsTest
private class VendorProductTriggerTest {

    @IsTest
    static void testSinglePreferredVendorProduct_disallowsSecondPreferred() {
        Business_Unit__c bu = ProcurementTestDataFactory.createBusinessUnit();
        Account vendor      = ProcurementTestDataFactory.createVendorAccount();
        Product2 product    = ProcurementTestDataFactory.createProduct();

        // First preferred vendor product (ok)
        Vendor_Product__c vp1 = ProcurementTestDataFactory.createVendorProduct(
            vendor, product, true
        );

        // Second preferred vendor product for same product should fail
        Vendor_Product__c vp2 = new Vendor_Product__c(
            Vendor__c                    = vendor.Id,
            Product__c                   = product.Id,
            Vendor_SKU__c                = 'SKU-SECOND',
            Vendor_UOM__c                = 'each',
            Conversion_Factor__c         = 1,
            Base_Cost_Per_Vendor_Unit__c = 15,
            Min_Order_Quantity__c        = 1,
            Is_Active__c                 = true,
            Is_Preferred__c              = true
        );

        Test.startTest();
        try {
            insert vp2;
            System.assert(false, 'Expected DmlException for duplicate preferred vendor product.');
        } catch (DmlException e) {
            System.assert(
                e.getDmlMessage(0).contains('Only one preferred vendor product is allowed per product'),
                'Unexpected error: ' + e.getDmlMessage(0)
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void testAutoCreateSourcingOptions_onVendorProductInsert() {
        Business_Unit__c bu = ProcurementTestDataFactory.createBusinessUnit();
        Account vendor      = ProcurementTestDataFactory.createVendorAccount();
        Product2 product    = ProcurementTestDataFactory.createProduct();

        // Product availability eligible for auto-sourcing
        Product_Availability__c pa = ProcurementTestDataFactory.createProductAvailability(
            bu, product, true, true
        );

        // Insert vendor product – should auto-create Product_Sourcing_Option__c
        Test.startTest();
        Vendor_Product__c vp = ProcurementTestDataFactory.createVendorProduct(
            vendor, product, false
        );
        Test.stopTest();

        List<Product_Sourcing_Option__c> psoList = [
            SELECT Id, Business_Unit__c, Product__c, Vendor__c, Vendor_Product__c
            FROM Product_Sourcing_Option__c
            WHERE Business_Unit__c = :bu.Id
              AND Product__c       = :product.Id
              AND Vendor__c        = :vendor.Id
              AND Vendor_Product__c = :vp.Id
        ];

        System.assertEquals(1, psoList.size(), 'Expected one Product Sourcing Option auto-created.');
    }
}
