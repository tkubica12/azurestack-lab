# Azure Stack lab - Day 2: Application platforms
During second day we will practice:
- Using Application Services (PaaS) to deploy and manage applications
- Using serverless in Azure Stack
- Deploying Kubernetes
- Kubernetes basics
- Deploying advanced AI/ML services in Kubernetes

## Prerequisities
Check [README](./README.md)

## Step 1 - create and scale WebApp using PaaS and use Deployment Slots to manage versions
Usign GUI create Web App named (yourname)-app1 on new Service Plan on Production tier S1. Open Web App page and click on URL - you should see dafult page of your future application.

Go to App Service Editor (Preview) and in WWWROOT folder use right click to create file index.html with "My great app" inthere. Refresh URL of your application - you should see you static web up and running.

Let's now see how you can create additional environments and easily test and release new versions of your application. Go to Deployment slots and click Add Slot. Call it "test" and Do not clone settings.

Click on new slot and go to App Service Editor (Preview) and create index.html with content "New version of my great app".

In Overview section find URL of your test version and open it. You next-version application is running fine.

Go back to deployment slots and configure 20% of users to hit test version and click Save. Now 20% of users will go to new version. In order for single user to not switch randomly platform 2q cookie-based session persistence and browser is holding it. In order to test probability of hitting new version use PowerShell command to access page as it ignores cookies by default:

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

## Step 6 - create Kubernetes cluster and connect
Kubernetes needs access to your Azure environment in order to install cluster and enable Kubernetes to create resources for your applications such as laod balancer rules or disks. Therefore we need to have Service Principal account in Active Directory. 

