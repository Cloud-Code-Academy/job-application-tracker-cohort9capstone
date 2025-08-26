// This Trigger runs automatically on Job Application Records when they are inserted (new) or updated (edited).
// It listens for changes to Job Application Records and then automatically runs some extra logic before or after the Record is saved in Salesforce.
// i.e. Whenever a Job Application Record is saved, do these extra steps to keep data accurate and automated.
trigger JobAppTrigger on Job_Application__c (before insert, before update, after insert, after update) {

    // -------------------------------------------------------
    // BEFORE Triggers: Calculate paycheck breakdowns and sets Primary Contact automatically if null and related Contacts exist.
    // Purpose: Save Paycheck_*__c Fields and Primary_Contact__c directly on Job Application before Record is committed.
    // "Before" means this code runs before Salesforce actually saves the Job Application Record into the database.
    // This is the perfect time to fill in Fields or calculate values directly on the Record before it gets stored.
    // -------------------------------------------------------
    if(Trigger.isBefore){ 
        // Call our Helper Class (JobAppAutomation) to calculate paycheck amounts for all Records being saved in this transaction.
        // Trigger.new is a list of Job Applications being saved right now (could be 1 Record or 200 at once in bulk).
        JobAppAutomation.calculatePaychecks(Trigger.new);
    }

    // -------------------------------------------------------
    // AFTER Triggers: Create follow-up Tasks for Job Applications.
    // Purpose: Tasks require Job Application Id (WhatId), which only exists after insert (creation).
    // The createFollowUpTasks Method now automatically creates Tasks based on Status.
    // "After" means this code runs after Salesforce has already saved the Job Application Record into the database.
    // At this point, the Record has an official Salesforce Id. Some related Records (like Tasks) require that Id in order to exist.
    // -------------------------------------------------------
    if(Trigger.isAfter){
        
        // AFTER Insert
        // This runs right after a brand new Job Application Record is created in Salesforce.
        // At this moment, the Record has an Id, so we can safely create related Tasks for it.
        if(Trigger.isInsert){
            JobAppAutomation.createFollowUpTasks(Trigger.new);
        }

        // AFTER Update
        // This runs right after an existing Job Application Record has been edited and saved.
        if(Trigger.isUpdate){
            JobAppAutomation.createFollowUpTasks(Trigger.new);
        }
    }
}