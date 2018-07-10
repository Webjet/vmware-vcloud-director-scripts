### stopVapp v1
###   -ciServer "vcloud.macquarieview.com" -vappName "WJ-DEV-NODE01" -orgVdc "M2SVC20637001" -orgname "Webjet_Marketing_Pty_Ltd_42809_SVC" -apiusername "devadmin" -apipassword "P@ssw0rd"
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
$vappName = $env:vappNameStop
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
} Catch {
	Write-Host "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Exit(1)
} Finally {
	Write-Host "Imported VCloud Module"
}
	
# Authenticate and connect to our endpoint:
# (Clear text password below is for lab/demo purpose only. Recommend hashing credential in production setup)
Try {
	Connect-CIServer -Server $ciServer -User $apiusername -Password $apipassword -Org $orgname | Out-Null
} Catch {
	Write-Host "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Exit(1)
} Finally {
	Write-Host "Logged into $($ciServer)"
}

# Get our Target VDC:
Try {
	write-host "Getting Target VDC $($orgVdc)"
	$orgVdc = get-orgvdc $orgVdc
} Catch {
	Write-Host "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Exit(1)
}

# Find Target VApp
Try {
	write-host "Getting Target VApp $($vappname)"
	$targetvapp = Get-CIVApp -OrgVdc $orgVdc -Name $vappname
} Catch {
	Write-Host "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Write-Host "Unable to find VApp $($vappname)"
	Exit(1)
}
	
# Stop our Target VApp:	
Try {
	write-host "Attempting to stop VApp"
	Stop-CIVApp $targetvapp -Confirm:$False -ErrorAction Stop | Out-Null
	$i = 1
	do {
		Start-Sleep -s 20 -ErrorAction SilentlyContinue
		$targetvapp = Get-CIVApp -OrgVdc $orgVdc -Name $vappName
		if ($i++ -gt 9) {
			Write-Host "$vappName took too long to shutdown"
			Exit(1)
		}
	} while ($targetvapp.Enabled -ne "PoweredOff")
} Catch {
	Write-Host "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Exit(1)
}
write-host "VApp Stopped"
Disconnect-CIServer -Server $ciServer  -Confirm:$false

Stop-Transcript
### END