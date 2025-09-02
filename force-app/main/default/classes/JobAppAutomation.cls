    // This is an Apex Class named JobAppAutomation.
    // The "with sharing" keyword makes sure Salesforce Security Rules (like Record Sharing) are respected, so Users only see or update Records they're allowed to).
    public with sharing class JobAppAutomation {

        // -------------------------------------------------------
        // Method: calculatePaychecks
        // Purpose: For each Job Application, calculate paycheck breakdowns.
        // Usage: Called in BEFORE Triggers, so calculated values are saved with the Record.
        // -------------------------------------------------------
        public static void calculatePaychecks(List<Job_Application__c> jobApps) {

            // Check if the Running User has permission to update the Job Application Record, if not, exit the Method immediately.
            if (!Schema.sObjectType.Job_Application__c.isUpdateable()) {
                return; // Stop if no update access.
            }

            // Loop through each Job Application Record passed in.
            for (Job_Application__c app : jobApps) {

                // Step 0: Default Salary to 0 if null, so calculations won't fail.
                Decimal salary = (app.Salary__c != null) ? app.Salary__c : 0;

                // Step 1: Save basic paycheck breakdowns.
                app.Paycheck_Yearly__c     = salary;           // Save Yearly Salary (or 0 if blank)
                app.Paycheck_Monthly__c    = salary / 12;      // Divide Yearly by 12 (Monthly)
                app.Paycheck_Bi_Weekly__c  = salary / 26;      // Divide Yearly by 26 (Bi-Weekly)
                app.Paycheck_Weekly__c     = salary / 52;      // Divide Yearly by 52 (Weekly)
                app.Paycheck_Six_Months__c = salary / 2;       // Divide Yearly by 2 (6-Month Estimate)

                // Step 2: Calculate Federal, Social Security, and Medicare Taxes.
                Decimal federalTaxRate = 0.20;       // Universal Federal (Estimate): 20%
                Decimal socialSecurityRate = 0.062; // Social Security: 6.2%
                Decimal medicareRate = 0.0145;      // Medicare: 1.45%

                // Calculate Estimated Deductions.
                Decimal estimatedFederal = salary * federalTaxRate;
                Decimal estimatedSS = salary * socialSecurityRate;
                Decimal estimatedMedicare = salary * medicareRate;

                // Store Calculated Tax Values in Custom Fields.
                app.Federal_Tax__c       = estimatedFederal;
                app.Social_Security__c   = estimatedSS;
                app.Medicare__c          = estimatedMedicare;

                // Step 3: Calculate Take Home Pay (Yearly & Monthly).
                Decimal takeHome = salary - (estimatedFederal + estimatedSS + estimatedMedicare);

                // Store the Results in Custom Fields.
                app.Take_Home_Pay__c        = takeHome;              // Yearly Take Home Pay
                app.Take_Home_Pay_Monthly__c = takeHome / 12;        // Monthly Take Home Pay

                // Primary Contact Automation: If Primary Contact is null (has not yet been assigned), and there is at least one related Contact, set it automatically.
                if (app.Primary_Contact__c == null) {
                    // Query to find the first related Contact for this Job Application via the Job Application Contact Junction Object.
                    List<Contact> relatedContacts = [
                        SELECT Id FROM Contact
                        WHERE Id IN (
                            SELECT Contact__c 
                            FROM Job_Application_Contact__c
                            WHERE Job_Application__c = :app.Id
                        )
                        ORDER BY CreatedDate ASC // Pick the oldest one.
                        LIMIT 1
                    ];

                    // If any Contact is found, assign the first related Contact as the Primary Contact.
                    if (!relatedContacts.isEmpty()) {
                        app.Primary_Contact__c = relatedContacts[0].Id;
                    }
                }
            }
        }
        
        // -------------------------------------------------------
        // Method: assignPrimaryContact
        // Purpose: Separate Method to assign Primary Contact based on Job Application Contact Records that is more efficient and bulk-safe.
        // -------------------------------------------------------
        public static void assignPrimaryContact(List<Job_Application__c> jobApps) {
           // Collect all Job Application Ids into a Set for filtering in SOQL.
            Set<Id> jobAppIds = new Set<Id>(); // Store all Job Application Record Ids.
            for(Job_Application__c ja : jobApps) jobAppIds.add(ja.Id); // Collect Ids from input List.

            // Create a Map that will store the first related Contact for each Job Application.
            Map<Id, Job_Application_Contact__c> primaryMap = new Map<Id, Job_Application_Contact__c>();
            // Query all Job Application Contact links for the given Job Applications, ordered by CreatedDate ASC, so the first one is the "oldest".
            for(Job_Application_Contact__c jac : [
                SELECT Id, Job_Application__c, Contact__c
                FROM Job_Application_Contact__c
                WHERE Job_Application__c IN :jobAppIds
                ORDER BY CreatedDate ASC
            ]) {
                // If this Job Application doesn't already have a Contact in the Map, add the first one found.
                if(!primaryMap.containsKey(jac.Job_Application__c)) {
                    primaryMap.put(jac.Job_Application__c, jac);
                }
            }

            // Loop through each Job Application passed in.
            for(Job_Application__c ja : jobApps) {
                // If we found a related Contact in the Map, assign it as the Primary Contact.
                if(primaryMap.containsKey(ja.Id)) {
                    ja.Primary_Contact__c = primaryMap.get(ja.Id).Contact__c;
                }
            }
        }

        // -------------------------------------------------------
        // Helper Method: getTasksForJobApplication
        // Purpose: Given one Job Application and its existing Tasks, return the new Tasks that should be created based on its Status.
        // -------------------------------------------------------
        private static List<Task> getTasksForJobApplication(Job_Application__c app, Id taskOwnerId, Set<String> existingSubjects) {
            List<Task> tasks = new List<Task>();

            System.debug('Entering Helper for Job Application Id = ' + app.Id + ', Status=' + app.Status__c);

            switch on app.Status__c {

                when 'Saved' {
                    // Add 3 Tasks for Job Applications with "Saved" Status.
                    if (!existingSubjects.contains('Review Job Description and Align with Interests')) {
                        tasks.add(new Task(
                            WhatId = app.Id,
                            Subject = 'Review Job Description and Align with Interests',
                            ActivityDate = System.today().addDays(1),
                            Status = 'Not Started',
                            OwnerId = taskOwnerId
                        ));
                        System.debug('Task added: Review Job Description and Align with Interests');
                    }
                    if (!existingSubjects.contains('Review Highlighted Skills for Role Fit')) {
                        tasks.add(new Task(
                            WhatId = app.Id,
                            Subject = 'Review Highlighted Skills for Role Fit',
                            ActivityDate = System.today().addDays(2),
                            Status = 'Not Started',
                            OwnerId = taskOwnerId
                        ));
                        System.debug('Task added: Review Highlighted Skills for Role Fit');
                    }
                    if (!existingSubjects.contains('Research Company or Role and Mark Excitement Level')) {
                        tasks.add(new Task(
                            WhatId = app.Id,
                            Subject = 'Research Company or Role and Mark Excitement Level',
                            ActivityDate = System.today().addDays(3),
                            Status = 'Not Started',
                            OwnerId = taskOwnerId
                        ));
                        System.debug('Task added: Research Company or Role and Mark Excitement Level');
                    }
                }

                when 'Applying' {
                    // Add 5 Tasks to guide through the Job Applications process. Each is scheduled 1–5 days out.
                    if (!existingSubjects.contains('Find and Research Someone at the Company')) {
                        tasks.add(new Task(
                            WhatId = app.Id,
                            Subject = 'Find and Research Someone at the Company',
                            ActivityDate = System.today().addDays(1),
                            Status = 'Not Started',
                            OwnerId = taskOwnerId
                        ));
                        System.debug('Task added: Find and Research Someone at the Company');
                    }
                    if (!existingSubjects.contains('Setup Informational Interview')) {
                        tasks.add(new Task(
                            WhatId = app.Id,
                            Subject = 'Setup Informational Interview',
                            ActivityDate = System.today().addDays(2),
                            Status = 'Not Started',
                            OwnerId = taskOwnerId
                        ));
                        System.debug('Task added: Setup Informational Interview');
                    }
                    if (!existingSubjects.contains('Identify Potential Referrals')) {
                        tasks.add(new Task(
                            WhatId = app.Id,
                            Subject = 'Identify Potential Referrals',
                            ActivityDate = System.today().addDays(3),
                            Status = 'Not Started',
                            OwnerId = taskOwnerId
                        ));
                        System.debug('Task added: Identify Potential Referrals');
                    }
                    if (!existingSubjects.contains('Customize Work Achievements using Job Description Keywords')) {
                        tasks.add(new Task(
                            WhatId = app.Id,
                            Subject = 'Customize Work Achievements using Job Description Keywords',
                            ActivityDate = System.today().addDays(4),
                            Status = 'Not Started',
                            OwnerId = taskOwnerId
                        ));
                        System.debug('Task added: Customize Work Achievements');
                    }
                    if (!existingSubjects.contains('Submit Application on Company Website - If Possible')) {
                        tasks.add(new Task(
                            WhatId = app.Id,
                            Subject = 'Submit Application on Company Website - If Possible',
                            ActivityDate = System.today().addDays(5),
                            Status = 'Not Started',
                            OwnerId = taskOwnerId
                        ));
                        System.debug('Task added: Submit Application on Company Website - If Possible');
                    }
                }

                when 'Applied' {
                    // Add 4 Tasks after Job Applications submission.
                    if (!existingSubjects.contains('Reach Out to Hiring Manager or Recruiter')) {
                        tasks.add(new Task(
                            WhatId = app.Id,
                            Subject = 'Reach Out to Hiring Manager or Recruiter',
                            ActivityDate = System.today().addDays(1),
                            Status = 'Not Started',
                            OwnerId = taskOwnerId
                        ));
                        System.debug('Task added: Reach Out to Hiring Manager or Recruiter');
                    }
                    if (!existingSubjects.contains('Follow-Up Weekly on Application')) {
                        tasks.add(new Task(
                            WhatId = app.Id,
                            Subject = 'Follow-Up Weekly on Application',
                            ActivityDate = System.today().addDays(7),
                            Status = 'Not Started',
                            OwnerId = taskOwnerId
                        ));
                        System.debug('Task added: Follow-Up Weekly on Application');
                    }
                    if (!existingSubjects.contains('Continue Saving Similar Job Opportunities')) {
                        tasks.add(new Task(
                            WhatId = app.Id,
                            Subject = 'Continue Saving Similar Job Opportunities',
                            ActivityDate = System.today().addDays(3),
                            Status = 'Not Started',
                            OwnerId = taskOwnerId
                        ));
                        System.debug('Task added: Continue Saving Similar Job Opportunities');
                    }
                    if (!existingSubjects.contains('Setup Weekly Networking Calls')) {
                        tasks.add(new Task(
                            WhatId = app.Id,
                            Subject = 'Setup Weekly Networking Calls',
                            ActivityDate = System.today().addDays(4),
                            Status = 'Not Started',
                            OwnerId = taskOwnerId
                        ));
                        System.debug('Task added: Setup Weekly Networking Calls');
                    }
                }

                when 'Interviewing' {
                    // Add 5 Tasks to prepare for interviews.
                    if (!existingSubjects.contains('Prepare "Tell Me About Yourself" Blurb')) {
                        tasks.add(new Task(
                            WhatId = app.Id,
                            Subject = 'Prepare "Tell Me About Yourself" Blurb',
                            ActivityDate = System.today().addDays(1),
                            Status = 'Not Started',
                            OwnerId = taskOwnerId
                        ));
                        System.debug('Task added: Prepare "Tell Me About Yourself" Blurb');
                    }
                    if (!existingSubjects.contains('Practice Behavioral Interview Questions')) {
                        tasks.add(new Task(
                            WhatId = app.Id,
                            Subject = 'Practice Behavioral Interview Questions',
                            ActivityDate = System.today().addDays(2),
                            Status = 'Not Started',
                            OwnerId = taskOwnerId
                        ));
                        System.debug('Task added: Practice Behavioral Interview Questions');
                    }
                    if (!existingSubjects.contains('Research Company and Interviewers')) {
                        tasks.add(new Task(
                            WhatId = app.Id,
                            Subject = 'Research Company and Interviewers',
                            ActivityDate = System.today().addDays(3),
                            Status = 'Not Started',
                            OwnerId = taskOwnerId
                        ));
                        System.debug('Task added: Research Company and Interviewers');
                    }
                    if (!existingSubjects.contains('Setup Virtual Interview Space and Test Tech')) {
                        tasks.add(new Task(
                            WhatId = app.Id,
                            Subject = 'Setup Virtual Interview Space and Test Tech',
                            ActivityDate = System.today().addDays(4),
                            Status = 'Not Started',
                            OwnerId = taskOwnerId
                        ));
                        System.debug('Task added: Setup Virtual Interview Space');
                    }
                    if (!existingSubjects.contains('Send Thank You Emails within 24 Hours')) {
                        tasks.add(new Task(
                            WhatId = app.Id,
                            Subject = 'Send Thank You Emails within 24 Hours',
                            ActivityDate = System.today().addDays(5),
                            Status = 'Not Started',
                            OwnerId = taskOwnerId
                        ));
                        System.debug('Task added: Send Thank You Emails within 24 Hours');
                    }
                }

                when 'Negotiating' {
                    // Add 3 Tasks to help with offer negotiation.
                    if (!existingSubjects.contains('Research Market Value and Prepare Numbers')) {
                        tasks.add(new Task(
                            WhatId = app.Id,
                            Subject = 'Research Market Value and Prepare Numbers',
                            ActivityDate = System.today().addDays(1),
                            Status = 'Not Started',
                            OwnerId = taskOwnerId
                        ));
                        System.debug('Task added: Research Market Value and Prepare Numbers');
                    }
                    if (!existingSubjects.contains('Prepare Negotiation Scripts')) {
                        tasks.add(new Task(
                            WhatId = app.Id,
                            Subject = 'Prepare Negotiation Scripts',
                            ActivityDate = System.today().addDays(2),
                            Status = 'Not Started',
                            OwnerId = taskOwnerId
                        ));
                        System.debug('Task added: Prepare Negotiation Scripts');
                    }
                    if (!existingSubjects.contains('Evaluate Offer and Accept / Decline')) {
                        tasks.add(new Task(
                            WhatId = app.Id,
                            Subject = 'Evaluate Offer and Accept / Decline',
                            ActivityDate = System.today().addDays(3),
                            Status = 'Not Started',
                            OwnerId = taskOwnerId
                        ));
                        System.debug('Task added: Evaluate Offer and Accept / Decline');
                    }
                }

                when 'Accepted' {
                    // Add 3 Tasks after offer is accepted / for onboarding preparation.
                    if (!existingSubjects.contains('Plan Resignation - If Applicable')) {
                        tasks.add(new Task(
                            WhatId = app.Id,
                            Subject = 'Plan Resignation - If Applicable',
                            ActivityDate = System.today().addDays(1),
                            Status = 'Not Started',
                            OwnerId = taskOwnerId
                        ));
                        System.debug('Task added: Plan Resignation - If Applicable');
                    }
                    if (!existingSubjects.contains('Take Time to Relax and Recharge')) {
                        tasks.add(new Task(
                            WhatId = app.Id,
                            Subject = 'Take Time to Relax and Recharge',
                            ActivityDate = System.today().addDays(2),
                            Status = 'Not Started',
                            OwnerId = taskOwnerId
                        ));
                        System.debug('Task added: Take Time to Relax and Recharge');
                    }
                    if (!existingSubjects.contains('Prepare for First Day of Onboarding')) {
                        tasks.add(new Task(
                            WhatId = app.Id,
                            Subject = 'Prepare for First Day of Onboarding',
                            ActivityDate = System.today().addDays(3),
                            Status = 'Not Started',
                            OwnerId = taskOwnerId
                        ));
                        System.debug('Task added: Prepare for First Day of Onboarding');
                    }
                }

                when 'Closed' {
                    // Add 2 reflection Tasks when Job Applications is closed.
                    if (!existingSubjects.contains('Send Follow-Up Email Thanking Interviewer and Ask for Feedback')) {
                        tasks.add(new Task(
                            WhatId = app.Id,
                            Subject = 'Send Follow-Up Email Thanking Interviewer and Ask for Feedback',
                            ActivityDate = System.today().addDays(1),
                            Status = 'Not Started',
                            OwnerId = taskOwnerId
                        ));
                        System.debug('Task added: Send Follow-Up Email Thanking Interviewer');
                    }
                    if (!existingSubjects.contains('Review Notes and Reflect on Areas of Improvement')) {
                        tasks.add(new Task(
                            WhatId = app.Id,
                            Subject = 'Review Notes and Reflect on Areas of Improvement',
                            ActivityDate = System.today().addDays(2),
                            Status = 'Not Started',
                            OwnerId = taskOwnerId
                        ));
                        System.debug('Task added: Review Notes and Reflect on Areas of Improvement');
                    }
                }

                when else {
                    // Do nothing for undefined Statuses.
                    System.debug('No Tasks created. Status=' + app.Status__c);
                }
            }

            return tasks;
        }

        // -------------------------------------------------------
        // Method: createFollowUpTasks
        // Purpose: Create Tasks for Job Applications (depending on their Status) after they have been inserted / updated.
        // Usage: Called in AFTER Triggers, so WhatId is populated.
        // -------------------------------------------------------

        // Static variable to prevent recursion in the same transaction.
        private static Boolean tasksAlreadyCreated = false;

        public static void createFollowUpTasks(List<Job_Application__c> jobApps) {

            // Prevent recursion. Exit early if Tasks were already created in this transaction.
            if (tasksAlreadyCreated) {
                System.debug('Exiting early. Tasks already created in this transaction.');
                return;
            }
            tasksAlreadyCreated = true; // Mark as true, so this block won't run again in this transaction.
            System.debug('Starting createFollowUpTasks. Job Apps count=' + jobApps.size());

            // Check if the Running User has permission to create Tasks. If not, exit the Method.
            if (!Schema.sObjectType.Task.isCreateable()) {
                System.debug('User does not have permission to create Tasks. Exiting.');
                return;
            }

            // Collect all Job Application Ids for querying existing Tasks.
            Set<Id> jobAppIds = new Set<Id>();
            for (Job_Application__c app : jobApps) {
                if (app.Id != null) {
                    jobAppIds.add(app.Id);
                }
            }
            System.debug('Collected Job App Ids: ' + jobAppIds);

            // Query existing Tasks linked to these Job Applications, keyed by WhatId (Job App Id).
            Map<Id, List<Task>> existingTasksByJobApp = new Map<Id, List<Task>>();
            if (!jobAppIds.isEmpty()) {
                for (Task t : [
                    SELECT Id, WhatId, Subject
                    FROM Task
                    WHERE WhatId IN :jobAppIds
                ]) {
                    if (!existingTasksByJobApp.containsKey(t.WhatId)) {
                        existingTasksByJobApp.put(t.WhatId, new List<Task>());
                    }
                    existingTasksByJobApp.get(t.WhatId).add(t);
                }
            }
            System.debug('Existing Tasks grouped by Job App: ' + existingTasksByJobApp.keySet());

            // List to hold all Task Records we'll create.
            List<Task> tasksToInsert = new List<Task>();

            // Loop through each Job Application Record.
            for (Job_Application__c app : jobApps) {
                Id taskOwnerId = (app.OwnerId != null) ? app.OwnerId : UserInfo.getUserId();

                // Get existing Subjects for this Job Application to prevent duplicates.
                Set<String> existingSubjects = new Set<String>();
                if (existingTasksByJobApp.containsKey(app.Id)) {
                    for (Task t : existingTasksByJobApp.get(app.Id)) {
                        existingSubjects.add(t.Subject);
                    }
                }

                // Call the Helper to generate Tasks for this Job Application.
                tasksToInsert.addAll(getTasksForJobApplication(app, taskOwnerId, existingSubjects));
            }

            // Insert only if we have new Tasks.
            if (!tasksToInsert.isEmpty()) {
                System.debug('Inserting ' + tasksToInsert.size() + ' new Tasks.');
                insert tasksToInsert;
            } else {
                System.debug('No new Tasks to insert.');
            }
        }
    }