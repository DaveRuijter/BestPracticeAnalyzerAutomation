## This script will add the given user as an admin in all the Premium Power BI workspaces
## It will first ask for the user email
## Then it will ask for the credentials of a Power BI Service Administrator

## IMPORTANT: you need the correct ObjectId of the Service Principal (again, this is not the object id shown in the Azure Portal!)
$UserEmail = Read-Host -Prompt 'Specify the User email'

$permission = 'admin'

Clear-Host

#$credential = (Get-Credential)
Connect-PowerBIServiceAccount

$listofworkspaces = [System.Collections.ArrayList]::new()

Get-PowerBIWorkspace -All -Scope Organization -Include All | Where-Object {$_.IsOnDedicatedCapacity -eq $True -and $_.Type -eq "Workspace"} | ForEach-Object {
  Write-Host "=================================================================================================================================="
  $workspaceName = $_.Name
  $listofworkspaces += $workspaceName
  Write-Host "Found Premium workspace: $workspaceName."
  if ($_.Users | Where-Object {$_.Identifier -eq $UserEmail})
  {
    Write-Host "User already member of: $workspaceName."
  }
  else {
    Write-Host "Adding User to: $workspaceName."
    Add-PowerBIWorkspaceUser -Scope Organization -Id $_.Id -UserPrincipalName $UserEmail -AccessRight $permission
    Write-Host "Done."    
  }
}

Write-Host "=================================================================================================================================="

$listofworkspaces

Write-Host "`nScript finished."