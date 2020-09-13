## This script will add the given Service Principal as an admin in all the Power BI workspaces
## THe Power BI cmdlet needs the correct objectID, and that's NOT the one visible in the Azure Portal!

## Tip: You can use a script in the BPAA repo to get the correct objectid: GetCorrectServicePrincipalObjectId.ps1.
## Or, you can paste this code below in the Azure Cloud Shell of the Azure Portal:
## az ad sp show --id "<input your ClientId here>" --query "{objectId:objectId}" --output tsv

# Provide the correct ObjectId of the Service Principal (again, this is not the object id shown in the Azure Portal!)
$PowerBIServicePrincipalObjectId = '<insert here>'

$permission = 'member'

Clear-Host

$credential = (Get-Credential)
Connect-PowerBIServiceAccount -Credential $credential

Get-PowerBIWorkspace -Scope Organization -Include All -All | Where-Object {$_.IsOnDedicatedCapacity -eq $True} | ForEach-Object {
  Write-Host "=================================================================================================================================="
  $workspaceName = $_.Name
  Write-Host "Found Premium workspace: $workspaceName."
  if ($_.Users | Where-Object {$_.Identifier -eq $PowerBIServicePrincipalObjectId})
  {
    Write-Host "Service Principal already member of: $workspaceName."
  }
  else {
    Add-PowerBIWorkspaceUser -Id $_.Id -PrincipalType App -Identifier $PowerBIServicePrincipalObjectId -AccessRight $permission      
  }
}
Write-Host "`nScript finished."
Read-Host -Prompt 'Press enter to close this window...'