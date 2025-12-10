@IsTest
private class PurchaseOrderLineTriggerTest {

    @IsTest
    static void testDefaultsAndCalculationsFromSourcingOption() {
        Business_Unit__c bu = ProcurementTestDataFactory.createBusinessUnit();
        Account vendor      = ProcurementTestDataFactory.createVendorAccount();
        Product2 product    = ProcurementTestDataFactory.createProduct();
        ProcurementTestDataFactory.createDefaultProductUom(product);

        Vendor_Product__c vp = ProcurementTestDataFactory.createVendorProduct(
            vendor, product, false
        );

        Product_Sourcing_Option__c pso = ProcurementTestDataFactory.createProductSourcingOption(
            bu, product, vendor, vp, false
        );

        Purchase_Order__c po = ProcurementTestDataFactory.createPurchaseOrder(bu, vendor);

        Test.startTest();
        Purchase_Order_Line__c line = new Purchase_Order_Line__c(
            Purchase_Order__c          = po.Id,
            Product_Sourcing_Option__c = pso.Id,
            Vendor_Quantity__c         = 10
            // Cost_Per_Vendor_Unit__c left null to be defaulted
        );
        insert line;
        Test.stopTest();

        line = [
            SELECT Id,
                   Product__c,
                   Vendor__c,
                   Vendor_Product__c,
                   Vendor_Quantity__c,
                   Vendor_UOM__c,
                   Conversion_Factor__c,
                   Internal_UOM__c,
                   Internal_Quantity__c,
                   Converted_Internal_Quantity__c,
                   Cost_Per_Vendor_Unit__c
            FROM Purchase_Order_Line__c
            WHERE Id = :line.Id
        ];

        System.assertEquals(product.Id, line.Product__c, 'Product should default from PSO / Vendor_Product.');
        System.assertEquals(vendor.Id,  line.Vendor__c,  'Vendor should default from PSO / Vendor_Product.');
        System.assertEquals(vp.Id,      line.Vendor_Product__c, 'Vendor_Product__c should default from PSO.');
        System.assertEquals('each',       line.Vendor_UOM__c, 'Vendor UOM should default from Vendor_Product.');
        System.assertEquals(1,          line.Conversion_Factor__c, 'Conversion factor should default from Vendor_Product.');
        System.assertEquals('each',       line.Internal_UOM__c, 'Internal UOM should default from Product_UOM.');

        System.assertEquals(10, line.Vendor_Quantity__c, 'Vendor qty should match input.');
        System.assertEquals(10, line.Converted_Internal_Quantity__c, 'Converted internal qty should be vendorQty * conversionFactor.');
        System.assertEquals(10, line.Internal_Quantity__c, 'Internal qty should default to converted internal qty.');

        System.assertEquals(
            vp.Base_Cost_Per_Vendor_Unit__c,
            line.Cost_Per_Vendor_Unit__c,
            'Cost per vendor unit should default from Vendor_Product when no contract cost in range.'
        );
    }

    @IsTest
    static void testBaseCostUsedWhenContractOutOfRange() {
        Business_Unit__c bu = ProcurementTestDataFactory.createBusinessUnit();
        Account vendor      = ProcurementTestDataFactory.createVendorAccount();
        Product2 product    = ProcurementTestDataFactory.createProduct();
        ProcurementTestDataFactory.createDefaultProductUom(product);

        Vendor_Product__c vp = ProcurementTestDataFactory.createVendorProduct(
            vendor, product, false
        );

        // Contract cost that is out of effective range (in the past)
        Product_Sourcing_Option__c pso = new Product_Sourcing_Option__c(
            Business_Unit__c                = bu.Id,
            Product__c                      = product.Id,
            Vendor__c                       = vendor.Id,
            Vendor_Product__c               = vp.Id,
            Contract_Cost_Per_Vendor_Unit__c = 5,
            Effective_From__c               = Date.today().addYears(-2),
            Effective_To__c                 = Date.today().addYears(-1),
            Is_Active__c                    = true
        );
        insert pso;

        Purchase_Order__c po = ProcurementTestDataFactory.createPurchaseOrder(bu, vendor);

        Test.startTest();
        Purchase_Order_Line__c line = new Purchase_Order_Line__c(
            Purchase_Order__c          = po.Id,
            Product_Sourcing_Option__c = pso.Id,
            Vendor_Quantity__c         = 3
        );
        insert line;
        Test.stopTest();

        line = [
            SELECT Cost_Per_Vendor_Unit__c
            FROM Purchase_Order_Line__c
            WHERE Id = :line.Id
        ];

        System.assertEquals(
            vp.Base_Cost_Per_Vendor_Unit__c,
            line.Cost_Per_Vendor_Unit__c,
            'When contract cost is out of range, base cost from Vendor_Product should be used.'
        );
    }

