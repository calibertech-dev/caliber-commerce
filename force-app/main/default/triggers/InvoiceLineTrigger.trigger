trigger InvoiceLineTrigger on Invoice_Line__c (before insert, before update, before delete) {
    InvoiceLineGuardService.run(Trigger.new, Trigger.old, Trigger.isInsert, Trigger.isUpdate, Trigger.isDelete);
}
