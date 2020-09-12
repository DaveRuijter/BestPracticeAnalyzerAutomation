## This little script helps to retrieve the Object Id that we need to use to add a Service Principal to a Power BI workspace
## Power BI needs the objectID, and it's not visible in the Azure Portal!
## The Object Id show in the Azure Portal is a different Object ID!
## Note: This script uses Azure CLI

# Application ID of the Servie Principal from Azure Portal
$spID = "<insert here>" 

# Get the correct object id of the Service Principal.
$spObjectId = az ad sp show --id $spId --query "{objectId:objectId}" --output tsv

Write-Host "The correct ObjectId is: $spObjectId"