@IsTest
private class ProductAvailabilityAutoSourcingTest {

    @IsTest
    static void testAutoCreateOnInsert() {
        Business_Unit__c bu = ProcurementTestDataFactory.createBusinessUnit();
        Account vendor      = ProcurementTestDataFactory.createVendorAccount();
        Product2 product    = ProcurementTestDataFactory.createProduct();

        Vendor_Product__c vp = ProcurementTestDataFactory.createVendorProduct(
            vendor, product, false
        );

        Test.startTest();
        Product_Availability__c pa = ProcurementTestDataFactory.createProductAvailability(
            bu, product, true, true
        );
        Test.stopTest();

        List<Product_Sourcing_Option__c> options = [
            SELECT Id, Business_Unit__c, Product__c, Vendor__c, Vendor_Product__c
            FROM Product_Sourcing_Option__c
            WHERE Business_Unit__c  = :bu.Id
              AND Product__c        = :product.Id
              AND Vendor_Product__c = :vp.Id
        ];

        System.assertEquals(1, options.size(), 'Expected a sourcing option for BU+Product+VendorProduct.');
    }

    @IsTest
    static void testAutoCreateOnUpdateTransitionToEligible() {
        Business_Unit__c bu = ProcurementTestDataFactory.createBusinessUnit();
        Account vendor      = ProcurementTestDataFactory.createVendorAccount();
        Product2 product    = ProcurementTestDataFactory.createProduct();

        Vendor_Product__c vp = ProcurementTestDataFactory.createVendorProduct(
            vendor, product, false
        );

        // Initially not eligible (no auto-create / no allow purchase)
        Product_Availability__c pa = new Product_Availability__c(
            Business_Unit__c               = bu.Id,
            Product__c                     = product.Id,
            Is_Active__c                   = true,
            Allow_Purchase__c              = false,
            Auto_Create_Sourcing_Options__c = false
        );
        insert pa;

        Test.startTest();
        pa.Allow_Purchase__c              = true;
        pa.Auto_Create_Sourcing_Options__c = true;
        update pa;
        Test.stopTest();

        List<Product_Sourcing_Option__c> options = [
            SELECT Id
            FROM Product_Sourcing_Option__c
            WHERE Business_Unit__c  = :bu.Id
              AND Product__c        = :product.Id
              AND Vendor_Product__c = :vp.Id
        ];

        System.assertEquals(1, options.size(), 'Expected sourcing option created on transition to eligible.');
    }

    @IsTest
    static void testDoesNotCreateDuplicatesForSameBUAndVendorProduct() {
        Business_Unit__c bu = ProcurementTestDataFactory.createBusinessUnit();
        Account vendor      = ProcurementTestDataFactory.createVendorAccount();
        Product2 product    = ProcurementTestDataFactory.createProduct();

        Vendor_Product__c vp = ProcurementTestDataFactory.createVendorProduct(
            vendor, product, false
        );

        // Existing sourcing option
        Product_Sourcing_Option__c existing = ProcurementTestDataFactory.createProductSourcingOption(
            bu, product, vendor, vp, false
        );

        // Make availability eligible – should NOT create a duplicate PSO
        Product_Availability__c pa = new Product_Availability__c(
            Business_Unit__c               = bu.Id,
            Product__c                     = product.Id,
            Is_Active__c                   = true,
            Allow_Purchase__c              = false,
            Auto_Create_Sourcing_Options__c = false
        );
        insert pa;

        Test.startTest();
        pa.Allow_Purchase__c               = true;
        pa.Auto_Create_Sourcing_Options__c = true;
        update pa;
        Test.stopTest();

        List<Product_Sourcing_Option__c> options = [
            SELECT Id
            FROM Product_Sourcing_Option__c
            WHERE Business_Unit__c  = :bu.Id
              AND Product__c        = :product.Id
              AND Vendor_Product__c = :vp.Id
        ];

        System.assertEquals(1, options.size(), 'Should not create duplicate PSO for same BU + Vendor_Product.');
    }
}