You should have account ready for this lab. If not create new one and note your application id. [https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal#create-an-azure-active-directory-application](https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal#create-an-azure-active-directory-application)

We need secret for this account - generate it. [https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal#create-a-new-application-secret](https://docs.microsoft.com/en-us/azure/active-directory/develop/howto-create-service-principal-portal#create-a-new-application-secret)

Give this account RBAC authorization for your subscription (Resource Group would be enough, but let's keep it simple). Go to subscriptions, Access Control (IAM) and add your Service Principal account as Contributor.

Next we need to generate SSH keys. You can use [https://www.puttygen.com/](https://www.puttygen.com/). Make sure you store your private key and public key.

Go to Azure Stack portal and run Kubernetes wizard. We will create non-HA cluster with one master node and for worker nodes use 2 nodes. Enter your service principal (application id), secret and also paste your public SSH key.

Now we have some time to learn Kubernetes basics. Instructor will go throw [presentation in Czech](https://github.com/tkubica12/kubernetes-demo/raw/master/PPT-CZ/Kubernetes%20-%20jak%20funguje.pptx)

When cluster is created we will need to grap connection details from master node and copy it to your notebook so we can connect to Kubernetes from it. Use [WinSCP](https://winscp.net/eng/download.php) and point it public IP of your master node and specify default username which is azureuser. Connect.

In panel with /home/azureuser folder press CTRL+ALT+h to see hidden files. There is .kube directory with config file. Copy full .kube folder to your C:\Users\yourusername. You should have C:\Users\yourusername\.kube\config file on your PC.

To work with Kubernetes cluster we will use kubectl.exe. [Download](https://storage.googleapis.com/kubernetes-release/release/v1.15.0/bin/windows/amd64/kubectl.exe) it to some folder which is in our PATH.

Make sure you can connect to cluster:

```powershell
kubectl get nodes
```

In your Visual Studio Code install Kubernetes extension. New icon should appear and you should be able to see your cluster there.

## Step 7 - create your first Pod
Kubernetes files are stored in kubernetes folder.

Deploy Pod

```powershell
kubectl apply -f podApp.yaml
```

We can list running Pods. With -w we can stream changes od Pod status so you might see status changing from ContainerCreating to Running etc.

```powershell
kubectl get pods -w
```

If something goes wrong check more details about Pod including log of state changes.

```powershell
kubectl describe pod todo
```

Note that you can also get logs via kubectl (use -f for streaming).

```powershell
kubectl logs todo
```

Pod is not exposed to outside of our cluster (we will do that later), but we can use kubectl to create encrypted tunnel for troubleshooting. Create port-forwarding and open browser on http://localhost:54321/api/version

```powershell
kubectl port-forward pod/todo 54321:80
```

Pod is basic unit of deployment and by itself it does not provide additional functionality such as redeploying Pod if something goes wrong (such as node going down). We can see that by deleting Pod. It will just die and no other Pod will be deployed as replacement.

```powershell
kubectl delete pod todo
kubectl get pods -w
```

## Step 8 - using Deployment controller
Rather that using Pod directly let's create Deployment object. Controller than creates ReplicaSet and making sure that desired number of Pods is always running. There are few more configurations we have added as best practice that we are going to need later in lab:

```powershell
kubectl apply -f deploymentApp1replica.yaml
kubectl get deploy,rs,pods
```

We will now kill our Pod and see how Kubernetes will make sure our environment is consistent with desired state (which means create Pod again). 

```powershell
kubectl delete pod todo-54bb8c6b7c-p9n6v    # replace with your Pod name
kubectl get pods
```

Scale our deployment to 3 replicas.

```powershell
kubectl apply -f deploymentApp3replicas.yaml
kubectl get deploy,rs,pods
kubectl get pods -o wide
```

Now let's play a little bit with labels. There are few ways how you can print it on output or filter by label. Try it out.

```powershell
# print all labels
kubectl get pods --show-labels    

# filter by label
kubectl get pods -l app=todo

# add label column
kubectl get pods -L app
```

Note kthat the way how ReplicaSet (created by Deployment) is checking whether environment comply with desired state is by looking at labels. Look for Selector in output.

```powershell
kubectl get rs
kubectl describe rs todo-54bb8c6b7c   # put your actual rs name here
```

Suppose now that one of your Pods behaves strangely. You want to get it out, but not kill it, so you can do some more troubleshooting. We can edit Pod and change its label app: todo to something else such as app: todoisolated. What you expect to happen?

```powershell
kubectl edit pod todo-54bb8c6b7c-xr98s    # change to your Pod name
kubectl get pods --show-labels
```

What happened? As we have changed label ReplicaSet controller no longer see 3 instances with desired labels, just 2. Therefore it created one additional instance. What will happen if you change label back to its original value?

```powershell
kubectl edit pod todo-54bb8c6b7c-xr98s    # change to your Pod name
kubectl get pods --show-labels
```

Kubernetes have killed one of your Pods. Now we have 4 instances, but desired state is 3, so controller removed one of those.

## Step 9 - expose application via Service
Kubernetes includes internal load balancer and service discovery called Service. This creates internal virtual IP address (cluster IP), load balancing rules are DNS records in internal DNS service. In order to get access to Service from outside AKS has implemented driver for type: LoadBalancer which calls Azure and deploy rules to Azure Load Balancer. By default it will create externally accessible public IP, but can be also configured for internal LB (for apps that should be accessible only within VNET or via VPN).

Let's create one. Note "selector". That is way how Service identifies Pods to send traffic to. We have intentionaly included labels app and component, but not type (you will see why later in lab).

```powershell
kubectl apply -f serviceApp.yaml
kubectl get service
```

Note that external IP can be in pending state for some time until Azure configures everything.

While we wait we will test service internally. Create Pod with Ubuntu, connect to it and test internal DNS name and connectivity.

```powershell
kubectl apply -f podUbuntu.yaml
```

For troubleshooting you can exec into container and run some commands there or even jump using interactive mode to shell. Note this is just for troubleshooting - you should never change anything inside running containers this way. Always build new container image or modify external configuration (we will come to this later) rather than doing things inside.

Jump into container and try access to service using DNS record.

```powershell
kubectl exec -ti ubuntu -- /bin/bash
curl todo-app/api/version
```

Azure Stack has by now allocated public IP to deployed Service. You can get it via kubectl get services. When using scripts we can use jsonpath for direct parsing.

```powershell
$extPublicIP = $(kubectl get service todo-app -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
Invoke-RestMethod $extPublicIP/api/version -DisableKeepAlive
```

## Step 10 - rolling upgrade
Kubernetes Deployment support rolling upgrade to newer container images. If you change image in desired state (typically you change tag to roll to new version of your app). Deployment will create new ReplicaSet with new version and orchestrate rolling upgrade. It will add new version Pod and when it is fully up it removes one with older version and so until original ReplicaSet is on size 0. Since tags we used for Service identification are the same for both we will not experience any downtime.

In one window start curl in loop.

```powershell
$url = "$(kubectl get service todo-app -o jsonpath='{.status.loadBalancer.ingress[0].ip}')/api/version"
while($true) {Invoke-RestMethod $url -DisableKeepAlive}
```

Focus on version which is on end of string. No in different window deploy new version of Deploment with different image tag and see what is going on.

```powershell
kubectl apply -f deploymentAppV2.yaml
```

## Step 11 - Using MS SQL in Linux-based Docker container in Kubernetes
First we will need to securely store database sa account password and connection string. We will use Kubernetes Secret for that.

```powershell
kubectl create secret generic db `
    --from-literal=password=Azure12345678 `
    --from-literal=connectionString="Server=tcp:sql,1433;Initial Catalog=todo;Persist Security Info=False;User ID=sa;Password=Azure12345678;MultipleActiveResultSets=False;Encrypt=False;TrustServerCertificate=False;Connection Timeout=30;"
```

Until this point we have not connected our todo app with SQL database. We have monitored health of /api/version, but now we want to check app is working and connected to DB (we will poll / as health probe as app returns 503 if DB is not connected). Also we need to pass DB connection string as environmental variable from stored Secret.

```powershell
kubectl apply -f deploymentAppFull.yaml
```

Note rolling upgrade is halted. Why? We do not have DB ready yet so liveness probe if failing and Kubernetes keeps restarting our application. Because Pod is not healthy, rolling upgrade does not continue. This is fine - we will deploy SQL, Pod will eventualy get access to it, probe will succeed and Deployment will advance with other Pods.

For purpose of this training we will deploy non-HA SQL (good for testing). For running AlwaysOn SQL clusters on Kubernetes you may use Kubernetes SQL Operator: [https://docs.microsoft.com/en-us/sql/linux/sql-server-ag-kubernetes?view=sqlallproducts-allversions](https://docs.microsoft.com/en-us/sql/linux/sql-server-ag-kubernetes?view=sqlallproducts-allversions)

sql.yaml consists of Persistent Volume Claim backed by Azure Disk, Deployment with single instance SQL and Service to provide DNS discovery and virtual endpoint.

```powershell
kubectl apply -f sql.yaml
kubectl get pvc,pod
```

Access your todo application - it should work now. Add some todo and it will be written to SQL.

We can now attempt to kill sql pod.

```powershell
kubectl delete pod sql-78b549bdf7-wcbg6   # Use your sql pod name
```

Todo application will return error for some time, but Pod will be recreated and todo will start to work again. Note this is not full HA solution:
* If Pod fails, but Node is still available, recovery is pretty fast (Kubernetes create new SQL Pod and point to the same Volume)
* Should Node fail Kubernetes will run Pod on different Node, but it can take about 5 minutes for Volume to get attached to new Node so this is not proper HA solution as downtime can be in minutes
* Should database file get corrupted we might experience some data loss. Note Disk is highly available (all data are replicated 3 times), but does not prevent corruption on file system and database level

For production scenarios use SQL in AlwaysOn replicated cluster configuration using Kubernetes Operator. Note that as Kubernetes user you are responsible for HA, patching and licensing of your SQL. If Azure Stack provider operates managed SQL as a Service that might be easier for you to use as operator manages and upgrades SQL for you.

## Step 12 - deploy Azure cognitive services in Kubernetes in Azure Stack
A lot of Microsoft Cognitive Services (AI) can be deployed as container in Azure Stack to provide local AI capabilities. ML model is deployed and used locally so no customer data leave Azure Stack while container and Azure is connected just for billing purposes. Please have a look into [documentation](https://docs.microsoft.com/en-us/azure/cognitive-services/cognitive-services-container-support) to understand what is available.

In our example I have trained simplistic custom vision model to recognize two stuffed toys using Microsoft [Custom Vision](https://www.customvision.ai) and exported as Docker container tkubica/plysaci:latest on Docker Hub.

Deploy container and Service.

```powershell
kubectl apply -f plysaci.yaml
kubectl get service
```

Now let's send image to our model deployed in Kubernetes in Azure Stack.

```powershell
# Get service IP address
$ip = "$(kubectl get service plysaci -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"

# Ask AI by sending image to it
$results = Invoke-RestMethod -Method Post -ContentType application/octet-stream -InFile .\plysaci.jpg -Uri $ip/image

# Check results - rectangles of objects and probabilities (you typically filter predictions with less than 50% prebability)
$results.predictions
```

## Step 13 - Use Azure Container Registry to store and build images

