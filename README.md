# Caliber Commerce

Caliber Commerce is the financial and transactional foundation of the Caliber Platform.
It provides a unified model for Proposals, Contracts, Invoices, Payments, Deposits, and now Procurement & Purchase Orders—enabling accurate billing, cost tracking, purchasing, and seamless integration with both customer-facing and internal processes.

## Overview

This package defines the full commercial lifecycle from Proposal → Contract → Invoice, with a fully auditable Transaction Register that ensures financial accuracy and traceability.
It introduces standardized billing objects, posting logic, payment application tools, and a vendor-aware procurement layer that can be extended into accounting, subscriptions, and integrations such as Stripe or QuickBooks.

Caliber Commerce serves as the universal transaction engine across all Caliber Platform modules—supporting both project-based, service-based, and product-based business workflows.

### Core Features

- Proposals (Estimates / Quotes / Change Orders) – Unified pricing documents supporting dynamic numbering and multi-route fulfillment (Project, Work Order, Order, or Service Contract).

- Contracts & Amendments – Legal agreements assembled from modular text sections. Contract Amendments manage Change Orders and Addenda, directly linked to Change-type Proposals.

- Invoices – Flexible, Stripe-compatible invoicing system with exact rounding logic, deposits, progress billing, and balance tracking.

- Deposits – Dedicated prepayment object that represents customer deposits as liabilities and automatically applies them to future invoices.

- Transaction Register – A central ledger that records invoices, payments, credits, and refunds, maintaining audit-grade financial accuracy.

- Payments & Refunds – Supports partial payments, on-account credits, refunds, and reconciliation with Stripe or custom processors.

- Recurring Billing – Subscriptions automate invoice generation based on defined cycles or usage.

- Declarative Deposit Policies – Configurable rules that determine deposit percentages and thresholds per business unit.

- Cross-Package Integrations – Seamless linkage to Projects, Work Orders, Orders, and Service Contracts for complete fulfillment workflows.

- Brand-Ready Document Templates – Consistent merge layouts for Estimates, Contracts, Amendments, and Invoices across all brands.

## Procurement, Vendor Management & Purchase Orders

Caliber Commerce also provides a procurement and sourcing layer that manages how internal teams purchase products from vendors, how those products are represented, and how costs flow into the rest of the platform.

### This subsystem introduces:

- Multi-vendor sourcing per product

- Vendor-specific units of measure and conversion factors

- Business-unit-specific availability rules

- Contract and base cost handling

- Automated creation of sourcing options

- Purchase Orders with cost and quantity rollups

- Procurement Data Model

### The procurement model centers around four primary objects:

- ```Product_Availability__c``` – Controls which Business Units can sell and/or purchase a Product2 and under what conditions.

- ```Vendor_Product__c``` – Represents how a specific vendor sells a product (SKU, cost, units, conversion).

- ```Product_Sourcing_Option__c``` – Defines which vendor a specific Business Unit can buy a product from, along with contract terms.

- ```Purchase_Order__c``` / ```Purchase_Order_Line__c``` – Represents the purchase transaction and line-level quantities, units, and costs.

## Product_Availability__c

Defines Business Unit–level rules for products, including whether they can be sold or purchased and whether sourcing options should be auto-created.

### Key fields include:

- ```Business_Unit__c```

- ```Product__c```

- ```Is_Active__c```

- ```Allow_Sell__c```

- ```Allow_Purchase__c```

- ```Default_Pricebook__c```

- ```Auto_Create_Sourcing_Options__c```

## Vendor_Product__c

Represents a vendor-specific catalog entry for a given Product2, including units and base cost.

### Key fields include:

- ```Vendor__c``` (Account with vendor filter applied)

- ```Product__c```

- ```Vendor_SKU__c```

- ```Vendor_Units__c``` (using a global UOM value set)

- ```Conversion_Factor__c``` (vendor units → internal units)

- ```Base_Cost_Per_Vendor_Unit__c```

- ```Min_Order_Quantity__c```

- ```Lead_Time_Days__c```

- ```Is_Active__c```

- ```Is_Preferred__c``` (enforced so only one preferred vendor product exists per product at a time)

## Product_Sourcing_Option__c

Represents how a specific Business Unit sources a Product from a specific Vendor. This is the “purchasing policy” object for a BU + Product + Vendor combination.

### Key fields include:

- ```Business_Unit__c```

- ```Product__c```

- ```Vendor__c```

- ```Vendor_Product__c```

- ```Min_Order_Quantity__c```

- ```Is_Active__c```

- ```Is_Default__c``` (enforced to be unique per Business Unit + Product)

- ```Contract_Cost_Per_Vendor_Unit__c```

- ```Contract_Discount_Percent__c```

- ```Effective_From__c / Effective_To__c```

Product Sourcing Options normalize vendor data into something consumable by users, Purchase Orders, and future replenishment logic.

## Purchase_Order__c

Represents a purchase placed with a vendor on behalf of a Business Unit. Includes status tracking and rollups for financial values.

### Key fields include:

- ```Business_Unit__c```

