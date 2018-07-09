# Declare login credentials
$ciServer = '' #'vcloud.macquarieview.com'
$apiusername = ''
$apipassword = ''
$orgName = '' #'Webjet_Marketing_Pty_Ltd_42809_SVC'
$orgVdc = '' #'name-of-vdc'

#Getting login details
if (!$apiusername) {
	$apiusername = read-host "Enter username: "
}
if (!$apipassword) {
	$apipassword = read-host "Enter password: "  -asSecureString
}

#Connecting to the CI Server
Try {
    Connect-CIServer -Server $ciServer -User $apiusername -Password $([Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($apipassword))) -Org $orgName | Out-Null
} Catch {
	Write-Output "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Exit(1)
} Finally {
	Write-Output "Successfully logged into $($ciServer)"
}

#Get VDC Name:
Try {
    write-host "Getting OrgVdc name..."
    if (!$orgVdc) {
        #write-host "$orgVdc not defined"
        $orgVdc = Get-orgVdc -Org $(get-org)
        write-host "OrgVdc set to $orgVdc"
    }
} Catch {
	Write-Host "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Exit(1)
}