# Best Practice Analyzer Automation (BPAA)
Just a fancy automation/script to run the Best Practice Analyzer of Tabular Editor over all datasets in the Power BI Service.

The power of this script is of course in the Best Practice Analyzer that is part of Tabular Editor! 
Please visit https://tabulareditor.com/ and reach out Daniel Otykier and thank him!

If you want to modify the best-practices rules, or add your own, contribute to the rules on GitHub:
https://github.com/TabularEditor/BestPracticeRules#contributing. 

## how it works
- The script loopts the workspaces that the given service principal has the member or admin role membership in (the script installs the PowerShell Power BI management module MicrosoftPowerBIMgmt)
- The script then runs the Best Practice Analyzer on each data model in the workspace (the script downloads the portable version of Tabular Editor to do this).
- The script will output the results of each analysis in the given directory as .trx files, a standard VSTEST result (JSON).
- The script will download and open the Power BI template report of the solution, that will load the .trx files and provides a start to analyze the results.


## prerequisites
- You need a Service Principal (e.g. App Registration) in Azure Active Directory. Nothing special, just add a secret to it and write down the ClientId, Secret, TenantId.
- Download the latest version of the BPAA solution from the repo in GitHub. Unzip the BPAA solution to a directory of choice. (or only the BPAA.ps1 file). 
- Add the Service Principal of step 1 to all Power BI workspaces, and make sure it has the ‘member’ or ‘admin’ role. If you have more than a dozen workspaces you would want to script this! No worries, I’ve added a script for that in the BPAA repo. You can find it in the directory of step 3. Note: you need the correct ObjectId of the Service Principal! You can find it in the “Enterprise applications” screen in Azure Active Directory (not the App Registrations screen!).
- The solution only works on v2 workspaces. So, this might be an appropriate time to upgrade those workspaces?
- The solution only works on workspaces in Premium capacity (it needs the XMLA endpoint). You could spin up an Azure Power BI Embedded (A sku) for the duration of this exercise, and connect the workspaces to that capacity. When you’re done you connect them back to shared capacity and suspend the premium capacity.


Also credits and thanks to https://mnaoumov.wordpress.com/ for the functions to help call the .exe.
