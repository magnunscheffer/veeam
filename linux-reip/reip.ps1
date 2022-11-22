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
  [String]$csvfile = "C:\Git\veeam\linux-reip\config.csv" 
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
write-output "Starting re-ip process at: $(Get-Date)" | Out-File -FilePath C:\git\veeam\linux-reip\log.txt 
$ProfileList = Import-Csv -Path $csvfile -Delimiter ";"  

#Geting information about Failover Plan
$parentPid = (Get-WmiObject Win32_Process -Filter "processid='$pid'").parentprocessid.ToString()
$parentPid | Out-File -FilePath C:\git\veeam\linux-reip\log.txt -Append
$parentCmd = (Get-WmiObject Win32_Process -Filter "processid='$parentPid'").CommandLine
$parentCmd | Out-File -FilePath C:\git\veeam\linux-reip\log.txt -Append
$cmdArgs = $parentCmd.Replace('" "','","').Replace('"','').Split(',')
$FPlan = (Get-VBRFailoverPlan | Where-Object {$cmdArgs[4] -eq $_.Id.ToString()}).Name
$FPlan | Out-File -FilePath C:\git\veeam\linux-reip\log.txt -Append

#$FPlan = (Get-VBRFailoverPlan -Name FP1)
#Geting information about VMs in Failover Plan
$VMlist = $FPlan.FailoverPlanObject 
$VMlist | Out-File -FilePath C:\git\veeam\linux-reip\log.txt -Append

