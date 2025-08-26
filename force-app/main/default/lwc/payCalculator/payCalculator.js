// This brings in special Salesforce tools for LWCs.
// LightningElement = the base “class” that all LWCs use.
// track = Tells Salesforce, if this value changes, update the screen automatically.
import { LightningElement, track } from 'lwc'; 

// Creates a new component called PayCalculator.
// "default" just means Salesforce knows this is the main thing to load from this file.
export default class PayCalculator extends LightningElement {
    // Track Salary Input
    // This makes a variable called salary, starting at 0.
    // The @track means keep watching this number, and if it changes, refresh the display.
    @track salary = 0;

    // Track Calculated Results as Formatted Strings
    // These are the results that will be shown on the screen. They start as "0.00" (a string that looks like money).
    @track federalTax = '0.00';
    @track socialSecurity = '0.00';
    @track medicare = '0.00';
    @track takeHomeYearly = '0.00';
    @track takeHomeMonthly = '0.00';

    // Standard Tax Rates
    // These are the built-in tax percentages. They don't change unless you edit them.
    federalTaxRate = 0.20;       // 20%
    socialSecurityRate = 0.062;  // 6.2%
    medicareRate = 0.0145;       // 1.45%

    // Handle Input Changes
    // This function runs whenever the User types into the Salary box.
    handleSalaryChange(event) {
        // "event.target.value" grabs what the User typed.
        //  "parseFloat" turns it into a number. If it's not a number (like someone left it blank), use 0.
        // Then, it calls calculateTakeHome() to update all the results.
        const value = parseFloat(event.target.value);
        this.salary = isNaN(value) ? 0 : value;
        this.calculateTakeHome();
    }

    // Calculate Take Home Pay
    // This does the math.
    calculateTakeHome() {
        const federal = this.salary * this.federalTaxRate; // Federal tax = salary × 20%
        const ss = this.salary * this.socialSecurityRate; // Social Security = salary × 6.2%
        const medicare = this.salary * this.medicareRate; // Medicare = salary × 1.45%
        // Subtracts all the Taxes from the Salary to find Yearly Take Home Pay, then divides by 12 for the Monthly Take Home Pay.
        const takeHomeYearly = this.salary - federal - ss - medicare;
        const takeHomeMonthly = takeHomeYearly / 12;

        // Format Results as Strings with Two Decimal Places
        // ".toFixed(2)" makes numbers look like money (always 2 decimal places, i.e. 1234.5 -> 1234.50).
        // Finally, it saves the results into the tracked variables, so the HTML screen updates.
        this.federalTax = federal.toFixed(2);
        this.socialSecurity = ss.toFixed(2);
        this.medicare = medicare.toFixed(2);
        this.takeHomeYearly = takeHomeYearly.toFixed(2);
        this.takeHomeMonthly = takeHomeMonthly.toFixed(2);
    }
}