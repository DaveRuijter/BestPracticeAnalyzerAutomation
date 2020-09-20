﻿# =================================================================================================================================================
# Best Practice Analyzer Automation (BPAA)
# 
# Dave Ruijter
# https://moderndata.ai
# https://github.com/DaveRuijter/BestPracticeAnalyzerAutomation
# =================================================================================================================================================

# README

# The power of this script is of course in the Best Practice Analyzer that is part of Tabular Editor! 
# This automation is nothing but a fancy orchestrator.
# Please visit https://tabulareditor.com/ and reach out Daniel Otykier and thank him!

# If you want to modify the best-practices rules, or add your own, contribute to the rules on GitHub:
# https://github.com/TabularEditor/BestPracticeRules#contributing. 

# The script loopts the workspaces that the given service principal has the member or admin role membership in (the script installs the PowerShell Power BI management module MicrosoftPowerBIMgmt)
# The script then runs the Best Practice Analyzer on each data model in the workspace (the script downloads the portable version of Tabular Editor to do this).
# The script will output the results of each analysis in the given directory as .trx files, a standard VSTEST result (JSON).
# The script will download and open the Power BI template report of the solution, that will load the .trx files and provides a start to analyze the results.


# Also credits and thanks to https://mnaoumov.wordpress.com/ for the functions to help call the .exe.
# =================================================================================================================================================

# PARAMETERS

# Directories
$OutputDirectory = "C:\PowerBI_BPAA_output"
$TRXFilesOutputSubfolderName = "BPAA_output"

# Download URL for Tabular Editor portable (you can leave this default, or specify another version):
$TabularEditorUrl = "https://github.com/otykier/TabularEditor/releases/download/2.12.2/TabularEditor.Portable.zip"

# URL to the BPA rules file (you can leave this default, or specify another version):
$BestPracticesRulesUrl = "https://raw.githubusercontent.com/TabularEditor/BestPracticeRules/master/BPARules-PowerBI.json"

# Download URL for BPAA Power BI template report (you can leave this default, or specify another version):
$BPAATemplateReportDownloadUrl = "https://github.com/DaveRuijter/BestPracticeAnalyzerAutomation/raw/master/BPAA%20insights.pbit"

# =================================================================================================================================================

# TODO:

# - Check if TE is already installed and available via program files
# - Add option to start/suspend A sku
# - Add option to move workspace to Premium capacity during script execution
# - Add a switch for the BPA results file
# - Add support to specify a local BPA rules file (instead of Url)

# =================================================================================================================================================
# =================================================================================================================================================

function Get-ScriptDirectory {
    #if ($psise) {
    #    Split-Path $psise.CurrentFile.FullPath
    #}
    #else {
    #    $global:PSScriptRoot
    #}
    $OutputDirectory
}

