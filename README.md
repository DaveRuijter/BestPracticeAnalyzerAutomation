# Best Practice Analyzer Automation (BPAA)
Just a fancy automation/script to run the Best Practice Analyzer of Tabular Editor over all datasets in the Power BI Service.

The power of this script is of course in the Best Practice Analyzer that is part of Tabular Editor! 
Please visit https://tabulareditor.com/ and reach out Daniel Otykier and thank him!

If you want to modify the best-practices rules, or add your own, contribute to the rules on GitHub:
https://github.com/TabularEditor/BestPracticeRules#contributing. 

- The script loopts the workspaces that the given service principal has the admin role membership in.
- The script will output the results of each analysis in the given directory as .trx files, a standard VSTEST result (JSON).
- The script downloads the portable version of Tabular Editor to a new folder called TabularEditorPortable in the directory of this .ps1.
- The script installs the PowerShell Power BI management module (MicrosoftPowerBIMgmt).

Also credits and thanks to https://mnaoumov.wordpress.com/ for the functions to help call the .exe.
