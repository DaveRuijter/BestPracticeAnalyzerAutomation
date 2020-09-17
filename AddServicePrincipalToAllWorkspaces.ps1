## This script will add the given Service Principal as an admin in all the Premium Power BI workspaces
## It will first ask for the correct ObjectId of the Service Principal
## Then it will ask for the credentials of a Power BI Service Administrator

## IMPORTANT: you need the correct ObjectId of the Service Principal
$PowerBIServicePrincipalObjectId = Read-Host -Prompt 'Specify the ObjectId of the Service Principal (you can find this in the "Enterprise applications" screen in Azure Active Directory'

$permission = 'member'

Clear-Host

Connect-PowerBIServiceAccount

$listofworkspaces = [System.Collections.ArrayList]::new()

Get-PowerBIWorkspace -All -Scope Organization -Include All | Where-Object {$_.IsOnDedicatedCapacity -eq $True -and $_.Type -eq "Workspace"} | ForEach-Object {
  Write-Host "=================================================================================================================================="
  $workspaceName = $_.Name
  $listofworkspaces += $workspaceName
  Write-Host "Found Premium workspace: $workspaceName."
  if ($_.Users | Where-Object {$_.Identifier -eq $PowerBIServicePrincipalObjectId})
  {
    Write-Host "Service Principal already member of: $workspaceName."
  }
  else {
    Write-Host "Adding Service Principal to: $workspaceName."
    Add-PowerBIWorkspaceUser -Scope Organization -Id $_.Id -PrincipalType App -Identifier $PowerBIServicePrincipalObjectId -AccessRight $permission
    Write-Host "Done."
  }
}

Write-Host "=================================================================================================================================="

$listofworkspaces

Write-Host "`nScript finished."