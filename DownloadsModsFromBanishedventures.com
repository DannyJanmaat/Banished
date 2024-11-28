  Begin {
    Clear-Host
    [System.Net.ServicePointManager]::SecurityProtocol = 3072
    $ProgressPreference = 'SilentlyContinue'

      Function CatchString{
        [CmdLetBinding()]
          Param(
           [Parameter( Position = 0 ,Mandatory = $False )][String]$C,
           [Parameter( Position = 1, Mandatory = $False)][String]$FS,
           [Parameter( Position = 2, Mandatory = $False )][String]$SS
          )
        Begin {
          $C = $C.Split([Environment]::NewLine);$P = "$FS(.*?)$SS"
        }
        Process{
          $R = [regex]::Match($C,$P).Groups[1].Value
        }
        End{
          Return $R
          $FS = "";$SS = "";$C = "";$R = ""
        }
      }

    $Content = (iwr "https://www.banishedventures.com/mods/" -UseB).Content
    $Links = (iwr "https://www.banishedventures.com/mods/" -UseB).Links.href
    $Output=@()
  }

  Process {
    $Output += $Links | % {
      If ( $_ -Match '/?download=' ) {
        $Id = ($_ -Split "\?")[-1]
        $Name = ((CatchString $Content $Id '</strong>') -Split '<strong>')[-1]
        $Object = New-Object PSCustomObject
        $Object | Add-Member 'Name' $Name
        $Object | Add-Member 'Link' $_
        Return $Object
      }
    } | Select * -Unique
  }

  End {
    $Output | Sort Name | Out-File ".\Export_DownloadsModsFromBanishedventures.com.txt"
  }
