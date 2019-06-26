# Azure Stack lab - Day 2: Application platforms
During second day we will practice:
- Using Application Services (PaaS) to deploy and manage applications
- Using serverless in Azure Stack
- Deploying Kubernetes
- Kubernetes basics
- Deploying advanced AI/ML services in Kubernetes
- Creating custom marketplace items

## Prerequisities
Check [README](./README.md)

## Step 1 - create and scale WebApp using PaaS and use Deployment Slots to manage versions
Usign GUI create Web App named (yourname)-app1 on new Service Plan on Production tier S1. Open Web App page and click on URL - you should see dafult page of your future application.

Go to App Service Editor (Preview) and in WWWROOT folder use right click to create file index.html with "My great app" inthere. Refresh URL of your application - you should see you static web up and running.

Let's now see how you can create additional environments and easily test and release new versions of your application. Go to Deployment slots and click Add Slot. Call it "test" and Do not clone settings.

Click on new slot and go to App Service Editor (Preview) and create index.html with content "New version of my great app".

In Overview section find URL of your test version and open it. You next-version application is running fine.

Go back to deployment slots and configure 20% of users to hit test version and click Save. Now 20% of users will go to new version. In order for single user to not switch randomly platform uses cookie-based session persistence and browser is holding it. In order to test probability of hitting new version use PowerShell command to access page as it ignores cookies by default:

```powershell
Invoke-WebRequest https://tomas-app1.appservice.local.azurestack.external/
```

Try multiple times and you should see about 20% of responses comming from new version.

After sime time we feel confident with new version, let's swap the slots and release to production. What was test before will become production and previous production will be in test (so you can easily switch back if something goes wrong). Go to Deploment Slots and select Swap. After operation is complete you should see only new version.

You application is now very popular and you need more performance to handle load. Add additional application node by going to Scale out (App Service plan) and increase number to 2. There are now additional steps required, after couple of minutes you have dobled your performance. You also scale back to 1 and because reverse proxy which is part of PaaS holds connections there should be no impact on availability. 

## Step 2 - use developer tooling to integrate Azure Stack with your development environment or CI/CD pipeline

Open Visual Studio 2019 and create new project. Select ASP.NET Core Web Application template and type Web Application (Model-View-Controller).

Hit F5 to compile and run you app locally. If page loads, close your browser.

In right top corner ther is Sign In buttot - sign as AAD user.

In Solution Explorer right click on application name (right under Solution myapp) and select Publish. Use App Service and choose Creat New. You will list of all your subscriptions in both Azure and Azure Stack. Select correct one and find your existing App Service Plan. Click Create and wait for your application to be deployed. Browser will open automatically pointing to your Web App hosted in Azure Stack PaaS.

There are much more integrations available for Developers and DevOps Teams:
* You can deploy and manage additional components in Azure Stack including VMs, Storage accounts or Azure Functions
* You can use remote debugging
* You can deploy to Kubernetes in Azure Stack including automatic Docker container creation, publish to Azure Container Registry etc.
* You can use .NET Framework, .NET Core, Java, Node.JS and other languages
* Open source platform Visual Studio Code also supports similar features
* You can integrate Azure Stack PaaS into DevOps orchestration and CI/CD tool Azure DevOps
* There are integrations to 3rd patry tools such as Eclipse or Jenkins
* Azure Stack supports automation with tools like Terraform or Ansible

## Step 3 - enable application monitoring with Application Insights in Azure
We will now add SDK to monitor application in Azure Application Insights. Applications in Azure Stack can be deeply monitored using Azure public cloud tools. Right click on app name in Solution Explorer, click Add and Application Insights Telemetry. Click on Configure settings to select your own resource group name and use West Europe region. Wizard will automatically find your Azure subscription and will create Application Insights and build connections to it to your application after you clic Register.

Right click on app name and Publish changes to Azure Stack.

After application opens generate some events by clicking on some tabs on top.

Open Application Insights in Azure and try the following:
* Open Live Stream tab and click on some tabs to see realtime data
* Check Application Map
* Open Search to see some events
* Check Performance section
* Investigate Usage section including Users, Sessions and User Flows

## Step 4 - use serverless to expose API endpoint and store messages in Queue
We will create new Function App (serverless) via GUI. We can use Consumption hosting plan (running in shared plan), but as we already purchased App Service plan dedicated, let's run it there. Use .NET as language and let wizard create storage account.

