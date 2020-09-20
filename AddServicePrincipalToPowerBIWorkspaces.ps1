# =================================================================================================================================================
## This script will add the given Service Principal to Power BI workspaces
## It will first ask for the (correct) ObjectId of the Service Principal
## Then it will ask for the credentials of a Power BI Service Administrator

## Note: this script only works with v2 workspaces (you can't add a Service Principal to a v1 workspace)
# =================================================================================================================================================

## Parameters

# The role to give the Service Principal in the workspaces (admin, member, contributor)
$RoleType = 'member'

# If the Service Principal is already a member of the workspace, 
# do you want to force the role to be as state in the $RoleType parameter above?
$ForceRole = $True

# Add the Service Principal to workspaces that are in Premium capacity?
$AddToPremiumCapacityWorkspaces = $true

# Add the Service Principal to workspaces that are in shared capacity?
$AddToSharedCapacityWorkspaces = $true

# =================================================================================================================================================

$ErrorActionPreference = 'Stop'
Clear-Host

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
========================================================================"

#IMPORTANT: you need the correct ObjectId of the Service Principal
$PowerBIServicePrincipalObjectId = Read-Host -Prompt 'Specify ObjectId of Service Principal (find this in the "Enterprise applications" in Azure Active Directory)'

if ($PowerBIServicePrincipalObjectId) {
  # Connect to Power BI (this will prompt for credentials, use an account that has the Power BI admin role!)
  Connect-PowerBIServiceAccount

  # Keep track of all the workspaces that we 'touch'
  $listofworkspaces = [System.Collections.ArrayList]::new()

  Write-Host "=================================================================================================================================="

  # Get all workspaces (and filter to only v2 workspaces)
  $AllV2Workspaces = Get-PowerBIWorkspace -All -Scope Organization -Include All | `
    Where-Object {$_.Type -eq "Workspace" -and $_.State -ne "Deleted" -and $_.IsReadOnly -eq $False `
    -and ( `
      ($_.IsOnDedicatedCapacity -eq $True -and $AddToPremiumCapacityWorkspaces -eq $true) `
      -or `
      ($_.IsOnDedicatedCapacity -eq $False -and $AddToSharedCapacityWorkspaces -eq $true) `
    ) `
  }
  Write-Host "Found a total of $($AllV2Workspaces.Count) workspaces..."

  # Add the Service Principal to the workspaces
  $AllV2Workspaces | ForEach-Object {
    Write-Host "=================================================================================================================================="
    $WorkspaceName = $_.Name
    $WorkspaceId = $_.Id

    Write-Host "Working on workspace: $WorkspaceName."

    # Track this workspace
    $listofworkspaces += $WorkspaceName

    # Check if Service Principal is in the workspace
    $ServicePrincipalInWorkspace = $_.Users | Where-Object {$_.Identifier -eq $PowerBIServicePrincipalObjectId}
    if ($ServicePrincipalInWorkspace)
    {
      Write-Host "Service Principal already member of: $WorkspaceName, with role type $($ServicePrincipalInWorkspace.AccessRight)."
      
      # Check current role type
      if ($ServicePrincipalInWorkspace.AccessRight -ne $RoleType) {
        # If foce is enabled, overrule the current role type
        if ($ForceRole) {
          Write-Host "Updating role type (force is inabled)."
            
          # Remove Service Principal
          Write-Host "Remove Service Principal from workspace..."
          Remove-PowerBIWorkspaceUser -Scope Organization -Id $WorkspaceId -PrincipalType App -Identifier $PowerBIServicePrincipalObjectId

          # Adding Service Principal
          Write-Host "Adding Service Principal to: $WorkspaceName, with correct role type..."
          Add-PowerBIWorkspaceUser -Scope Organization -Id $WorkspaceId -PrincipalType App -Identifier $PowerBIServicePrincipalObjectId -AccessRight $RoleType
          Write-Host "Done."
        }
        else {
          Write-Warning "Force update is not enabled, not updating this role membership!"
        }
      }
    }
    else {
      Write-Host "Adding Service Principal to: $WorkspaceName."
      Add-PowerBIWorkspaceUser -Scope Organization -Id $WorkspaceId -PrincipalType App -Identifier $PowerBIServicePrincipalObjectId -AccessRight $RoleType
      Write-Host "Done."
    }
  }

  Write-Host "=================================================================================================================================="

  # Report the tracked list of workspaces
  Write-Host "List of workspaces that we checked during the script:"
  $listofworkspaces
}
else {
  Write-Error "No ObjectId provided for the Service Principal!"  
}

Logout-PowerBIServiceAccount
Write-Host "`nScript finished."