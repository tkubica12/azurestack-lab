configuration IIS
{
    node "localhost"
    {
        WindowsFeature IIS {
            Ensure = "Present"
            Name   = "Web-Server"
        }

        WindowsFeature ASP { 
            Ensure = "Present"
            Name   = "Web-Asp-Net45"
        } 

        File WebsiteContent {
            Ensure = 'Present'
            SourcePath = 'https://raw.githubusercontent.com/tkubica12/azurestack-lab/master/demo-environment/arm/scripts/info.aspx'
            DestinationPath = 'c:\inetpub\wwwroot'
        }
    }
}