public with sharing class ApplicationGuardService {

    /**
     * Call from BEFORE INSERT/BEFORE UPDATE on:
     *   - Payment_Application__c
     *   - Deposit_Application__c
     *   - Credit_Memo_Application__c
     *
     * Enforces:
     *  - Parent Invoice must be Posted
     *  - Amount__c > 0 when Status__c = 'Applied'
     *  - No over-application beyond current Amount_Due__c (delta-aware on updates)
     *  - Blocks applying to fully paid invoices
     */
    public static void validateApplications(List<SObject> recs) {
        if (recs == null || recs.isEmpty()) return;

        // Shared field API names across your three *_Application__c objects
        final String F_INVOICE = 'Invoice__c';
        final String F_AMOUNT  = 'Amount__c';
        final String F_STATUS  = 'Status__c';

        // 1) Collect parent invoice Ids
        Set<Id> invoiceIds = new Set<Id>();
        for (SObject r : recs) {
            Id invId = (Id) r.get(F_INVOICE);
            if (invId != null) invoiceIds.add(invId);
        }
        if (invoiceIds.isEmpty()) return;

        // 2) Pull parent headers
        Map<Id, Invoice__c> invoices = new Map<Id, Invoice__c>([
            SELECT Id, Posting_Status__c, Status__c, Amount_Due__c, Total_Amount__c
            FROM Invoice__c
            WHERE Id IN :invoiceIds
        ]);

        // 3) Group incoming rows per invoice (Apex style—no lambdas)
        Map<Id, List<SObject>> byInvoice = new Map<Id, List<SObject>>();
        for (SObject r : recs) {
            Id invId = (Id) r.get(F_INVOICE);
            if (invId == null) {
                r.addError('Invoice is required.');
                continue;
            }
            if (!byInvoice.containsKey(invId)) {
                byInvoice.put(invId, new List<SObject>());
            }
            byInvoice.get(invId).add(r);
        }

        // 4) Validate per parent
        for (Id invId : byInvoice.keySet()) {
            Invoice__c inv = invoices.get(invId);
            if (inv == null) {
                for (SObject r : byInvoice.get(invId)) r.addError('Parent Invoice not found.');
                continue;
            }

            // Must be Posted to apply
            if (inv.Posting_Status__c != 'Posted') {
                for (SObject r : byInvoice.get(invId)) r.addError('Cannot apply to an Unposted invoice.');
                continue;
            }

            Decimal currentDue = inv.Amount_Due__c == null ? 0 : inv.Amount_Due__c;

            // If already fully paid, block any additional applications
            if (currentDue <= 0) {
                for (SObject r : byInvoice.get(invId)) r.addError('Invoice is fully paid; no additional applications are allowed.');
                continue;
            }

            // Compute net delta these rows introduce (insert/update aware)
            Decimal delta = 0;
            for (SObject r : byInvoice.get(invId)) {
                String status = (String) r.get(F_STATUS);
                if (status != 'Applied') continue; // only Applied affects balance

                Decimal amt = (Decimal) r.get(F_AMOUNT);
                if (amt == null || amt <= 0) {
                    r.addError('Amount must be greater than 0 for Applied records.');
                    continue;
                }

                if (Trigger.isUpdate && Trigger.oldMap != null) {
                    SObject oldR = Trigger.oldMap.get((Id) r.get('Id'));
                    if (oldR != null) {
                        String oldStatus = (String) oldR.get(F_STATUS);
                        Decimal oldAmt   = (Decimal) oldR.get(F_AMOUNT);
                        if (oldStatus == 'Applied') {
                            delta += amt - (oldAmt == null ? 0 : oldAmt);
                        } else {
                            delta += amt;
                        }
                        continue;
                    }
                }
                // insert path (or no old row)
                delta += amt;
            }

            // Over-application check: proposed delta cannot exceed current due
            if (delta > currentDue) {
                for (SObject r : byInvoice.get(invId)) {
                    String status = (String) r.get(F_STATUS);
                    Decimal amt = (Decimal) r.get(F_AMOUNT);
                    if (status == 'Applied' && amt != null && amt > 0) {
                        r.addError('Application amount exceeds the invoice Amount Due.');
                    }
                }
            }
        }
    }
}
