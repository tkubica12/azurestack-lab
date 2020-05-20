configuration IIS
{
    Import-DscResource -ModuleName xPSDesiredStateConfiguration
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

        xRemoteFile DownloadFile
        {
            DestinationPath = 'c:\inetpub\wwwroot\info.aspx'
            Uri = "https://raw.githubusercontent.com/tkubica12/azurestack-lab/master/demo-environment/arm/scripts/infov2.aspx"
        }
    }
}