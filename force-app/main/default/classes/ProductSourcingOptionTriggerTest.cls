@IsTest
private class ProductSourcingOptionTriggerTest {

    @IsTest
    static void defaults_populateFromVendorProduct_onInsert() {
        Business_Unit__c bu = ProcurementTestDataFactory.createBusinessUnit();
        Account vendor      = ProcurementTestDataFactory.createVendorAccount();
        Product2 product    = ProcurementTestDataFactory.createProduct();

        Vendor_Product__c vp = ProcurementTestDataFactory.createVendorProduct(
            vendor, product, false
        );

        // Intentionally omit Vendor__c and Product__c to let defaults fill them
        Product_Sourcing_Option__c pso = new Product_Sourcing_Option__c(
            Business_Unit__c       = bu.Id,
            Vendor_Product__c      = vp.Id,
            Is_Active__c           = true
        );

        Test.startTest();
        insert pso;
        Test.stopTest();

        pso = [
            SELECT Id, Business_Unit__c, Product__c, Vendor__c, Min_Order_Quantity__c
            FROM Product_Sourcing_Option__c
            WHERE Id = :pso.Id
        ];

        System.assertEquals(product.Id, pso.Product__c, 'Product should default from Vendor_Product__c');
        System.assertEquals(vendor.Id,  pso.Vendor__c,  'Vendor should default from Vendor_Product__c');
        System.assertEquals(vp.Min_Order_Quantity__c, pso.Min_Order_Quantity__c, 'Min order should default from Vendor_Product__c');
    }

    @IsTest
    static void validation_preventsExistingDuplicateBuVendorProduct() {
        Business_Unit__c bu = ProcurementTestDataFactory.createBusinessUnit();
        Account vendor      = ProcurementTestDataFactory.createVendorAccount();
        Product2 product    = ProcurementTestDataFactory.createProduct();
        Vendor_Product__c vp = ProcurementTestDataFactory.createVendorProduct(
            vendor, product, false
        );

        Product_Sourcing_Option__c pso1 = ProcurementTestDataFactory.createProductSourcingOption(
            bu, product, vendor, vp, false
        );

        Product_Sourcing_Option__c pso2 = new Product_Sourcing_Option__c(
            Business_Unit__c  = bu.Id,
            Product__c        = product.Id,
            Vendor__c         = vendor.Id,
            Vendor_Product__c = vp.Id,
            Is_Active__c      = true
        );

        Test.startTest();
        try {
            insert pso2;
            System.assert(false, 'Expected duplicate BU+Vendor_Product validation error.');
        } catch (DmlException e) {
            System.assert(
                e.getDmlMessage(0).contains('Product Sourcing Option already exists') ||
                e.getDmlMessage(0).contains('Duplicate Product Sourcing Option for this Business Unit and Vendor Product'),
                'Unexpected error message: ' + e.getDmlMessage(0)
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void validation_preventsMultipleDefaultsPerBuProduct() {
        Business_Unit__c bu = ProcurementTestDataFactory.createBusinessUnit();
        Account vendor1     = ProcurementTestDataFactory.createVendorAccount();
        Account vendor2     = ProcurementTestDataFactory.createVendorAccount();
        Product2 product    = ProcurementTestDataFactory.createProduct();

        Vendor_Product__c vp1 = ProcurementTestDataFactory.createVendorProduct(
            vendor1, product, false
        );
        Vendor_Product__c vp2 = ProcurementTestDataFactory.createVendorProduct(
            vendor2, product, false
        );

        Product_Sourcing_Option__c pso1 = ProcurementTestDataFactory.createProductSourcingOption(
            bu, product, vendor1, vp1, true
        );

        Product_Sourcing_Option__c pso2 = new Product_Sourcing_Option__c(
            Business_Unit__c  = bu.Id,
            Product__c        = product.Id,
            Vendor__c         = vendor2.Id,
            Vendor_Product__c = vp2.Id,
            Is_Active__c      = true,
            Is_Default__c     = true
        );

        Test.startTest();
        try {
            insert pso2;
            System.assert(false, 'Expected validation preventing multiple defaults per BU+Product.');
        } catch (DmlException e) {
            System.assert(
                e.getDmlMessage(0).contains('Only one default Product Sourcing Option') ||
                e.getDmlMessage(0).contains('default Product Sourcing Option is allowed per Business Unit and Product'),
                'Unexpected error message: ' + e.getDmlMessage(0)
            );
        }
        Test.stopTest();
    }
}