If ($FPlan.Platform -eq "VMWare") 
{
  #Connecting to vCenter Server if is Vmware
  Connect-VIServer -Server $vi_srv -Credential $vi_cred -Force | Out-File -FilePath C:\git\veeam\linux-reip\log.txt -Append
  Foreach ($VM in $VMList) 
  {
    $VM.Item.GuestInfo | Out-File -FilePath C:\git\veeam\linux-reip\log.txt -Append
    If ($VM.Item.GuestInfo.IsUnixBased -eq $false)
    {
      Write-Output "Skiping re-ip for VMs Windows" | Out-File -FilePath C:\git\veeam\linux-reip\log.txt -Append      
    }
    Else
    {
      Write-Output "VM Linux starting Re-IP process..." | Out-File -FilePath C:\git\veeam\linux-reip\log.txt -Append      
      #Mounting VM Replica Name
      $VMName = $VM.Item.Name + $rep_sufix.Trim()
      #$VMName = "Rep-RHEL" + $rep_sufix

      #Geting information about VM from vcenter
      $VMGuest = Get-VM $VMName | Select-Object -ExpandProperty ExtensionData | Select-Object -ExpandProperty guest
      $VMGuest | Out-File -FilePath C:\git\veeam\linux-reip\log.txt -Append      

      #Waiting for VM to be responsive (Guest IP is Visible)
      while (!$VMGuest.IpAddress) 
      {
        Start-Sleep -Seconds 10 
        $VMGuest = Get-VM $VMName  | Select-Object -ExpandProperty ExtensionData | Select-Object -ExpandProperty guest
        $VMGuest | Out-File -FilePath C:\git\veeam\linux-reip\log.txt -Append      
        Write-Output "Waiting for Guest IP to be published..." | Out-File -FilePath C:\git\veeam\linux-reip\log.txt -Append                          
      }
            
      #Defining network parameters
      $ProfileUsed = $ProfileList | Where-Object {$_.ProfileName -eq $($VM.Item.Name)} 
      $ProfileUsed | Out-File -FilePath C:\git\veeam\linux-reip\log.txt -Append      
      #$ProfileUsed = $ProfileList | Where-Object {$_.ProfileName -eq "XPTO"} 

      #Testing if VM doesn't have a custom profile.
      If (!$ProfileUsed)
      {
        $ProfileUsed = $ProfileList | Where-Object {$_.ProfileName -eq "Default"}
        $ProfileUsed | Out-File -FilePath C:\git\veeam\linux-reip\log.txt -Append      
      }       

      #Creating IP data for replacing at config file
      #Creating the New Mask
      $NewIpMask = $ProfileUsed.AddressMask.Trim().Replace(".x","")
      $NewIpMask | Out-File -FilePath C:\git\veeam\linux-reip\log.txt -Append      
      #Creating the Old Mask
      $DotCount = ($NewIpMask.ToCharArray() | Where-Object {$_ -eq '.'} | Measure-Object).Count
      $OldIpMask = $($VMGuest.Net.IpConfig.IpAddress[0].IpAddress).Split(".")[0..$DotCount] -join "."
      $OldIpMask | Out-File -FilePath C:\git\veeam\linux-reip\log.txt -Append      
      #Creating the old Mask
      $OldMask = New-NetMask -Prefix $VMGuest.Net.IpConfig.IpAddress[0].PrefixLength
      $OldMask | Out-File -FilePath C:\git\veeam\linux-reip\log.txt -Append      
      #Creating the new Mask
      $NewMask = New-NetMask -Prefix $ProfileUsed.Prefix.Trim()
      $NewMask | Out-File -FilePath C:\git\veeam\linux-reip\log.txt -Append      
      #Geting old gateway info
      $OldGateway=$VMGuest.ipstack.iprouteconfig.iproute.gateway.ipaddress | where-object {$_ -ne $null}
      $OldGateway | Out-File -FilePath C:\git\veeam\linux-reip\log.txt -Append      
      #Geting new gateway info
      $NewGateway=$ProfileUsed.Gateway.Trim() 
      $NewGateway | Out-File -FilePath C:\git\veeam\linux-reip\log.txt -Append      

      #Creating the guest credential
      $guest_pwd = ConvertTo-SecureString $($ProfileUsed.'guest-pwd-file'.Trim()) -AsPlainText -Force
      $guest_cred = New-Object System.Management.Automation.PSCredential -ArgumentList $($ProfileUsed.'guest-usr'.Trim()), $guest_pwd
      $guest_cred | Out-File -FilePath C:\git\veeam\linux-reip\log.txt -Append      

      Switch ($VMGuest.GuestFullName)
      {
        {($_ -like "*CentOs 6*") -or ($_ -like "*RedHat 6*") } 
        {
          Write-Output "CentOS/RHEL 6"
          $ifcfg_path= "/etc/sysconfig/network-scripts/ifcfg-eth0"
          $routecmd="route -n | grep UG | awk '{print $2;}'"
        }        
        {($_ -like "*CentOs 7*") -or ($_ -like "*CentOs 8*") -or ($_ -like "*RedHat 7*") -or ($_ -like "*RedHat 8*")} 
        {
          Write-Output "CentOS/RHEL 7-8" | Out-File -FilePath C:\git\veeam\linux-reip\log.txt -Append      
          $ifcfg_path= "/etc/sysconfig/network-scripts/ifcfg-ens192"
          $routecmd="ip route | grep default | awk '{print `$3;}'"
        }
        {$_ -like "*Ubuntu 20*"} 
        {
          Write-Output "Ubuntu Family"
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
      $NewNetConfig | Out-File -FilePath C:\git\veeam\linux-reip\log.txt -Append      
      $Vi_Vm = Get-VM $VMName
      $Vi_Vm | Out-File -FilePath C:\git\veeam\linux-reip\log.txt -Append      
      #Running network config update
      ($Vi_Vm | Invoke-VMScript -ScriptText $NewNetConfig -GuestCredential $guest_cred).ScriptOutput.Trim() | Out-File -FilePath C:\git\veeam\linux-reip\log.txt -Append      

      #Testing if network is responsive
      $pinggw = @"
gw=`$($($routecmd))
ping -c4 `$gw | grep -Po "[[:digit:]]+ *(?=%)" 
"@
      $pinggw | Out-File -FilePath C:\git\veeam\linux-reip\log.txt -Append
      #Running the script 
      $pl = ($Vi_Vm | Invoke-VMScript -ScriptText $pinggw -GuestCredential $guest_cred).ScriptOutput.Trim() 
      Write-Output "Package Lost %: "$pl | Out-File -FilePath C:\git\veeam\linux-reip\log.txt -Append
      #Analysing the result
      if ($pl -eq "100") 
        { 
            Write-Output  "Error: Re-IP failed, please check the VM config!"
        } 
      else 
        {
          Write-Output  "Info: Successfully re-ip!"
        } 
    }  
  }
  Disconnect-VIServer -Server $vi_srv -Force | Out-File -FilePath C:\git\veeam\linux-reip\log.txt -Append
}
else 
{
  Write-Output "Platform $($FPTest.Platform) not supported" | Out-File -FilePath C:\git\veeam\linux-reip\log.txt -Append
  break
}