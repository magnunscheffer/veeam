<#
.Requirements 
- Visit https://github.com/magnunscheffer/veeam/tree/main/selfjob-entmgr#requirements-for-this-script

.DESCRIPTION
 ]This script change EM Self-Service Portal Tenant Jobs settings to force use values from a Template Job[Overriding the user settings], for more details about EM Self-Service Portal visit:
 https://helpcenter.veeam.com/docs/backup/em/em_working_with_vsphere_portal.html?ver=120
.EXAMPLE 
 Put this script on "Pre-Script" session on your Template Job and after that, use 'Copy from" Settings during the Tenant Creation. For more information access:
 https://helpcenter.veeam.com/docs/backup/em/em_adding_tenant_accounts.html?ver=120  (Step 15-c)


.NOTES
  Version:        0.1 
  Author:         Magnun Scheffer
  Contact Info: mfs_@outlook.com
  Creation Date:  21/08/2023

This script can be attached to multiple replications jobs.
.PARAMETERS
#>
#Set Job Name to use as  template for the script
param (
        [string]$TemplateName = 'Template'
    )

# Determine Tenant Job name from calling Veeam.Backup.Manager process
$parentPid = (Get-WmiObject Win32_Process -Filter "processid='$pid'").parentprocessid.ToString()
$parentCmd = (Get-WmiObject Win32_Process -Filter "processid='$parentPid'").CommandLine
$cmdArgs = $parentCmd.Replace('" "','","').Replace('"','').Split(',')
$jobName = (Get-VBRJob | ? {$cmdArgs[4] -eq $_.Id.ToString()}).Name

#Getting Template Job Object
$TemplateJob = Get-VBRJob -Name $TemplateName

#Get Tenant Job Object
$TenantJob = Get-VBRJob -Name $jobname
#$TenantJob = Get-VBRJob -Name "TenantMagnun"  #use for internal debug only

#Reading Options and Schedule from Template Job.
$Template0ptions = Get-VBRJobOptions $TemplateJob
$TemplateSchedule = Get-VBRJobScheduleOptions -Job $TemplateJob

#Getting Current Tenanat Settings
$Tenant0ptions = Get-VBRJobOptions $TenantJob
$TenantSchedule = Get-VBRJobScheduleOptions -Job $TenantJob

#Preserve specifics parameters from Tenant Job
$TemplateSchedule.OptionsBackupWindow = $TenantSchedule.OptionsBackupWindow  #On this case is force to keep the user defined backup windows instead replace with Template job settings.

#Setting Template values to Tenant Job
Set-VBRJobOptions -Job $TenantJob -Options $Template0ptions
Set-VBRJobScheduleOptions -Job $TenantJob -Options $TemplateSchedule