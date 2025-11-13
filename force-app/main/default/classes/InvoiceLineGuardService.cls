public with sharing class InvoiceLineGuardService {
    public static void run(
        List<Invoice_Line__c> newList,
        List<Invoice_Line__c> oldList,
        Boolean isInsert,
        Boolean isUpdate,
        Boolean isDelete
    ) {
        // Collect parent Invoice Ids from whichever context we have
        Set<Id> invoiceIds = new Set<Id>();
        if (isInsert || isUpdate) {
            for (Invoice_Line__c l : newList) if (l.Invoice__c != null) invoiceIds.add(l.Invoice__c);
        }
        if (isDelete) {
            for (Invoice_Line__c l : oldList) if (l.Invoice__c != null) invoiceIds.add(l.Invoice__c);
        }
        if (invoiceIds.isEmpty()) return;

        // Query parents' posting status
        Map<Id, Invoice__c> parents = new Map<Id, Invoice__c>([
            SELECT Id, Posting_Status__c
            FROM Invoice__c
            WHERE Id IN :invoiceIds
        ]);

        // If parent is Posted, block edits/inserts/deletes
        if (isInsert || isUpdate) {
            for (Invoice_Line__c l : newList) {
                Invoice__c p = parents.get(l.Invoice__c);
                if (p != null && p.Posting_Status__c == 'Posted') {
                    l.addError('Invoice is Posted (locked). Unpost the invoice to modify line items.');
                }
            }
        }
        if (isDelete) {
            for (Invoice_Line__c l : oldList) {
                Invoice__c p = parents.get(l.Invoice__c);
                if (p != null && p.Posting_Status__c == 'Posted') {
                    l.addError('Invoice is Posted (locked). Unpost the invoice to delete line items.');
                }
            }
        }
    }
}
