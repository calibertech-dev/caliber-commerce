## Field Changes and Mapping from Original Caliber Platform (Production)

⚙️ Field Rename: Balance_Due__c → Balance__c
Purpose: Simplify naming, avoid confusion with Amount_Due__c display field.
Impact: All formulas, rollups, and automation previously referencing Balance_Due__c
        must be updated to use Balance__c.
Migration handled in pre/post-install scripts.
Execute: ```UPDATE [SELECT Id, Balance_Due__c, Balance__c FROM Invoice__c WHERE Balance__c = NULL];```