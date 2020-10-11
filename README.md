![](https://docs.microsoft.com/en-us/azure/search/media/search-indexer-field-mappings/indexer-stages-field-mappings.png)
# Azure Cognitive Search Automation

Here we attempt to automate from end-to-end the deployment of an [Azure Cognitive Search](https://azure.microsoft.com/en-us/services/search/). The technology of choice to facilitate our automation is [Azure ARM Templates](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/). Unfortunately not everything can be achieved in ARM Templates alone and for these tasks we will be employing [PowerShell & Deployment Scripts](https://moimhossain.com/2020/04/03/azure-ad-app-via-arm-template-deployment-scripts/). For example, much of the Cognitive Search API appears to have no corresponding ARM Template Resources and activities, like assigning users [Azure AD App Role](https://docs.microsoft.com/en-us/powershell/module/azuread/new-azureadserviceapproleassignment?view=azureadps-2.0) permissions, appear to be beyond the reach of ARM Templates <i>(no pun intended)</i>. So in general we will be using ARM Templates to provision Platform Resources and PowerShell + Deployment Scripts to configure them. The motivation for creating this repo was driven by the realization that while individual aspects of this process are well documented no single resource tied them together into one comprehensive automation example and that compositing the disparate resources into a clear picture was not a straightforward task.

## Prerequisites

To begin we will first need to create a user with sufficient privilege to run the PowerShell Deployment Script Resources in our ARM Template. This user is intended to be reused and is created in its own Resources Group. Feel free to delete the user and its Resource Group after the template deployment is complete if you wish. Because of the scope limitations with ARM Templates we will need to rely on PowerShell to perform this task. The following script will create the PowerShell user, assign the user the necessary permissions and output a unique id that you will need to save and provide to the ARM Template. This script creates a [Service Principal and Application Object](https://docs.microsoft.com/en-us/azure/active-directory/develop/app-objects-and-service-principals#application-and-service-principal-relationship) in your [Azure AD Tenant](https://docs.microsoft.com/en-us/microsoft-365/enterprise/subscriptions-licenses-accounts-and-tenants-for-microsoft-cloud-offerings?view=o365-worldwide) with [<i>Application.ReadWrite.OwnedBy</i>](https://docs.microsoft.com/en-us/graph/permissions-reference) permissions.

<blockquote>
<i>Application.ReadWrite.OwnedBy Allows the calling app to create other applications and service principals, and fully manage those applications and service principals (read, update, update application secrets and delete), without a signed-in user. It cannot update any applications that it is not an owner of. Does not allow management of consent grants or application assignments to users or groups.</i>
</blockquote>

```powershell
.\Prerequisites\grant-permission.ps1
```

## ARM Template Deployment
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/)

From here the ARM Template does the following work:
- Provisions a [Microsoft.Resources/resourceGroups](https://docs.microsoft.com/en-us/azure/templates/microsoft.resources/2018-05-01/resourcegroups) with a CanNotDelete [Microsoft.Authorization/locks](https://docs.microsoft.com/en-us/azure/templates/microsoft.authorization/locks).
- Provisions a [Microsoft.ManagedIdentity/userAssignedIdentities](https://docs.microsoft.com/en-us/azure/templates/microsoft.managedidentity/2018-11-30/userassignedidentities) with permission to perform maintenance tasks within the Resource Group 
- Provisions a [Microsoft.Authorization/roleAssignments](https://docs.microsoft.com/en-us/azure/templates/microsoft.authorization/2018-09-01-preview/roleassignments) using [Microsoft.Authorization/roleDefinitions](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles) to grant our PowerShell User the [Azure Owner built-in role](https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#owner) on the Resource Group
- Provisions a single shared [Microsoft.Storage/storageAccounts](https://docs.microsoft.com/en-us/azure/templates/microsoft.storage/storageaccounts) (Non-Public) with a dedicated [blobServices/containers](https://docs.microsoft.com/en-us/azure/templates/microsoft.storage/2018-07-01/storageaccounts/blobservices/containers) to store blobs for the following Resources:
    - [Azure Web Job Storage](https://github.com/Azure/azure-webjobs-sdk/wiki)
    - [Azure Dashboard Storage](https://docs.microsoft.com/en-us/azure/azure-functions/functions-app-settings)
    - [Azure Website Content Storage](https://docs.microsoft.com/en-us/azure/azure-functions/functions-app-settings)
    - [Deployment Script Storage](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/deployment-script-template?tabs=CLI)
    - [Datasource for Azure Cognitive Search](https://docs.microsoft.com/en-us/azure/search/search-howto-indexing-azure-blob-storage)
- Provisions a [Microsoft.Search/searchServices](https://docs.microsoft.com/en-us/azure/templates/microsoft.search/searchservices)
- Provisions a [Microsoft.CognitiveServices/accounts](https://docs.microsoft.com/en-us/azure/templates/microsoft.cognitiveservices/2017-04-18/accounts)
- Provisions a [Microsoft.Web/serverfarms](https://docs.microsoft.com/en-us/azure/templates/microsoft.web/2018-02-01/serverfarms) App Service Plan
- Provisions a [Microsoft.Web/sites](https://docs.microsoft.com/en-us/azure/templates/microsoft.web/sites) (currently unused) and [Microsoft.Web/sites/functions](https://docs.microsoft.com/en-us/azure/templates/microsoft.web/2018-02-01/sites/functions)
- [Microsoft.Web/sites/sourcecontrols](https://docs.microsoft.com/en-us/azure/templates/microsoft.web/2018-02-01/sites/sourcecontrols) to deploy the [Azure Function App](https://docs.microsoft.com/en-us/azure/azure-functions/functions-infrastructure-as-code#app-service-plan) from [GitHub](https://github.com/davideker/azureskills).
- Provisions [Microsoft.Resources/deploymentScripts](https://docs.microsoft.com/en-us/azure/templates/microsoft.resources/deploymentscripts) that:
    - Configures an [Index](https://docs.microsoft.com/en-us/rest/api/searchservice/create-index) in the Azure Cognitive Search Service
    - Configures a [Skillset](https://docs.microsoft.com/en-us/azure/search/cognitive-search-defining-skillset) leveraging [built-in skills](https://docs.microsoft.com/en-us/azure/search/cognitive-search-predefined-skills)
    - Configures the [Cognitive Services](https://docs.microsoft.com/en-us/azure/search/cognitive-search-attach-cognitive-services) for the Azure Cognitive Search 
    - Configures a  [Custom Skill](https://docs.microsoft.com/en-us/azure/search/cognitive-search-create-custom-skill-example)
    - Configures an [Indexer](https://docs.microsoft.com/en-us/rest/api/searchservice/create-indexer)


<img src="https://docs.microsoft.com/en-us/azure/search/media/knowledge-store-concept-intro/knowledge-store-concept-intro.svg" alt="drawing" style="width:800px;"/>


## Caveats

The Resources provisioned in this ARM Template are meant to illustrate how the Cognitive Search Service is composed and to provide a testing ground for Custom Skills. It is not production ready. It relies on Free Tier resources and as a result the index it creates is not configured for large scale indexing. Additionally, as configured, it is strictly intended to be used to index [PDF documents](https://docs.microsoft.com/en-us/azure/search/cognitive-search-concept-image-scenarios), though with some minor changes it can be adapted to index any kind of [document supported](https://docs.microsoft.com/en-us/azure/search/search-blob-storage-integration) by the Cognitive Search Service.

## Considerations

- [Improving Azure Function security posture](https://docs.microsoft.com/en-us/azure/azure-functions/security-concepts)
- [Configuring the Index for scalability](https://docs.microsoft.com/en-us/azure/search/search-capacity-planning)
- [Configuring the Indexer for different document types](https://docs.microsoft.com/en-us/azure/search/search-howto-indexing-azure-blob-storage) 
- [Scheduling the Indexer](https://docs.microsoft.com/en-us/azure/search/search-howto-schedule-indexers) 
- [Adding a Knowledge Store](https://docs.microsoft.com/en-us/azure/search/cognitive-search-working-with-skillsets#:~:text=knowledge%20store)