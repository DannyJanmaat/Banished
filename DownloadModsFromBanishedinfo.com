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

    $Uri = "https://banishedinfo.com/mods/ajax?action=mods&start=0&count=10000&section=&sort=downloads"
    $JSON = (iwr $Uri -ContentType 'application/json' -UseB).Content | ConvertFrom-Json
    $BaseLinks=@();$Output=@()
  }

  Process {
    $JSON | % {
      $Url = $_.url
      $ModId = $_.mod_id
      $Object = New-Object PSCustomObject
      $Object | Add-Member 'Page' "https://banishedinfo.com/mods/view/$Url"
      $Object | Add-Member 'ModId' $ModId
      $BaseLinks += $Object
    };$BaseLinksCount = $BaseLinks.Count

    $Counter=0
      ForEach ( $BaseLink in $BaseLinks ) {
        $Counter++
        $ModId = $BaseLink.ModId
        $Content = Try { iwr $BaseLink.page -UseB } Catch {Break}
        $ContentLinkId = ( CatchString $Content '/mods/download/' '"' ).Split('/')[-1]
          ForEach ( $Link in $Content.Links.href ) {
            If ( $Link -Match "/mods/download/$ModId" ) {
              $LinkId = ( $Link ).Split( '/' )[-1]
              $LinkName = $Link -Replace '/mods/download/',''
                If ( $LinkId -Eq $ContentLinkId ) {
                  $Object = New-Object PSCustomObject
                  $Page = "https://banishedinfo.com/mods/file/$LinkName"
                  $Object | Add-Member 'Page' $Page
                  $Output += $Object
                  Write-Host "$Counter/$BaseLinksCount - $Page"
                  Break
                }
            }
          }
      }
  }

  End {
    $Output = $Output.Page | Select -Unique
    $Output | Out-File ".\Result_DownloadModsFromBanishedinfo.com.txt"
  }
