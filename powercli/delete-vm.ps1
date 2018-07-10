$ciVappName = "WJ-DEV-NODE01"
$vmsToDeleteNames = "WEBJET-TEST-VM01", "WJ-TEST-VM02"
$civApp = Get-CIVApp $ciVappName
$vmsToDelete = Get-CIVM -VApp $civApp | ? { $vmsToDeleteNames -contains $_.Name }
$refsToVmsToDelete = $vmsToDelete | % {
   $ref = New-Object VMware.VimAutomation.Cloud.Views.Reference
   $ref.Href = $_.Href
   $ref
}

$recomposeParams = New-Object VMware.VimAutomation.Cloud.Views.RecomposeVAppParams
$recomposeParams.DeleteItem = $refsToVmsToDelete
$task = $civApp.ExtensionData.RecomposeVApp_Task($recomposeParams)
# Note that if you need to edit multiple vapps, you can start the tasks for all vapps
# and wait for the tasks at the end.
$task.Wait()