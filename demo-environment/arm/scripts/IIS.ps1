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
            SourcePath = '$PSScriptRoot\info.aspx'
            DestinationPath = 'c:\inetpub\wwwroot'
        }
    }
}