# Couple of functions to help call the .exe
# Author: https://mnaoumov.wordpress.com/
function Invoke-NativeApplication
{
    param
    (
        [ScriptBlock] $ScriptBlock,
        [int[]] $AllowedExitCodes = @(0),
        [switch] $IgnoreExitCode
    )
 
    $backupErrorActionPreference = $ErrorActionPreference
 
    $ErrorActionPreference = "Continue"
    try
    {
        if (Test-CalledFromPrompt)
        {
            $lines = & $ScriptBlock
        }
        else
        {
            $lines = & $ScriptBlock 2>&1
        }
 
        $lines | ForEach-Object -Process `
            {
                $isError = $_ -is [System.Management.Automation.ErrorRecord]
                "$_" | Add-Member -Name IsError -MemberType NoteProperty -Value $isError -PassThru
            }
        if ((-not $IgnoreExitCode) -and ($AllowedExitCodes -notcontains $LASTEXITCODE))
        {
            throw "Execution failed with exit code $LASTEXITCODE"
        }
    }
    finally
    {
        $ErrorActionPreference = $backupErrorActionPreference
    }
}
 
function Test-CalledFromPrompt
{
    (Get-PSCallStack)[-2].Command -eq "prompt"
}

Set-Alias -Name exec -Value Invoke-NativeApplication
# ==================================================================================================================================

$CurrentDateTime = (Get-Date).tostring("yyyyMMdd-HHmmss")

# Start transcript
$Logfile = Join-Path -Path $OutputDirectory -ChildPath "\$CurrentDateTime\BPAA_LogFile.txt"
new-item $(Join-Path -Path $OutputDirectory -ChildPath "\$CurrentDateTime") -itemtype directory -Force | Out-Null
Start-Transcript -Path $Logfile

# ==================================================================================================================================
Clear-Host
$ErrorActionPreference = 'Stop'
Write-Host "
========================================================================
   __  ___         __                 ___         __                 _ 
  /  |/  /___  ___/ /___  ____ ___   / _ \ ___ _ / /_ ___ _   ___ _ (_)
 / /|_/ // _ \/ _  // -_)/ __// _ \ / // // _ '// __// _ '/_ / _ '// / 
/_/  /_/ \___/\_,_/ \__//_/  /_//_//____/ \_,_/ \__/ \_,_/(_)\_,_//_/  
                                                                    
   ___                     ___         _    _  __                      
  / _ \ ___ _ _  __ ___   / _ \ __ __ (_)  (_)/ /_ ___  ____           
 / // // _ '/| |/ // -_) / , _// // // /  / // __// -_)/ __/           
/____/ \_,_/ |___/ \__/ /_/|_| \_,_//_/__/ / \__/ \__//_/              
                                      |___/                            
========================================================================

" -ForegroundColor DarkCyan

Write-Host "=================================================================================================================================="
Write-Host "Best Practice Analyzer Automation starting..." -ForegroundColor DarkCyan

# Service Principal values (you can leave it like this, so it will prompt you for the values during execution):
$PowerBIServicePrincipalClientId = Read-Host -Prompt 'Specify the Application (Client) Id of the Service Principal'
$PowerBIServicePrincipalSecret = Read-Host -Prompt 'Specify the secret of the Service Principal' -AsSecureString
$PowerBIServicePrincipalTenantId = Read-Host -Prompt 'Specify the tenantid of the Service Principal'

Write-Host "=================================================================================================================================="

# Verifying if the PowerShell Power BI management module is installed
Write-Host 'Verifying if the PowerShell Power BI management module is installed...'
if (Get-Module -ListAvailable -Name MicrosoftPowerBIMgmt) {
    Write-Host "MicrosoftPowerBIMgmt already installed."
} 
else {
    try {
        Install-Module -Name MicrosoftPowerBIMgmt -AllowClobber -Confirm:$False -Force  
        Write-Host "MicrosoftPowerBIMgmt installed."
    }
    catch [Exception] {
        $_.message 
        exit
    }
}

Write-Host "=================================================================================================================================="

# Specify download destination of Tabular Editor:
$TabularEditorPortableRootPath = Join-Path -Path $(Get-ScriptDirectory) -ChildPath "\TabularEditorPortable"
new-item $TabularEditorPortableRootPath -itemtype directory -Force | Out-Null
$TabularEditorPortableDownloadDestination = Join-Path -Path $TabularEditorPortableRootPath -ChildPath "\TabularEditor.zip"
$TabularEditorPortableExePath = Join-Path -Path $TabularEditorPortableRootPath -ChildPath "\TabularEditor.exe"

# Download portable version of Tabular Editor from GitHub:
Write-Host 'Downloading the portable version of Tabular Editor from GitHub...'
Invoke-WebRequest -Uri $TabularEditorUrl -OutFile $TabularEditorPortableDownloadDestination

# Unzip Tabular Editor portable, and then delete the zip file:
Expand-Archive -Path $TabularEditorPortableDownloadDestination -DestinationPath $TabularEditorPortableRootPath -Force
Remove-Item $TabularEditorPortableDownloadDestination
Write-Host 'Done.'

# Download BPA rules file
Write-Host 'Downloading the standard Best Practice Rules of Tabular Editor from GitHub...'
$TabularEditorBPARulesPath = Join-Path -Path $TabularEditorPortableRootPath -ChildPath "\BPARules-PowerBI.json"
Invoke-WebRequest -Uri $BestPracticesRulesUrl -OutFile $TabularEditorBPARulesPath
Write-Host 'Done.'

# Specify download destination of the Power BI template report:
$TemplateReportRootPath = Join-Path -Path $(Get-ScriptDirectory) -ChildPath "\"
new-item $TemplateReportRootPath -itemtype directory -Force | Out-Null
$TemplateReportDownloadDestination = Join-Path -Path $TemplateReportRootPath -ChildPath "\BPAA insights.pbit"

# Download BPAA Template report from GitHub:
Write-Host 'Downloading the template Power BI report from GitHub...'
Invoke-WebRequest -Uri $BPAATemplateReportDownloadUrl -OutFile $TemplateReportDownloadDestination

Write-Host "=================================================================================================================================="

# Connect to the Power BI Service
Write-Host 'Creating credential based on Service Principal and connecting to the Power BI Service...'
$credential = New-Object System.Management.Automation.PSCredential($PowerBIServicePrincipalClientId, $PowerBIServicePrincipalSecret)
Connect-PowerBIServiceAccount -ServicePrincipal -Credential $credential -Tenant $PowerBIServicePrincipalTenantId
Write-Host "Done. (details about the environment should be posted above)"

Write-Host "=================================================================================================================================="

# Create a new array to hold the dataset info of all datasets over all workspaces
$biglistofdatasets = [System.Collections.ArrayList]::new()

# Prepare the output directory (it needs to exist)
$OutputDir = Join-Path -Path $OutputDirectory -ChildPath "\$CurrentDateTime"
new-item $OutputDir -itemtype directory -Force | Out-Null # the Out-Null prevents this line of code to output to the host

# Retrieving all workspaces
Write-Host 'Retrieving all Premium Power BI workspaces (that the Service Principal has a membership in)...'
$workspaces = Get-PowerBIWorkspace -All #-Include All -Scope Organization (commented this, I'm getting an 'Unauthorized' for this approach)
if ($workspaces) {
    Write-Host 'Outputting all workspace info to disk...'
    $workspacesOutputPath = Join-Path -Path $OutputDirectory -ChildPath "\$CurrentDateTime\BPAA_workspaces.json"
    $workspaces | ConvertTo-Json -Compress | Out-File -FilePath $workspacesOutputPath

    Write-Host 'Done. Now iterating the workspaces...'
    $workspaces | Where-Object {$_.IsOnDedicatedCapacity -eq $True} | ForEach-Object {
        Write-Host "=================================================================================================================================="
        $workspaceName = $_.Name
        $worskpaceId = $_.Id
        Write-Host "Found Premium workspace: $workspaceName.`n"

        Write-Host "Now retrieving all datasets in the workspace..."
        # Added a filter to skip datasets called "Report Usage Metrics Model"
        $datasets = Get-PowerBIDataset -WorkspaceId $_.Id | Where-Object {$_.Name -ne "Report Usage Metrics Model"}
        $datasets | Add-Member -MemberType NoteProperty -Name "WorkspaceId" -Value $worskpaceId
        $biglistofdatasets += $datasets
        #$datasets
        
        if ($datasets) {
            Write-Host 'Done. Now iterating the datasets...'
            $datasets | ForEach-Object {
                $datasetName = $_.Name
                Write-Host "Found dataset: $datasetName.`n"

                # Prepare the output directory (it needs to exist)
                $DatasetTRXOutputDir = Join-Path -Path $OutputDirectory -ChildPath "\$CurrentDateTime\$TRXFilesOutputSubfolderName\$workspaceName\"
                new-item $DatasetTRXOutputDir -itemtype directory -Force | Out-Null # the Out-Null prevents this line of code to output to the host
                $DatasetTRXOutputPath = Join-Path -Path $DatasetTRXOutputDir -ChildPath "\BPAA - $workspaceName - $datasetName.trx"

                # Call Tabular Editor BPA!
                Write-Host "Performing Best Practice Analyzer on dataset: $datasetName."
                Write-Host "Output will be saved in file: $DatasetTRXOutputPath."
                exec { cmd /c """$TabularEditorPortableExePath"" ""Provider=MSOLAP;Data Source=powerbi://api.powerbi.com/v1.0/myorg/$workspaceName;User ID=app:$PowerBIServicePrincipalClientId@$PowerBIServicePrincipalTenantId;Password=$($credential.getNetworkCredential().password)"" ""$datasetName"" -A ""$TabularEditorBPARulesPath"" -TRX ""$DatasetTRXOutputPath""" } @(0, 1) $True #| Out-Null
            }
        }
        Write-Host "=================================================================================================================================="
    }
    
    Write-Host "Finished on workspace: $workspaceName."
    Write-Host "=================================================================================================================================="
}

Write-Host 'Outputting all metadata of the datasets to disk...'
$datasetsOutputPath = Join-Path -Path $OutputDirectory -ChildPath "\$CurrentDateTime\BPAA_datasets.json"
$biglistofdatasets | ConvertTo-Json -Compress | Out-File -FilePath $datasetsOutputPath

# Open Power BI template file
Write-Host "Open Power BI template file..."
Invoke-Item $TemplateReportDownloadDestination

Write-Host "Script finished."

# Stop tracing
Stop-Transcript