    @IsTest
    static void testRollupsAndStatusFromLines() {
        Business_Unit__c bu = ProcurementTestDataFactory.createBusinessUnit();
        Account vendor      = ProcurementTestDataFactory.createVendorAccount();
        Product2 product    = ProcurementTestDataFactory.createProduct();
        ProcurementTestDataFactory.createDefaultProductUom(product);

        Vendor_Product__c vp = ProcurementTestDataFactory.createVendorProduct(
            vendor, product, false
        );

        Product_Sourcing_Option__c pso = ProcurementTestDataFactory.createProductSourcingOption(
            bu, product, vendor, vp, false
        );

        Purchase_Order__c po = ProcurementTestDataFactory.createPurchaseOrder(bu, vendor);

        // Line 1: ordered, not received
        Purchase_Order_Line__c line1 = new Purchase_Order_Line__c(
            Purchase_Order__c          = po.Id,
            Product_Sourcing_Option__c = pso.Id,
            Vendor_Quantity__c         = 2,
            Cost_Per_Vendor_Unit__c    = 10,
            Status__c                  = 'Ordered'
        );

        // Line 2: fully received
        Purchase_Order_Line__c line2 = new Purchase_Order_Line__c(
            Purchase_Order__c          = po.Id,
            Product_Sourcing_Option__c = pso.Id,
            Vendor_Quantity__c         = 3,
            Cost_Per_Vendor_Unit__c    = 10,
            Status__c                  = 'Received',
            Received_Quantity_Internal__c = 3
        );

        Test.startTest();
        insert new List<Purchase_Order_Line__c>{ line1, line2 };
        Test.stopTest();

        po = [
            SELECT Id,
                   Subtotal__c,
                   Total_Internal_Quantity__c,
                   Received_Internal_Quantity__c,
                   Status__c
            FROM Purchase_Order__c
            WHERE Id = :po.Id
        ];

        System.assertEquals(50, po.Subtotal__c, 'Subtotal should be sum of line totals (2*10 + 3*10).');
        System.assertEquals(5,  po.Total_Internal_Quantity__c, 'Total internal qty should sum internal quantities (assuming factor 1).');
        System.assertEquals(3,  po.Received_Internal_Quantity__c, 'Received internal qty should sum received quantities.');

        System.assertEquals('Partially_Received', po.Status__c, 'Mixed ordered and received should yield Partially_Received.');
    }

    @IsTest
    static void testPurchaseOrderValidation_preventsBuChangeAndDeleteWithLines() {
        Business_Unit__c bu1 = ProcurementTestDataFactory.createBusinessUnit();
        Business_Unit__c bu2 = ProcurementTestDataFactory.createBusinessUnit();
        Account vendor       = ProcurementTestDataFactory.createVendorAccount();
        Product2 product     = ProcurementTestDataFactory.createProduct();
        ProcurementTestDataFactory.createDefaultProductUom(product);

        Vendor_Product__c vp = ProcurementTestDataFactory.createVendorProduct(
            vendor, product, false
        );

        Product_Sourcing_Option__c pso = ProcurementTestDataFactory.createProductSourcingOption(
            bu1, product, vendor, vp, false
        );

        Purchase_Order__c po = ProcurementTestDataFactory.createPurchaseOrder(bu1, vendor);

        Purchase_Order_Line__c line = new Purchase_Order_Line__c(
            Purchase_Order__c          = po.Id,
            Product_Sourcing_Option__c = pso.Id,
            Vendor_Quantity__c         = 1,
            Cost_Per_Vendor_Unit__c    = 10,
            Status__c                  = 'Ordered'
        );
        insert line;

        Test.startTest();

        // --- Try changing BU – should fail ---
        po.Business_Unit__c = bu2.Id;
        try {
            update po;
            System.assert(false, 'Expected error when changing BU on PO with lines.');
        } catch (DmlException e) {
            System.assert(
                e.getDmlMessage(0).contains('Cannot change Business Unit on a Purchase Order that has line items'),
                'Unexpected error when changing BU: ' + e.getDmlMessage(0)
            );
        }

        // Reload PO to ensure it still exists and BU is unchanged before delete test
        po = [
            SELECT Id, Business_Unit__c
            FROM Purchase_Order__c
            WHERE Id = :po.Id
        ];

        // --- Try deleting PO – should fail ---
        try {
            delete po;
            System.assert(false, 'Expected error when deleting PO with lines.');
        } catch (DmlException e) {
            System.assert(
                e.getDmlMessage(0).contains('Cannot delete a Purchase Order that has line items'),
                'Unexpected error when deleting PO: ' + e.getDmlMessage(0)
            );
        }

        Test.stopTest();
    }

}
