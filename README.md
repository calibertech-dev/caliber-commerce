# Caliber Commerce

Caliber Commerce is the financial and transactional foundation of the **Caliber Platform**.  
It provides a unified model for **Proposals**, **Contracts**, **Invoices**, **Payments**, **Deposits**, and related financial operations—enabling accurate billing, revenue tracking, and seamless integration with both customer-facing and internal processes.

## Overview

This package defines the full commercial lifecycle from **Proposal → Contract → Invoice**, with a fully auditable **Transaction Register** that ensures financial accuracy and traceability.  
It introduces standardized billing objects, posting logic, and payment application tools that extend into accounting, subscriptions, and integrations such as Stripe or QuickBooks.

Caliber Commerce serves as the universal transaction engine across all Caliber Platform modules—supporting both **project-based** and **standalone** business workflows.

---

## Core Features

- **Proposals (Estimates / Quotes / Change Orders)** – Unified pricing documents supporting dynamic numbering and multi-route fulfillment (Project, Work Order, Order, or Service Contract).  
- **Contracts & Amendments** – Legal agreements assembled from modular text sections. Contract Amendments manage Change Orders and Addenda, directly linked to Change-type Proposals.  
- **Invoices** – Flexible, Stripe-compatible invoicing system with exact rounding logic, deposits, progress billing, and balance tracking.  
- **Deposits** – Dedicated prepayment object that represents customer deposits as liabilities and automatically applies them to future invoices.  
- **Transaction Register** – A central ledger that records invoices, payments, credits, and refunds, maintaining audit-grade financial accuracy.  
- **Payments & Refunds** – Supports partial payments, on-account credits, refunds, and reconciliation with Stripe or custom processors.  
- **Recurring Billing** – Subscriptions automate invoice generation based on defined cycles or usage.  
- **Declarative Deposit Policies** – Configurable rules that determine deposit percentages and thresholds per business unit.  
- **Cross-Package Integrations** – Seamless linkage to Projects, Work Orders, Orders, and Service Contracts for complete fulfillment workflows.  
- **Brand-Ready Document Templates** – Consistent merge layouts for Estimates, Contracts, Amendments, and Invoices across all brands.

---

## Package Dependencies

Required:

- **Caliber Core** – shared utilities, error handling, and metadata framework.

Optional extensions:

- **Caliber Project Management** – enables project billing, progress invoices, and phase-based fulfillment.  
- **Caliber Restoration** – integrates restoration workflows with the Commerce data model.  
- **Caliber MagicPlan Integration** – creates Proposals directly from field capture data.  
- **Salesforce Field Service** – integrates with Maintenance Plans and Service Contracts.

---

## Installation & Setup

1. Install dependencies in order:
   1. `Caliber Core`
   2. `Caliber Commerce`
2. Assign permission sets:
   - `Caliber Commerce Admin`
   - `Caliber Commerce User`
   - `Caliber Commerce Read Only`
3. Add **Caliber Commerce** Lightning App to App Launcher.  
4. Configure **Numbering Rules** (Custom Metadata) for Proposal and Invoice prefixes.  
5. Configure **Invoice Deposit Policies** to automate deposit and invoice generation.  
6. Enable optional Flows:
   - Proposal Acceptance and Fulfillment Creation  
   - Invoice Posting & Payment Application  
   - Deposit Generation & Application  
   - Subscription Invoice Generation

---

## Data Model

Caliber Commerce introduces a normalized, auditable financial data model that supports quoting, contracting, invoicing, and payments.

### Legal & Contract Objects

| Object | Description |
|---------|-------------|
| **Contract__c** | Primary agreement record with category and business unit tracking. |
| **Contract_Section__c** | Modular text blocks that compose contract and amendment content. |
| **Contract_Amendment__c** | Child record for modifying an existing Contract, including **Change Orders** and Addenda. Linked to the associated Change-type Proposal. |

---

### Proposal & Quoting Objects

| Object | Description |
|---------|-------------|
| **Proposal__c** | Unified document for **Estimates**, **Quotes**, and **Change Orders**. Determines fulfillment route and billing model. |
| **Proposal_Line__c** | Defines individual pricing lines, quantities, and scope. Includes fulfillment and source tracking for auditability. |
| **Invoice_Deposit_Policy__c** | Configurable business rules defining required deposits, thresholds, and invoice creation behavior. |
| **Deposit__c** | Represents a customer prepayment held as a liability until applied to invoices. |
| **Project_Billing_Line__c** | Created when a Proposal’s fulfillment route = Project. Tied to Project Phases for progress billing. |

#### Key Fields on Proposal

