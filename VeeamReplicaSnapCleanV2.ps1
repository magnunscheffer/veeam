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
  Creation Date:  22/04/2020

This script can be attached to multiple replications jobs.
.PARAMETERS
#>

#import Veeam powershell Module
Add-PSSnapin VeeamPSSnapin

# Determine job name from calling Veeam.Backup.Manager process
$parentPid = (Get-WmiObject Win32_Process -Filter "processid='$pid'").parentprocessid.ToString()
$parentCmd = (Get-WmiObject Win32_Process -Filter "processid='$parentPid'").CommandLine
$cmdArgs = $parentCmd.Replace('" "','","').Replace('"','').Split(',')
$jobName = (Get-VBRJob | ? {$cmdArgs[4] -eq $_.Id.ToString()}).Name
$retrytime = 10
#$jobName = "Repl-Job-24Hrs-Linux"

############################### User Parameters ###############################
$vCenterName = "vcenter.domainfqnd.local"                 #FQDN of vCenter Server
$replicaSuffix = "_replica"                           #Suffix used by replica (config in Veeam replication job)
$logpath= "C:\Scripts\Replica\Logs"                                #Log file path 
$logretention = 30                                    #How long the log will be stored
#--------------------------------------------------------------

#Script Log (Daily)
$TargetFolder = $logpath + "\" + $jobName
 
IF (-not (Test-Path $TargetFolder))
{
    Write-Host "Creating $TargetFolder" 
    New-Item -ItemType Directory -Path $TargetFolder -Force              
}

$Date = Get-Date -Format "dd-MM-yyyy"
$OutputFileLocation =$TargetFolder+"\Log_replication_"+$jobName+"_"+$Date+".log"

Start-Transcript -path $OutputFileLocation -append 
#Clear Log files older than 30 days.
Get-ChildItem "$logpath\Log_replication*"  -File | Where CreationTime -lt  (Get-Date).AddDays(-$logretention)  | Remove-Item -Force


#List VMs in ReplicaJob.
$job = Get-VBRJob -Name $jobName
$session = $job.FindLastSession()
$jobfailed = "no"
if ($null -ne $session) {
    #Conect to vCenter to collect information about snapshots.
    Connect-VIServer -Server $vCenterName -Force | Out-Null
    #List all VMs in job and identify if VM status is failed, if is 'true' this script will try to  delete the orphaned snapshots.
    ForEach ($vm in $session.GetTaskSessions()) {        
        if ($vm.status -eq "Failed") 
        {
            $jobfailed = "yes"
            Write-Host "-----------------------------------------Start VM $($VM.name) Clean task---------------------------------------------"
            Write-Host "VM Name:" $vm.Name "| Status:" $vm.status        
            $ReplicaName = $VM.name + $replicaSuffix             
            Write-Host "Searching for VM" $ReplicaName "on vcenter" $vCenterName
            $Replica = Get-VM -Name $ReplicaName -ErrorAction SilentlyContinue 
        
            #If found a VMWare VM Called VMxxxx_replica" go to next.
            If ($Replica)
            {   
                Write-Host "Analyzing snapshots for vm: '" $Replica.Name "' " 
                $Snapshots = Get-Snapshot -VM $Replica 
                foreach ($Snap in $Snapshots) 
                {
                    #If found a snapshot called "Veeam Replica Working Snapshot" go to next.
                    If ($Snap.name -eq "Veeam Replica Working Snapshot")
                    {
                        #Cleaning orphaned snapshot
                        Write-Host "Cleaning Veeam Snapshot '"$snap.Name"' "
                        Remove-Snapshot -Snapshot $Snap -Confirm:$false
                    }
                    <#else 
                    { 
                        Write-Host "No Action Needed, this snapshot" $snap.Name  "is not a 'Veeam Replica Working Snapshot'"
                    }#>
                }
            } 
            Else
            {
                Write-Host "Replica not found for VM:$($Replica.Name)" 
            }
            Write-Host "----------------------------------------END VM $($VM.name) Clean task---------------------------------------------"         
        }
    }
    Disconnect-Viserver -Server $vCenterName -Confirm:$false
    if ($jobfailed -eq "yes")
        {        
            Write-Host "Job $JobName failed, restarting job in $retrytime minutes"
            $timerun = (Get-Date).AddMinutes($retrytime)
            $T = New-JobTrigger -Once -At $timerun
            $old = Get-ScheduledJob -Name $jobName -ErrorAction SilentlyContinue
            if ($old) 
            {
                Unregister-ScheduledJob -Name $jobName -Force
            }
            Register-ScheduledJob -Name $jobName -Trigger $T -ScriptBlock {
                param(
                $jobName
                )
                Add-PSSnapin VeeamPSSnapin;$job = Get-VBRJob -Name $jobName;Start-VBRJob -Job $job -RetryBackup -RunAsync;Unregister-ScheduledJob -Name $jobName -Force
            } -ArgumentList $JobName | Out-Null
    }
}
Stop-Transcript