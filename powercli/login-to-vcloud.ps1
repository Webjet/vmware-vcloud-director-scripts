##Declare login credentials
$global:ciServer = 'vcloud.macquarieview.com'
$global:apiusername = ''
$apipassword = ''
$global:orgName = 'Webjet_Marketing_Pty_Ltd_42809_SVC'
$global:orgVdc = 'M2SVC20637001' #'name-of-vdc'

#Getting login details
if (!$global:apiusername) {
	$global:apiusername = read-host "Enter username: "
}
if (!$apipassword) {
	$apipassword = read-host "Enter password: "  -asSecureString
}

##Connecting to the CI Server
Try {
    Connect-CIServer -Server $ciServer -User $apiusername -Password $([Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($apipassword))) -Org $orgName | Out-Null
} Catch {
	Write-Output "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Exit(1)
} Finally {
	Write-Output "Successfully logged into $($ciServer)"
}

##Get VDC Name:
###Assumption is there is only one VDC
Try {
    write-host "Getting OrgVdc name..."
    if (!$orgVdc) {
         $orgVdc = Get-orgVdc -Org $(get-org)
}
} Catch {
	Write-Host "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Exit(1)
} Finally {
        write-host "OrgVdc set to $($orgVdc)"
}