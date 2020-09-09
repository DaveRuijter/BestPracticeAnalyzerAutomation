# =================================================================================================================================================
# Best Practice Analyzer Automation (BPAA)
# Version 0.01
# 
# Dave Ruijter
# https://moderndata.ai/
# =================================================================================================================================================

# README

# The power of this script is of course in the Best Practice Analyzer that is part of Tabular Editor! 
# This automation is nothing but a fancy orchestrator.
# Please visit https://tabulareditor.com/ and reach out Daniel Otykier and thank him!

# If you want to modify the best-practices rules, or add your own, contribute to the rules on GitHub:
# https://github.com/TabularEditor/BestPracticeRules#contributing. 

# The script loopts the workspaces that the given service principal has the admin role membership in.
# The script will output the results of each analysis in the given directory as .trx files, a standard VSTEST result (JSON).
# The script downloads the portable version of Tabular Editor to a new folder called TabularEditorPortable in the directory of this .ps1.
# The script installs the PowerShell Power BI management module (MicrosoftPowerBIMgmt).


# Also credits and thanks to https://mnaoumov.wordpress.com/ for the functions to help call the .exe.
# =================================================================================================================================================

# PARAMETERS

# Name of the folder to contain the .trx files (standard VSTEST results)
# This folder wil be created in the same directory as this script.
# Note: each Power BI workspace will get its own subfolder within this $TRXOutputFolder.
$TRXOutputFolder = "BPAA_output"

# Download URL for Tabular Editor portable (you can leave this default, or specify another version):
$TabularEditorUrl = "https://github.com/otykier/TabularEditor/releases/download/2.12.2/TabularEditor.Portable.zip"

# URL to the BPA rules file
$BestPracticesRulesUrl = "https://raw.githubusercontent.com/TabularEditor/BestPracticeRules/master/BPARules-PowerBI.json"

# TenantId of the Power BI Service
# (required to use the Service Principal)
# By default it will prompt for the TenantId, but you can hard-code it if you want by uncommenting the other line of code
$PowerBIServicePrincipalTenantId = Read-Host -Prompt 'Specify the tenantid of the Service Principal'
#$PowerBIServicePrincipalTenantId = "680c2e2d-0ad8-4d66-a0ae-ebaf8dc134bd"

# =================================================================================================================================================

# TODO:

# - mention that only a service principal approach is supported now
# - Check if TE is already installed and available via program files
# - Add credential prompt as default
# - Add option to start/suspend A sku
# - Add option to move workspace to Premium capacity during script execution
# - Add a switch for the BPA results file
# - Add logic to add the service principal in all workspaces in the Power BI Service
# - Add support to specify a local BPA rules file (instead of Url)

# =================================================================================================================================================
# =================================================================================================================================================

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

Clear-Host

# Verifying if the PowerShell Power BI management module is installed
Write-Host "=================================================================================================================================="
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

function Get-ScriptDirectory {
    if ($psise) {
        Split-Path $psise.CurrentFile.FullPath
    }
    else {
        $global:PSScriptRoot
    }
}

# Download destination (root of PowerShell script execution path):
$TabularEditorPortableRootPath = Join-Path -Path $(Get-ScriptDirectory) -ChildPath "\TabularEditorPortable"
new-item $TabularEditorPortableRootPath -itemtype directory -Force | Out-Null
$TabularEditorPortableDownloadDestination = Join-Path -Path $TabularEditorPortableRootPath -ChildPath "\TabularEditor.zip"
$TabularEditorPortableExePath = Join-Path -Path $TabularEditorPortableRootPath -ChildPath "\TabularEditor.exe"

Write-Host "=================================================================================================================================="

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
Invoke-WebRequest -Uri $BestPracticesRules -OutFile $TabularEditorBPARulesPath
Write-Host 'Done.'

Write-Host "=================================================================================================================================="

# Connect to the Power BI Service
Write-Host "Connecting to the Power BI Service..."
$credential = (Get-Credential)
Connect-PowerBIServiceAccount -ServicePrincipal -Credential $credential -TenantId $PowerBIServicePrincipalTenantId
Write-Host "Done. (details about the environment should be posted above)"

Write-Host "=================================================================================================================================="

# Retrieving all Power BI workspaces (that the Service Principal has the admin role membership in)...
Write-Host 'Retrieving all Premium Power BI workspaces (that the Service Principal has the admin role membership in)...'
Get-PowerBIWorkspace -All | Where-Object {$_.IsOnDedicatedCapacity -eq $True} | ForEach-Object {
    Write-Host "=================================================================================================================================="
    $workspaceName = $_.Name
    Write-Host "Found Premium workspace: $workspaceName."
    Write-Host "Retrieving all datasets in the workspace."
    Get-PowerBIDataset -WorkspaceId $_.Id | ForEach-Object {
        $datasetName = $_.Name
        Write-Host "Found Premium dataset: $datasetName."

        # Prepare the output directory (it needs to exist)
        $DatasetTRXOutputDir = Join-Path -Path $(Get-ScriptDirectory) -ChildPath "\$TRXOutputFolder\$workspaceName\"
        new-item $DatasetTRXOutputDir -itemtype directory -Force | Out-Null # the Out-Null prevents this line of code to output to the host
        $DatasetTRXOutputPath = Join-Path -Path $DatasetTRXOutputDir -ChildPath "\BPAA - $workspaceName - $datasetName.trx"

        # Call Tabular Editor!
        Write-Host "Performing Best Practices Analyzer on dataset: $datasetName."
        Write-Host "Output will be saved in file: $DatasetTRXOutputPath."
        exec { cmd /c """$TabularEditorPortableExePath"" ""Provider=MSOLAP;Data Source=powerbi://api.powerbi.com/v1.0/myorg/$workspaceName;User ID=app:$($credential.getNetworkCredential().username)@$PowerBIServicePrincipalTenantId;Password=$($credential.getNetworkCredential().password)"" ""$datasetName"" -A ""$TabularEditorBPARulesPath"" -TRX ""$DatasetTRXOutputPath""" } @(1)
        Write-Host "=================================================================================================================================="
    }
    Write-Host "Finished on workspace: $workspaceName."
    Write-Host "=================================================================================================================================="
}
Write-Host "Script finished."