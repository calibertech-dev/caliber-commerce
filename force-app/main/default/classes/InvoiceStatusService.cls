public with sharing class InvoiceStatusService {

    // Decide and apply Status__c for the given invoices, based on Amount_Due__c and Posting_Status__c.
    public static void recalcForInvoices(Set<Id> invoiceIds) {
        if (invoiceIds == null || invoiceIds.isEmpty()) return;

        List<Invoice__c> toUpdate = new List<Invoice__c>();
        for (Invoice__c inv : [
            SELECT Id, Posting_Status__c, Status__c,
                   Total_Amount__c, Amount_Due__c
            FROM Invoice__c
            WHERE Id IN :invoiceIds
        ]) {
            // Only auto-update when the invoice is Posted (accounting lock).
            if (inv.Posting_Status__c != 'Posted') continue;

            Decimal total = inv.Total_Amount__c == null ? 0 : inv.Total_Amount__c;
            Decimal due   = inv.Amount_Due__c  == null ? 0 : inv.Amount_Due__c;
            if (due <= 0) {
                // Fully satisfied
                setIfChanged(inv, 'Paid', toUpdate);
                continue;
            }
            // Some balance remains (>0). Determine whether anything has been applied.
            Decimal applied = (total - due);
            if (applied > 0) {
                setIfChanged(inv, 'Partially Paid', toUpdate);
            } else {
                setIfChanged(inv, 'Open', toUpdate);
            }
        }
        if (!toUpdate.isEmpty()) update toUpdate;
    }

    // Helper: only stage updates when a change is needed.
    private static void setIfChanged(Invoice__c inv, String newStatus, List<Invoice__c> bucket) {
        if (inv.Status__c != newStatus) {
            Invoice__c upd = new Invoice__c(Id = inv.Id);
            upd.Status__c = newStatus;
            bucket.add(upd);
        }
    }
}
