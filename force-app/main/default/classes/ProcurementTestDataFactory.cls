@IsTest
public class ProcurementTestDataFactory {

    public static Legal_Entity__c createLegalEntity() {
        Legal_Entity__c le = new Legal_Entity__c(
            Name = 'Test Legal Entity'
            // TODO: add any additional required fields if you have them
        );
        insert le;
        return le;
    }

    private static Integer buCounter = 0;
    private static Integer vendorCounter = 0;

    public static Business_Unit__c createBusinessUnit() {
        buCounter++;
        String codeSuffix = String.valueOf(buCounter);

        Legal_Entity__c le = createLegalEntity();

        Business_Unit__c bu = new Business_Unit__c(
            Name                      = 'Test BU ' + codeSuffix,
            Short_Code__c             = 'BU' + codeSuffix,                     // ✅ unique
            Customer_Service_Email__c = 'support+bu' + codeSuffix + '@example.com', // ✅ unique if email is constrained
            Customer_Service_Phone__c = '555-555-55' + codeSuffix,              // or keep static if not unique
            Legal_Entity__c           = le.Id
        );
        insert bu;
        return bu;
    }

    public static Account createVendorAccount() {
        vendorCounter++;
        String suffix = String.valueOf(vendorCounter);

        // Find the "Business" record type for Account (used by the lookup filter)
        Id businessRtId = null;
        try {
            businessRtId = [
                SELECT Id
                FROM RecordType
                WHERE SObjectType = 'Account'
                  AND Name = 'Business'
                LIMIT 1
            ].Id;
        } catch (Exception e) {
            // If for some reason it doesn't exist in this org, we just don't set it.
            // But your lookup filter implies it *does* exist, or it wouldn't save.
        }

        Account vendor = new Account(
            Name        = 'Test Vendor ' + suffix,
            Is_Vendor__c = true        // ✅ matches Account.Is_Vendor__c = TRUE
        );

        if (businessRtId != null) {
            vendor.RecordTypeId = businessRtId;   // ✅ matches RecordType.Name = 'Business'
        }

        insert vendor;
        return vendor;
    }

    public static Product2 createProduct() {
        Product2 p = new Product2(
            Name      = 'Test Product',
            ProductCode = 'TP-001',
            IsActive  = true
        );
        insert p;
        return p;
    }

    public static Product_UOM__c createDefaultProductUom(Product2 p) {
        Product_UOM__c u = new Product_UOM__c(
            Product__c          = p.Id,
            Unit_of_Measure__c  = 'each',
            Conversion_to_Base__c = 1,
            Is_Active__c        = true,
            Is_Default__c       = true
        );
        insert u;
        return u;
    }

    public static Vendor_Product__c createVendorProduct(
        Account vendor,
        Product2 product,
        Boolean isPreferred
    ) {
        Vendor_Product__c vp = new Vendor_Product__c(
            Vendor__c                    = vendor.Id,
            Product__c                   = product.Id,
            Vendor_SKU__c                = 'SKU-' + String.valueOf(Crypto.getRandomInteger()),
            Vendor_UOM__c                = 'each',
            Conversion_Factor__c         = 1,    // satisfies validation: > 0
            Base_Cost_Per_Vendor_Unit__c = 10,
            Min_Order_Quantity__c        = 1,
            Is_Active__c                 = true,
            Is_Preferred__c              = isPreferred
        );
        insert vp;
        return vp;
    }

    public static Product_Availability__c createProductAvailability(
        Business_Unit__c bu,
        Product2 product,
        Boolean allowPurchase,
        Boolean autoCreateSourcing
    ) {
        Product_Availability__c pa = new Product_Availability__c(
            Business_Unit__c               = bu.Id,
            Product__c                     = product.Id,
            Is_Active__c                   = true,
            Allow_Purchase__c              = allowPurchase,
            Allow_Sell__c                  = false,
            Auto_Create_Sourcing_Options__c = autoCreateSourcing
        );
        insert pa;
        return pa;
    }

    public static Product_Sourcing_Option__c createProductSourcingOption(
        Business_Unit__c bu,
        Product2 product,
        Account vendor,
        Vendor_Product__c vp,
        Boolean isDefault
    ) {
        Product_Sourcing_Option__c pso = new Product_Sourcing_Option__c(
            Business_Unit__c                = bu.Id,
            Product__c                      = product.Id,
            Vendor__c                       = vendor.Id,
            Vendor_Product__c               = vp.Id,
            Min_Order_Quantity__c           = vp.Min_Order_Quantity__c,
            Contract_Cost_Per_Vendor_Unit__c = null,
            Is_Active__c                    = true,
            Is_Default__c                   = isDefault
        );
        insert pso;
        return pso;
    }

    public static Purchase_Order__c createPurchaseOrder(
        Business_Unit__c bu,
        Account vendor
    ) {
        Purchase_Order__c po = new Purchase_Order__c(
            Business_Unit__c     = bu.Id,
            Status__c            = 'Draft',
            Order_Date__c        = Date.today(),
            Expected_Delivery_Date__c = Date.today().addDays(7),
            Ship_To_Location__c  = null, // fill if required
            Terms__c             = 'Net 30',
            Vendor_Reference__c  = 'REF-123'
        );
        insert po;
        return po;
    }

    public static Purchase_Order_Line__c createPurchaseOrderLine(
        Purchase_Order__c po,
        Product_Sourcing_Option__c pso,
        Decimal vendorQty,
        Decimal costPerVendorUnit
    ) {
        Purchase_Order_Line__c line = new Purchase_Order_Line__c(
            Purchase_Order__c           = po.Id,
            Product_Sourcing_Option__c  = pso.Id,
            Vendor_Quantity__c          = vendorQty,
            Cost_Per_Vendor_Unit__c     = costPerVendorUnit
            // Other fields will be defaulted/calculated by triggers/services
        );
        insert line;
        return line;
    }
}