- ```Order_Date__c```

- ```Expected_Delivery_Date__c```

- ```Ship_To_Location__c```

- ```Status__c``` (Draft, Ordered, Partially Received, Received, Closed, etc.)

- ```Vendor_Reference__c```

- ```Terms__c```

- ```Subtotal__c```

- ```Shipping_Amount__c```

- ```Other_Charges__c```

- ```Tax_Amount__c```

- ```Tax_Deferred__c```

- ```Tax_Liability__c```

- ```Total_Amount__c``` (formula combining the above)

## Purchase_Order_Line__c

Represents individual material lines on a Purchase Order, linked to sourcing options, vendor products, and products.

### Key fields include:

- ```Purchase_Order__c```

- ```Product_Sourcing_Option__c```

- ```Vendor_Product__c```

- ```Product__c```

- ```Vendor__c```

- ```Product_Item__c``` (integration object in another package, if used)

- ```Vendor_Quantity__c```

- ```Vendor_UOM__c```

- ```Conversion_Factor__c```

- ```Converted_Internal_Quantity__c```

- ```Internal_Quantity__c```

- ```Internal_UOM__c```

- ```Cost_Per_Vendor_Unit__c```

- ```Received_Quantity_Internal__c```

- ```Status__c``` (line status)

- ```Line_Total__c``` (formula: Vendor_Quantity__c * Cost_Per_Vendor_Unit__c)

## Procurement Automation

The package includes trigger-driven services (in Caliber Core / Commerce) that implement the following behaviors:

- Single preferred vendor – When a Vendor_Product__c is marked as preferred, any other preferred vendor products for the same Product are automatically un-marked (or blocked depending on enforcement configuration).

- Auto-create sourcing options from Vendor_Product__c – When a Vendor Product is created, sourcing options are automatically created for any Business Units where Product_Availability__c allows purchasing and Auto_Create_Sourcing_Options__c = TRUE.

- Auto-create sourcing options from Product_Availability__c – When a Product Availability record transitions into an eligible state (Allow_Purchase__c = TRUE and Auto_Create_Sourcing_Options__c = TRUE), sourcing options are created for all active Vendor Products for that Product/BU combination (without duplicating existing ones).

- Defaulting logic for Product_Sourcing_Option__c – When a PSO is created with a Vendor_Product__c, Product and Vendor fields default from the Vendor Product, and minimum order quantity can be inherited as well.

- Validation for sourcing options – Prevents duplicates for the same Business Unit + Vendor Product and enforces that only one default option exists per Business Unit + Product.

- Purchase Order line defaults – When a Purchase Order Line references a Product Sourcing Option, relevant fields (Product, Vendor, Vendor Product, UOM, Conversion Factor, default cost) are populated from upstream objects.

- Cost selection logic – Purchase Order Line cost uses contract pricing (Contract_Cost_Per_Vendor_Unit__c) when the PO date falls in the effective date range; otherwise, it falls back to Base_Cost_Per_Vendor_Unit__c on the Vendor Product.

- Rollups and status – Purchase Order header values (Subtotal, internal totals, received totals, derived status) are recalculated whenever lines change.

- Validation rules on Purchase Orders – Prevent changing the Business Unit or deleting a Purchase Order that has line items.

## Package Dependencies

### Required:

- Caliber Core – shared utilities, error handling, and metadata framework.

### Optional extensions:

- Caliber Project Management – enables project billing, progress invoices, and phase-based fulfillment.

- Caliber Restoration – integrates restoration workflows with the Commerce data model.

- Caliber MagicPlan Integration – creates Proposals directly from field capture data.

- Salesforce Field Service – integrates with Maintenance Plans, Service Contracts, and inventory/receiving via Product_Item__c in the integration package.

## Installation & Setup

Install dependencies in order:

- Caliber Core

- Caliber Commerce

- Assign permission sets:

- Caliber Commerce Admin

- Caliber Commerce User

- Caliber Commerce Read Only

- Add Caliber Commerce Lightning App to App Launcher.

- Configure Numbering Rules (Custom Metadata) for Proposal and Invoice prefixes.

- Configure Invoice Deposit Policies to automate deposit and invoice generation.

### Configure Procurement Settings:

- Global Units of Measure (Global Value Set)

- Product Availability records per Business Unit

- Vendor flags and Account record types to satisfy Vendor lookup filters

### Enable optional Flows:

- Proposal Acceptance and Fulfillment Creation

- Invoice Posting & Payment Application

- Deposit Generation & Application

- Subscription Invoice Generation

- Purchase Order creation from demand (optional future flows)

## Data Model

Caliber Commerce introduces a normalized, auditable financial data model that supports quoting, contracting, invoicing, payments, and procurement.

## Legal & Contract Objects

```Contract__c```	Primary agreement record with category and business unit tracking.

```Contract_Amendment__c```	Child record for modifying an existing Contract, including Change Orders and Addenda. Linked to the associated Change-type Proposal.

## Proposal & Quoting Objects

```Proposal__c``` Unified document for Estimates, Quotes, and Change Orders. Determines fulfillment route and billing model.

