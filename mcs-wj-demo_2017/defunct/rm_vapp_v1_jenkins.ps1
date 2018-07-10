### rm_vapp v1
###   .\rm_vapp.ps1 -ciServer "vcloud.macquarieview.com" -vappName "WJ-DEV-NODE01" -orgVdc "M2SVC20637001" -orgname "Webjet_Marketing_Pty_Ltd_42809_SVC" -apiusername "devadmin" -apipassword "P@ssw0rd"
###

#Param(
    #[parameter(Mandatory=$true)]
    #$ciServer,
    #[parameter(Mandatory=$true)]
    #$vappName,
    #[parameter(Mandatory=$true)]
    #$orgVdc,
    #[parameter(Mandatory=$true)]
    #$orgname,
    #[parameter(Mandatory=$true)]
    #$apiusername,
    #[parameter(Mandatory=$true)]
    #$apipassword
#)

$ciServer = $env:ciServer
$vappName = $env:vappName
$orgVdc = $env:orgVdc
$orgname = $env:orgname
$apiusername = $env:apiusername
$apipassword = $env:apipassword


$ErrorActionPreference = "Stop"
$ProgressPreference = 'SilentlyContinue'
try{
	stop-transcript | out-null
}
Catch [System.InvalidOperationException]{}
Start-Transcript .\StopVapp-$vappname.txt -append -noclobber

try {
Add-PSSnapin VMware.VimAutomation.Cloud -ErrorAction SilentlyContinue
#[VMware.VimAutomation.Cloud.Views.CloudClient]::ApiVersionRestriction.ForceCompatibility("5.1")
# clear text password below is for lab/demo purpose only. recommend hashing credential in production setup
Connect-CIServer -Server $ciServer -User $apiusername -Password $apipassword -Org $orgname 

write-host "===Get VDC==="
$orgVdc = get-orgvdc $orgVdc

write-host "===Get our target VApp==="
$targetvapp = Get-CIVApp -OrgVdc $orgVdc -Name $vappName

write-host "===Stop our target VApp==="
Stop-CIVApp $targetvapp -Confirm:$False -ErrorAction Stop
$i = 1
do {
	Start-Sleep -s 20 -ErrorAction SilentlyContinue
	$targetvapp = Get-CIVApp -OrgVdc $orgVdc -Name $vappName
	if ($i++ -gt 9) {
		Write-Output "$vappName took too long to shutdown"
		Exit(1)
	}
} while ($targetvapp.Enabled -ne "PoweredOff")

write-host "===Delete our target VApp==="
Remove-CIVApp -VApp $targetvapp -Confirm:$False -ErrorAction Stop

Disconnect-CIServer -Server $ciServer  -Confirm:$false

}
Catch
{
    $ErrorMessage = $_.Exception.Message
    write-host "ERROR: $($ErrorMessage)"
    Break
}

Stop-Transcript
### END