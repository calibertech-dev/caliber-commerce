public with sharing class InvoiceTermsService {
    // Supported Terms values (per your picklist)
    private static final Set<String> TERM_KEYS = new Set<String>{
        'Due on Receipt','Net 7','Net 15','Net 30','Net 45','Net 60','Custom'
    };

    // Map Terms -> days offset (Custom handled by caller: we skip automation in that case)
    private static final Map<String, Integer> TERM_DAYS = new Map<String, Integer>{
        'Due on Receipt' => 0,
        'Net 7'          => 7,
        'Net 15'         => 15,
        'Net 30'         => 30,
        'Net 45'         => 45,
        'Net 60'         => 60
        // 'Custom' intentionally omitted so default falls back to 0
    };

    private static Integer daysFor(String terms) {
        if (terms == null) return 0;
        return TERM_DAYS.containsKey(terms) ? TERM_DAYS.get(terms) : 0;
    }

    public static void applyTermsDates(List<Invoice__c> news, Map<Id, Invoice__c> olds) {
        if (news == null || news.isEmpty()) return;
        Date today = Date.today();

        for (Invoice__c inv : news) {
            // Ignore unexpected Terms values (future-proof)
            if (inv.Terms__c != null && !TERM_KEYS.contains(inv.Terms__c)) continue;

            Boolean isInsert      = (olds == null);
            Invoice__c oldInv     = isInsert ? null : olds.get(inv.Id);
            Boolean termsChanged  = !isInsert && inv.Terms__c != oldInv.Terms__c;
            Boolean dateChanged   = !isInsert && inv.Invoice_Date__c != oldInv.Invoice_Date__c;

            // Skip all automation if Terms = Custom
            if (inv.Terms__c == 'Custom') {
                continue;
            }

            // Recalculate Due_Date__c when inserting, when Terms changed (not Custom),
            // when Invoice_Date__c changed, or when Due_Date__c is blank (backfill)
            if (isInsert || termsChanged || dateChanged || inv.Due_Date__c == null) {
                Date base = inv.Invoice_Date__c != null ? inv.Invoice_Date__c : today;
                inv.Due_Date__c = base.addDays(daysFor(inv.Terms__c));
            }
        }
    }
}