- `Proposal_Type__c` – *Estimate, Quote, Change*  
- `Fulfillment_Route__c` – *Project, Work Order, Order, Service Contract*  
- `Billing_Model__c` – *Standard, Progress, Recurring, Usage-Based*  
- `Deposit_Policy__c` – lookup to applicable deposit policy  
- `Original_Proposal__c` – links a Change Proposal to the original  
- `Amendment__c` – link to Contract Amendment when applicable  

#### Key Fields on Proposal Line

- `Fulfillment_Target__c` – *Project Phase, Work Order, Order, Service Contract*  
- `Source_Proposal_Line__c` – links to the original line being changed  
- `Discount_Type__c`, `Discount_Value__c`, `Discount_Amount__c` – standard discount structure  
- `Taxable__c`, `Unit_Net__c`, `Total_Price__c` – standardized pricing logic  

---

### Invoicing & Billing

| Object | Description |
|---------|-------------|
| **Invoice__c** | Core billing record representing earned revenue; supports taxes, deposits, discounts, and retainage. |
| **Invoice_Line__c** | Detailed line items copied from Proposal or Project Billing Lines. |
| **Project_Billing_Line__c** | Supports project-based billing; invoices generated automatically when phases are completed. |

#### Invoice Highlights

- `Invoice_Type__c` – *Standard, Progress, Final, Retainage*  
- `Status__c` – *Draft, Posted, Paid, Voided*  
- `Balance__c` – uses negative-accounting convention for liability accuracy.  
- `Posting_Status__c` – sync flag for Transaction Register entries.

---

### Payments, Deposits & Refunds

| Object | Description |
|---------|-------------|
| **Deposit__c** | Prepayment record linked to a Proposal or Contract; applied to invoices when work begins. |
| **Payment__c** | Records a customer’s remittance (Stripe, ACH, etc.). |
| **Payment_Session__c** | Represents a Stripe Checkout or PaymentIntent session. |
| **Payment_Application__c** | Connects a payment (or deposit) to one or more invoices. |
| **Refund__c** | Outbound transaction reversing payment or deposit; reconciles to the original record. |

---

### Credits & Adjustments

| Object | Description |
|---------|-------------|
| **Credit_Memo__c** | Issued credit used to offset invoice balances. |
| **Credit_Memo_Line__c** | Line-level details of credited items. |
| **Credit_Memo_Application__c** | Tracks credit applications against invoices or accounts. |

---

### Financial Ledger

| Object | Description |
|---------|-------------|
| **Transaction_Register__c** | Master ledger that records every posting event (invoice, payment, refund, credit). Forms the backbone of audit and reconciliation. |

---

### Recurring Billing

| Object | Description |
|---------|-------------|
| **Subscription__c** | Automates recurring invoices for contracts or service plans. Integrates with deposit logic and Transaction Register for recurring entries. |

---

## Fulfillment Routes

| Route | Fulfillment Object | Billing Trigger | Description |
|-------|--------------------|-----------------|--------------|
| **Project** | Project / Project Phases | Phase Completed | Generates invoices for all Project Billing Lines linked to completed phases. |
| **Work Order** | Work Order + Work Order Lines | Work Order Closed | Used for single-service jobs; invoices automatically upon closure. |
| **Order** | Order + Order Items | Order Fulfilled | Used for product sales; invoices upon fulfillment. |
| **Service Contract** | Service Contract / Maintenance Plan | Work Order Generated & Closed | Enables maintenance agreements and recurring service schedules. |

---

## Change Orders & Amendments

Change Orders are implemented using **Proposal (Type = Change)** records linked to a **Contract Amendment**.

- `Proposal_Type__c = Change` represents the pricing deltas.  
- `Contract_Amendment__c.Amendment_Type__c = Change Order` provides the legal wrapper.  
- `Original_Proposal__c` on the Change Proposal links back to the base.  
- `Source_Proposal_Line__c` on each line connects to its original for delta math.  
- Totals roll up to the Contract Amendment for doc generation.

---

## Customer Deposit Workflow

1. **Proposal Accepted** → Policy lookup (`Invoice_Deposit_Policy__c`) determines required deposit.  
2. **Deposit__c Created** → Deposit amount and terms recorded.  
3. **Customer Pays** → Payment captured via Stripe or other method.  
4. **Deposit Posted** → Liability entered in Transaction Register.  
5. **Invoice Posted** → Deposit applied through Payment Application.  
6. **Deposit Closed** → Remaining balance cleared or refunded.

---

## Roadmap

- Account-level running balance and credit rollups.  
- General Ledger export extension (Accounting package).  
- Multi-currency and jurisdictional tax support.  
- Customer portal for invoice payment and document access.  
- Advanced Stripe, QuickBooks, and ACH integration options.

---

## License

This project is licensed under the terms described in the [LICENSE.md](./LICENSE.md) file.

© 2025 Caliber Technologies LLC  
For commercial or implementation inquiries, contact **<dev@calibertech.net>**
