public with sharing class InvoicePostingService {
    // Sets Invoice_Date__c on transition to Posted (only if blank).
    public static void handleBefore(List<Invoice__c> news, Map<Id, Invoice__c> olds) {
        if (news == null || news.isEmpty()) return;
        Date today = Date.today();

        for (Invoice__c inv : news) {
            Boolean isInsert = (olds == null);
            Invoice__c oldInv = isInsert ? null : olds.get(inv.Id);

            Boolean transitionedToPosted =
                !isInsert &&
                oldInv != null &&
                oldInv.Posting_Status__c != 'Posted' &&
                inv.Posting_Status__c == 'Posted';

            // Also handle insert edge-case: records inserted already marked Posted
            Boolean insertedAsPosted =
                isInsert && inv.Posting_Status__c == 'Posted';

            if ((transitionedToPosted || insertedAsPosted) && inv.Invoice_Date__c == null) {
                inv.Invoice_Date__c = today;
            }
        }
    }
}
