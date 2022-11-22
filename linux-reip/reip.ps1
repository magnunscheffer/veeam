<#
.Requirements 
- Veeam Powershell Module
- Vmware PowerCli 12 or above 
- Veeam Running with a service account with permissions at vCenter.

.DESCRIPTION
 This script search for VM in DR PLan and re-ip linux VMs only, skiping windows VMs. 
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
param(
  #vCenter usernamme
  [String]$vi_usr= "administrator@vsphere.local",

  #vCenter Password
  [String]$v_pwd = "Veeam123!",

  #vCenter FQDN
  [String]$vi_srv = "vcenter.vbrdemo.local", 
  
  #ReplicaSufix
  [String]$rep_sufix = "_Replica" ,

  #Csvfile
  [String]$csvfile = "C:\Git\veeam\linux-reip\config.csv",

  #Log path
  [string]$LogPath = "C:\git\veeam\linux-reip\"
)
function New-NetMask {
  param (
    [Parameter(Mandatory=$true)]
    $Prefix
  )
  #Creating the a NetMask
  $Dec = [Convert]::ToUInt32($(("1" * $Prefix).PadRight(32, "0")), 2)
  $DottedIp = $( For ($i = 3; $i -gt -1; $i--) {
    $Remainder = $Dec % [Math]::Pow(256, $i)
    ($Dec - $Remainder) / [Math]::Pow(256, $i)
    $Dec = $Remainder
  } )
  Return [String]::Join('.', $DottedIP)
}

#Convert the PlainText PW and User to a Credential.
$vi_pwd = ConvertTo-SecureString $v_pwd -AsPlainText -Force
$vi_cred = New-Object System.Management.Automation.PSCredential -ArgumentList $vi_usr, $vi_pwd

#importing profiles configuration
$logtime = (Get-Date -Format "ddMMyyyy_HHmmss")
$LogName = $LogPath +"Log_"+$logtime+".log"


write-output "Starting re-ip process at: $(Get-Date)" | Out-File -FilePath $LogName 
$ProfileList = Import-Csv -Path $csvfile -Delimiter ";"  

#Geting information about Failover Plan
$parentPid = (Get-WmiObject Win32_Process -Filter "processid='$pid'").parentprocessid.ToString()
Write-Output "Process ID: $parentPid"  | Out-File -FilePath $LogName -Append
$parentCmd = (Get-WmiObject Win32_Process -Filter "processid='$parentPid'").CommandLine
Write-Output "Process Command Line:$parentCmd" | Out-File -FilePath $LogName -Append
$cmdArgs = $parentCmd.Replace('" "','","').Replace('"','').Split(',')
$FPlan = Get-VBRFailoverPlan | Where-Object {$cmdArgs[4] -eq $_.Id.ToString()}
$FPlan | Out-File -FilePath $LogName -Append

#Geting information about VMs in Failover Plan
$VMlist = $FPlan.FailoverPlanObject 
$VMlist | Out-File -FilePath $LogName -Append

