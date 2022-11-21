<#
.Requirements 
- Veeam Powershell PSSnapin
- Vmware PowerCli 12 or above 
- Veeam Running with a service account with permissions at vCenter.

.DESCRIPTION
 This script search for VM replicas with Orphaned snapshots "Veeam Replica Working Snapshot" caused by "An existing connection was forcibly closed by the remote host" error. 
.EXAMPLE 
 Put this script on "pre-script" session at Replication Job. (Job Settings --> Advanced --> Scripts --> Pre-Script)

.NOTES
  Version:        1.0
  Author:         Magnun Scheffer
  Contact Info: mfs_@outlook.com
  Creation Date:  21/11/2022

This script can be attached to multiple replications jobs.
.PARAMETERS
#>

$parentPid = (Get-WmiObject Win32_Process -Filter "processid='$pid'").parentprocessid.ToString()
$parentCmd = (Get-WmiObject Win32_Process -Filter "processid='$parentPid'").CommandLine
$cmdArgs = $parentCmd.Replace('" "','","').Replace('"','').Split(',')
$jobName = (Get-VBRJob | ? {$cmdArgs[4] -eq $_.Id.ToString()}).Name

$job = Get-VBRJob -Name $jobName

Write-Host $job