```Proposal_Line__c``` Defines individual pricing lines, quantities, and scope. Includes fulfillment and source tracking for auditability.

```Invoice_Deposit_Policy__c``` Configurable business rules defining required deposits, thresholds, and invoice creation behavior.

```Deposit__c``` Represents a customer prepayment held as a liability until applied to invoices.

```Project_Billing_Line__c``` Created when a Proposal’s fulfillment route = Project. Tied to Project Phases for progress billing.

### Key Fields on Proposal

- ```Proposal_Type__c``` – Estimate, Quote, Change

- ```Fulfillment_Route__c``` – Project, Work Order, Order, Service Contract

- ```Billing_Model__c``` – Standard, Progress, Recurring, Usage-Based

- ```Deposit_Policy__c``` – lookup to applicable deposit policy

- ```Original_Proposal__c``` – links a Change Proposal to the original

- ```Amendment__c``` – link to Contract Amendment when applicable

### Key Fields on Proposal Line

- ```Fulfillment_Target__c``` – Project Phase, Work Order, Order, Service Contract

- ```Source_Proposal_Line__c``` – links to the original line being changed

- ```Discount_Type__c```, ```Discount_Value__c```, ```Discount_Amount__c``` – standard discount structure

- ```Taxable__c```, ```Unit_Net__c```, ```Total_Price__c``` – standardized pricing logic

## Invoicing & Billing

```Invoice__c``` Core billing record representing earned revenue; supports taxes, deposits, discounts, and retainage.

```Invoice_Line__c``` Detailed line items copied from Proposal or Project Billing Lines.

```Project_Billing_Line__c``` Supports project-based billing; invoices generated automatically when phases are completed.

### Invoice Highlights

- ```Invoice_Type__c``` – Standard, Progress, Final, Retainage

- ```Status__c``` – Draft, Posted, Paid, Voided

- ```Balance__c``` – uses negative-accounting convention for liability accuracy.

- ```Posting_Status__c``` – sync flag for Transaction Register entries.

## Payments, Deposits & Refunds

```Deposit__c``` Prepayment record linked to a Proposal or Contract; applied to invoices when work begins.

```Payment__c``` Records a customer’s remittance (Stripe, ACH, etc.).

```Payment_Session__c``` Represents a Stripe Checkout or PaymentIntent session.

```Payment_Application__c``` Connects a payment (or deposit) to one or more invoices.

```Refund__c``` Outbound transaction reversing payment or deposit; reconciles to the original record.

## Credits & Adjustments

```Credit_Memo__c``` Issued credit used to offset invoice balances.

```Credit_Memo_Line__c``` Line-level details of credited items.

```Credit_Memo_Application__c``` Tracks credit applications against invoices or accounts.

## Financial Ledger

```Transaction_Register__c``` Master ledger that records every posting event (invoice, payment, refund, credit). Forms the backbone of audit and reconciliation.

## Recurring Billing

```Subscription__c```	Automates recurring invoices for contracts or service plans. Integrates with deposit logic and Transaction Register for recurring entries.

- Fulfillment Routes

- Route	Fulfillment Object	Billing Trigger	Description

- Project	Project / Project Phases	Phase Completed	Generates invoices for all Project Billing Lines linked to completed phases.

- Work Order	Work Order + Work Order Lines	Work Order Closed	Used for single-service jobs; invoices automatically upon closure.

- Order	Order + Order Items	Order Fulfilled	Used for product sales; invoices upon fulfillment.

- Service Contract	Service Contract / Maintenance Plan	Work Order Generated & Closed	Enables maintenance agreements and recurring service schedules.

## Change Orders & Amendments

Change Orders are implemented using Proposal (Type = Change) records linked to a Contract Amendment.

```Proposal_Type__c``` = Change represents the pricing deltas.

```Contract_Amendment__c.Amendment_Type__c``` = Change Order provides the legal wrapper.

```Original_Proposal__c``` on the Change Proposal links back to the base.

```Source_Proposal_Line__c``` on each line connects to its original for delta math.

- Totals roll up to the Contract Amendment for doc generation.

## Customer Deposit Workflow

- Proposal Accepted → Policy lookup (Invoice_Deposit_Policy__c) determines required deposit.

- Deposit__c Created → Deposit amount and terms recorded.

- Customer Pays → Payment captured via Stripe or other method.

- Deposit Posted → Liability entered in Transaction Register.

- Invoice Posted → Deposit applied through Payment Application.

- Deposit Closed → Remaining balance cleared or refunded.

## Roadmap

- Account-level running balance and credit rollups.

- General Ledger export extension (Accounting package).

- Multi-currency and jurisdictional tax support.

- Customer portal for invoice payment and document access.

- Advanced Stripe, QuickBooks, and ACH integration options.

- Additional procurement features: demand-based PO generation, replenishment rules, and vendor performance analytics.

## License

This project is licensed under the terms described in the LICENSE.md
 file.

© 2025 Caliber Technologies LLC
For commercial or implementation inquiries, contact dev@calibertech.net