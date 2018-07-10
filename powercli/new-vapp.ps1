#Declare org details and template for vm
$orgVdc = '' #'name-of-vdc'
$vappname = '' #'name-of-vapp'

#Create a new Vapp
Try {
    write-host "Getting existing vapp from $($orgVdc)"    
    if (!$vappname) then {
        $vappname =  Get-CIVApp -OrgVdc $orgVdc -Owner $apiusername
        Write-host "Available vapps are: $($vappname[0..9])"
        #WJ-DEV-DC01 OR WJ-DEV-NODE01
    }
} Catch {
	Write-Host "$($Error[0].ToString()) Line Number: $($Error[0].InvocationInfo.ScriptLineNumber)"
	Exit(1)
}