When environment is ready open it and click on + sign in Functions. Use wizard to select Webhook + API. There is sample code (you do not have to understand it at this point) that takes name as argument and responds with Hello (name). Use Get function URL and copy it to clipboard. Open web browser and paste it in and add "&name=Tomas". Full URL might look something like this:

```
https://mojefunkce.appservice.local.azurestack.external/api/HttpTriggerCSharp1?code=aoBmARujcdaoUgaLIApy8KQOs1QzskpuDmIoKB7BtjV0KP5x/SM5Pg==&name=Tomas
```

This is our first working serverless function. No server to manage, no framework, no need to compile code.

We will now want to create message in queue. There is PaaS service for that which is part of Storage account. We will reuse one already created for our Function. Note that in standard code you would need to authenticate against it and solve how to pass token etc. This will be handled by serverless platform, so we do not have to worry about that. Click on Integrate and + New Output. Select Azure Queue Storage and click Select. On next page we can modify names, but let's keep everything on defaults and click Save.

Go back to HttpTriggerCSharp1 to open code. We will make simple modification to output name to queue. Replace existing code with this one:

```
using System.Net;

public static async Task<HttpResponseMessage> Run(HttpRequestMessage req, TraceWriter log, ICollector<string> outputQueueItem)
{
    log.Info("C# HTTP trigger function processed a request.");

    // parse query parameter
    string name = req.GetQueryNameValuePairs()
        .FirstOrDefault(q => string.Compare(q.Key, "name", true) == 0)
        .Value;

    if (name == null)
    {
        // Get request body
        dynamic data = await req.Content.ReadAsAsync<object>();
        name = data?.name;
    }

    outputQueueItem.Add("Name passed to the function: " + name);

    return name == null
        ? req.CreateResponse(HttpStatusCode.BadRequest, "Please pass a name on the query string or in the request body")
        : req.CreateResponse(HttpStatusCode.OK, "Hello " + name);
}
```

Generate some call as before via browser. Open your Storage Account, go to Queues and you should see messages there.

## Step 5 - use serverless to react on message in Queue and create file in Blob storage
So far we have use HTTP call as trigger and sent output to Queue. We can also run TImer trigger or data related triggers run running code whenever there is new file in blob storage (eg. to run code to resize JPG) or react on message in queue. That is what we will try now.

On Functions click on + sign and this time select Create your own function to select Queue Trigger using C# (click on C# in that box). As queue name type outqueue and click Save. There is sample code that will get message and write to log. Let's test it. Click on logs and keep Window open. You will probably see logs of existing messages being consumed. Go to browser and call our first function again. That will trigger first function that writes message to queue and new message will trigger our second function.

Go to Integrate and click + New Output and this time select Azure Blob Storage, keep everything on defaults and click Save. Replace existing code with this one:

```
using System;

public static void Run(string myQueueItem, TraceWriter log, out string outputBlob)
{
    log.Info($"C# Queue trigger function processed: {myQueueItem}");
    outputBlob = myQueueItem;
}
```

Generate new request for first function via browser. Open Storage Account, go to Blobs and you should see new file stored in outcontainer.

Think about interesting scenarios with Azure Functions:
* Wait for new JPG to be stored in Blob storage and resize to multiple sizes for different screens
* Get requests from application and store in queue, so application can continue on other tasks. Have queue trigger to run background task to process message (eg. create order etc.)
* Upload CSV files to Blob storage and have it trigger Function to process CSV and store in database or do filtering.
* Have IoT sensor messages come to queue (or in future Event Hub) and use Function to process messages (parsing, conversion etc.)
* Think about hybrid scenarios - for example you can collect messages in Azure Stack and trigger function to filter interesting events and send them to Azure Blob Storage for advanced processing in public cloud. Or you can user public cloud Azure to build IoT platform and use Functions in public cloud to process RAW data, but send converted data to Azure Stack Queue, where you trigger Azure Stack Functions to process it and store in local database in Azure Stack.

## Step 6 - Create Kubernetes cluster and connect

## Step 7 - Create your first Pod

## Step 8 - Use Azure Container Registry to store and build images

## Step 9 - Use Deployment and Service to deploy and scale application

