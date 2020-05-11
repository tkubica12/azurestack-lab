configuration IIS
{
    Import-DscResource -Name MSFT_xRemoteFile -ModuleName xPSDesiredStateConfiguration
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
            DestinationPath = 'c:\inetpub\wwwroot'
            Uri = "https://raw.githubusercontent.com/tkubica12/azurestack-lab/master/demo-environment/arm/scripts/info.aspx"
        }
    }
}