If ($FPlan.Platform -eq "VMWare") 
{
  #Connecting to vCenter Server if is Vmware
  Connect-VIServer -Server $vi_srv -Credential $vi_cred -Force | Out-File -FilePath $LogName -Append
  Foreach ($VM in $VMList) 
  {
    Write-Output "-------------------------------------------------------------------------------------------------------------" | Out-File -FilePath $LogName -Append
    Write-Output "Is Linux VM ? $($VM.Item.GuestInfo.IsUnixBased)" | Out-File -FilePath $LogName -Append
    If ($VM.Item.GuestInfo.IsUnixBased -eq $false)
    {
      Write-Output "Skipping re-ip for Windows VM: $($VM.Item.Name)" | Out-File -FilePath $LogName -Append
      Write-Output "-------------------------------------------------------------------------------------------------------------" | Out-File -FilePath $LogName -Append      
    }
    Else
    {
      Write-Output "Starting re-ip process for LInuxVM: $($VM.Item.Name)" | Out-File -FilePath $LogName -Append      
      #Mounting VM Replica Name
      $VMName = $VM.Item.Name + $rep_sufix.Trim()
      #$VMName = "Rep-RHEL" + $rep_sufix

      #Geting information about VM from vcenter
      $VMGuest = Get-VM $VMName | Select-Object -ExpandProperty ExtensionData | Select-Object -ExpandProperty guest
      $VMGuest | Out-File -FilePath $LogName -Append      

      #Waiting for VM to be responsive (Guest IP is Visible)
      while (!$VMGuest.IpAddress) 
      {
        Start-Sleep -Seconds 10 
        $VMGuest = Get-VM $VMName  | Select-Object -ExpandProperty ExtensionData | Select-Object -ExpandProperty guest
        $VMGuest | Out-File -FilePath $LogName -Append      
        Write-Output "Waiting for Guest IP to be published..." | Out-File -FilePath $LogName -Append                          
      }
            
      #Defining network parameters.
      $ProfileUsed = $ProfileList | Where-Object {$_.ProfileName -eq $($VM.Item.Name)} 
      $ProfileUsed | Out-File -FilePath $LogName -Append      
      
      #Testing if VM doesn't have a custom profile.
      If (!$ProfileUsed)
      {
        $ProfileUsed = $ProfileList | Where-Object {$_.ProfileName -eq "Default"}
        $ProfileUsed | Out-File -FilePath $LogName -Append      
      }       

      #Creating IP data for replacing at config file
      #Creating the New Mask
      $NewIpMask = $ProfileUsed.AddressMask.Trim().Replace(".x","")
      $NewIpMask | Out-File -FilePath $LogName -Append      
      #Creating the Old Mask
      $DotCount = ($NewIpMask.ToCharArray() | Where-Object {$_ -eq '.'} | Measure-Object).Count
      $OldIpMask = $($VMGuest.Net.IpConfig.IpAddress[0].IpAddress).Split(".")[0..$DotCount] -join "."
      $OldIpMask | Out-File -FilePath $LogName -Append      
      #Creating the old Mask
      $OldMask = New-NetMask -Prefix $VMGuest.Net.IpConfig.IpAddress[0].PrefixLength
      $OldMask | Out-File -FilePath $LogName -Append      
      #Creating the new Mask
      $NewMask = New-NetMask -Prefix $ProfileUsed.Prefix.Trim()
      $NewMask | Out-File -FilePath $LogName -Append      
      #Geting old gateway info
      $OldGateway=$VMGuest.ipstack.iprouteconfig.iproute.gateway.ipaddress | where-object {$_ -ne $null}
      $OldGateway | Out-File -FilePath $LogName -Append      
      #Geting new gateway info
      $NewGateway=$ProfileUsed.Gateway.Trim() 
      $NewGateway | Out-File -FilePath $LogName -Append      

      #Creating the guest credential
      $guest_pwd = ConvertTo-SecureString $($ProfileUsed.'guest-pwd-file'.Trim()) -AsPlainText -Force
      $guest_cred = New-Object System.Management.Automation.PSCredential -ArgumentList $($ProfileUsed.'guest-usr'.Trim()), $guest_pwd
      $guest_cred | Out-File -FilePath $LogName -Append      

      Switch ($VMGuest.GuestFullName)
      {
        {($_ -like "*CentOs 6*") -or ($_ -like "*RedHat 6*") } 
        {
          Write-Output "Guest OS: CentOS/RHEL 6" | Out-File -FilePath $LogName -Append      
          $ifcfg_path= "/etc/sysconfig/network-scripts/ifcfg-eth0"
          $routecmd="route -n | grep UG | awk '{print $2;}'"
        }        
        {($_ -like "*CentOs 7*") -or ($_ -like "*CentOs 8*") -or ($_ -like "*RedHat 7*") -or ($_ -like "*RedHat 8*")} 
        {
          Write-Output "Guest OS: CentOS/RHEL 7-8" | Out-File -FilePath $LogName -Append      
          $ifcfg_path= "/etc/sysconfig/network-scripts/ifcfg-ens192"
          $routecmd="ip route | grep default | awk '{print `$3;}'"
        }
        {$_ -like "*Ubuntu 20*"} 
        {
          Write-Output "Guest OS: Ubuntu Family"
          $ifcfg_path = "/etc/netplan/config.yaml"
        }
      }

      #Creating new network configuration
      $NewNetConfig= @"
sed -i `"s/IPADDR=$($OldIpMask)/IPADDR=$($NewIpMask)/`" $($ifcfg_path)
sed -i `"s/GATEWAY=$($OldGateway)/GATEWAY=$($NewGateway)/`" $($ifcfg_path)
sed -i `"s/NETMASK=$($OldMask)/NETMASK=$($NewMask)/`" $($ifcfg_path)
sed -i `"s/PREFIX=$($VMGuest.Net.IpConfig.IpAddress[0].PrefixLength)/PREFIX=$($ProfileUsed.Prefix.Trim())/`" $($ifcfg_path)
systemctl restart network
"@
      #Get VM From vCenter
      $Vi_Vm = Get-VM $VMName
      Write-Output "VMware VM Object:" $Vi_Vm | Out-File -FilePath $LogName -Append      
      #Running network config update
      Write-Output "Running the network re-ip inside guest:" | Out-File -FilePath $LogName -Append
      $NewNetConfig | Out-File -FilePath $LogName -Append      
      ($Vi_Vm | Invoke-VMScript -ScriptText $NewNetConfig -GuestCredential $guest_cred).ScriptOutput.Trim() | Out-File -FilePath $LogName -Append      

      #Testing if network is responsive
      $pinggw = @"
gw=`$($($routecmd))
ping -c4 `$gw | grep -Po "[[:digit:]]+ *(?=%)" 
"@    
      #Running the script 
      Write-Output "Testing Network Connectivity against default gateway:" | Out-File -FilePath $LogName -Append
      $pinggw | Out-File -FilePath $LogName -Append

      $pl = ($Vi_Vm | Invoke-VMScript -ScriptText $pinggw -GuestCredential $guest_cred).ScriptOutput.Trim() 
      Write-Output "" | Out-File -FilePath $LogName -Append
      Write-Output "Package Lost : $($pl.Trim()) %" | Out-File -FilePath $LogName -Append
      #Analysing the result
      if ($pl -eq "100") 
        { 
            Write-Output  "Error: Re-IP failed, please check the VM config!" | Out-File -FilePath $LogName -Append
        } 
      else 
        {
          Write-Output  "Info: Successfully re-ip!" | Out-File -FilePath $LogName -Append
        } 
      Write-Output "-------------------------------------------------------------------------------------------------------------" | Out-File -FilePath $LogName -Append
    }  
  }
  Disconnect-VIServer -Server $vi_srv -Force -confirm:$false | Out-File -FilePath $LogName -Append
}
else 
{
  Write-Output "Platform $($FPTest.Platform) not supported" | Out-File -FilePath $LogName -Append
  break
}
write-output "Finished re-ip process at: $(Get-Date)" | Out-File -FilePath $LogName -Append
$LogNewName = $LogPath+"Log_"+$FPlan.Name.Trim()+"_"+$logtime+".log"
Rename-Item -Path $LogName -NewName $LogNewName -Force

#$VM = Get-VBRJob -WarningAction SilentlyContinue | Where-Object {$_.JobType -eq "Replica"} | Get-VBRJobObject -Name Rep-RHEL
#$ReIp= Get-VBRJob -WarningAction SilentlyContinue | ? {$_.Uid -like $VM.JobId.Guid} | Get-VBRViReplicaReIpRule