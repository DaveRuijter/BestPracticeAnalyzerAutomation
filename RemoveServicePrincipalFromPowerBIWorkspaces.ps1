# =================================================================================================================================================
## This script will remove the given Service Principal from Power BI workspaces
## It will first ask for the (correct) ObjectId of the Service Principal
## Then it will ask for the credentials of a Power BI Service Administrator
# =================================================================================================================================================

## Parameters

# Remove the Service Principal from workspaces that are in Premium capacity?
$RemoveFromPremiumCapacityWorkspaces = $true

# Remove the Service Principal from workspaces that are in shared capacity?
$RemoveFromSharedCapacityWorkspaces = $true

# =================================================================================================================================================
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

"

#IMPORTANT: you need the correct ObjectId of the Service Principal
$PowerBIServicePrincipalObjectId = Read-Host -Prompt 'Specify ObjectId of Service Principal (find this in the "Enterprise applications" in Azure Active Directory)'

if ($PowerBIServicePrincipalObjectId) {
    # Connecting to Power BI (this will prompt for credentials, use an account that has the Power BI admin role!)
    Write-Host "`Connecting to Power BI (this will prompt for credentials, use an account that has the Power BI admin role!)..."
    Connect-PowerBIServiceAccount

    # Keep track of all the workspaces that we 'touch'
    $listofworkspaces = [System.Collections.ArrayList]::new()

    # Get all workspaces (and filter to only v2 workspaces)
    Write-Host "Retrieving workspaces..."
    $AllV2Workspaces = Get-PowerBIWorkspace -All -Scope Organization -Include All | Where-Object { $_.Type -eq "Workspace" -and `
        ( `
            ($_.IsOnDedicatedCapacity -eq $True -and $RemoveFromPremiumCapacityWorkspaces -eq $true) `
            -or ($_.IsOnDedicatedCapacity -eq $False -and $RemoveFromSharedCapacityWorkspaces -eq $true) `
        ) `
        -and $_.Users.Identifier -eq $PowerBIServicePrincipalObjectId `
    }
    Write-Host "=================================================================================================================================="

    # Check if there are workspaces to work with
    if ($AllV2Workspaces)
    {
        Write-Host "Found $($AllV2Workspaces.Count) workspaces..."
        
        # Warn if there are more than 200 workspaces, as this might trigger API thresholds
        if ($AllV2Workspaces.Count -ge 200)
        {
            Write-Warning "Found 200 workspaces or more. This might trigger the thresholds of the Power BI REST API."            
        }

        # Remove the Service Principal from workspaces
        $AllV2Workspaces | ForEach-Object {
            Write-Host "=================================================================================================================================="
            $WorkspaceName = $_.Name
            $WorkspaceId = $_.Id

            Write-Host "Found workspace: $WorkspaceName."

            # Track this workspace
            $listofworkspaces += $WorkspaceName

            # Check if Service Principal is in the workspace
            $ServicePrincipalInWorkspace = $_.Users | Where-Object {$_.Identifier -eq $PowerBIServicePrincipalObjectId}
            if ($ServicePrincipalInWorkspace)
            {
                Write-Host "Service Principal is a member of: $WorkspaceName, with role type $($ServicePrincipalInWorkspace.AccessRight)."
                
                # Remove Service Principal
                Write-Host "Removing Service Principal from workspace..." -ForegroundColor DarkCyan
                
                # Call the REST API (updating a role type is not a native cmdlet in the module)
                try {
                    Invoke-PowerBIRestMethod -Method Delete -Url "admin/groups/$WorkspaceId/users/$PowerBIServicePrincipalObjectId"
                    Write-Host "Done."
                }
                catch {
                    Resolve-PowerBIError -Last
                }
            }
            else {
            Write-Host "Service Principal is not a member of: $WorkspaceName."
            }
        }

        Write-Host "=================================================================================================================================="

        # Report the tracked list of workspaces
        Write-Host "List of workspaces we checked during the script:"
        $listofworkspaces
    }
    else {
        Write-Warning "No workspaces that contain the Service Principal!"
    }
}
else {
  Write-Error "No ObjectId provided for the Service Principal!"
}

Logout-PowerBIServiceAccount
Write-Host "`nScript finished."