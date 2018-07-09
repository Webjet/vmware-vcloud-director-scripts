#Declare org details and template for vm
#$orgVdc = '' #'name-of-vdc'
$vappname = '' #'name-of-vapp'

#Get Vapp
Try {
    write-host "Getting Vapp"    
    if (!$vappname) {
        $vappname = Get-CIVApp -OrgVdc $orgVdc -Owner $apiusername
        $vapp_array = $($vappname[0..9]) -join "`n"
    } 
	Write-host "Available vapps are: "`n"$vapp_array"
    #WJ-DEV-DC01 OR WJ-DEV-NODE01
} Catch {
	Write-Host "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Exit(1)
}