<#
.Requirements 
- Visit https://github.com/magnunscheffer/veeam/tree/main/linux-reip#requirements-for-this-script

.DESCRIPTION
 This script search for VM in DR PLan and re-ip linux VMs only.
.EXAMPLE 
 Put this script on "Post-failover" session at Failover Plan Job. For more detailed instructions visit:
 https://github.com/magnunscheffer/veeam/tree/main/linux-reip#requirements-for-this-script

.NOTES
  Version:        1.0
  Author:         Magnun Scheffer
  Contact Info: mfs_@outlook.com
  Creation Date:  21/11/2022

This script can be attached to multiple replications jobs.
.PARAMETERS
#>
param(
  #vCenter Server Name
  [String]$vi_srv= "vcenter.vbrdemo.local",

  #ReplicaSufix
  [String]$rep_sufix = "_Replica" ,

  #Log path
  [string]$Path = "C:\git\veeam\linux-reip\",

  #Credentials Upload file
  [string]$credfile = $Path + "creds.csv"
)

#Function to mascared the VM Name inside Windows Credential Manager
Function Get-StringHash 
{ 
    param
    (
        [String] $String,
        $HashName = "MD5"
    )
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($String)
    $algorithm = [System.Security.Cryptography.HashAlgorithm]::Create('MD5')
    $StringBuilder = New-Object System.Text.StringBuilder 
  
    $algorithm.ComputeHash($bytes) | 
    ForEach-Object { 
        $null = $StringBuilder.Append($_.ToString("x2")) 
    } 
  
    $StringBuilder.ToString() 
}
#Function to convert a prefix into a netmask.
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

#Function to convert a netmask into a netmask.
function New-Prefix {
  param (
    [Parameter(Mandatory=$true)]
    [string]$IpAddress
  )   
  $result = 0; 
  # ensure we have a valid IP address
  [IPAddress] $ip = $IpAddress
  $octets = $ip.IPAddressToString.Split('.');
  foreach($octet in $octets)
  {
    while(0 -ne $octet) 
    {
      $octet = ($octet -shl 1) -band [byte]::MaxValue
      $result++; 
    }
  }
  return $result;
}
#Function used to prepared sed command data.
function New-VmIpMask {
  param (
    [Parameter(Mandatory=$true)]
    [string]$IpAddress,
    [Parameter(Mandatory=$true)]
    [int]$Prefix
  )    
  Switch ($Prefix)
  {
    {$_ -le 8} 
    {    
      $IpMask = ($($IpAddress).Split(".")[0] -join ".") + ".*.*.*" 
    }        
    {($_ -ge 9) -and ($_ -le 16)} 
    {
      $IpMask = ($($IpAddress).Split(".")[0..1] -join ".") + ".*.*"
    }  
    default
    {
      $IpMask = ($($IpAddress).Split(".")[0..2] -join ".") + ".*"
    }
  }
  return $IpMask
}

#Formating log file name
$logtime = (Get-Date -Format "ddMMyyyy_HHmmss")
$LogName = $Path +"Log_"+$logtime+".log"

write-output "Starting re-ip process at: $(Get-Date)" | Out-File -FilePath $LogName 

#Loading Credentials to Windows Credential Manager
$CredList = Import-Csv -Path $credfile -Delimiter ";"
ForEach ($Cred in $CredList) 
{
  #masking the profile name
  $CredId =Get-StringHash -String $Cred.Profile
  If ($Cred.Action -eq "Add") 
  {
    #cmdkey /add:$($CredId) /user:$($Cred.Username) /pass:$($Cred.Password) | Out-File -FilePath $LogName -Append    
    New-StoredCredential -Target $($CredId) -UserName $($Cred.Username) -Password $($Cred.Password)
  }  
  If ($Cred.Action -eq "Delete") 
  {
    #cmdkey /delete:$($CredId) | Out-File -FilePath $LogName -Append
    Remove-StoredCredential -Target $($CredId)
  }
}
#Confidential information cleaning
remove-item -Force -Path $credfile -Confirm:$false
Add-Content -Path $credfile -Value 'Profile;Username;Password;Action' -Force

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

If ($FPlan.Platform -eq "VMWare") #Because hyper-v is not supported by the script.
{
  #Connecting to vCenter Server if is Vmware  
  $vi_cred = Get-StoredCredential -Target (Get-StringHash -String "vCenter")
  Connect-VIServer -Server $vi_srv -Credential $vi_cred -Force | Out-File -FilePath $LogName -Append

  Foreach ($VM in $VMList) 
  {
    Write-Output "-------------------------------------------------------------------------------------------------------------" | Out-File -FilePath $LogName -Append
    Write-Output "Is Linux VM ? $($VM.Item.GuestInfo.IsUnixBased)" | Out-File -FilePath $LogName -Append
    #Testing if is a linux Windows VM:
    If ($VM.Item.GuestInfo.IsUnixBased -eq $false)
    {
      Write-Output "Skipping re-ip for Windows VM: $($VM.Item.Name)" | Out-File -FilePath $LogName -Append
      Write-Output "-------------------------------------------------------------------------------------------------------------" | Out-File -FilePath $LogName -Append      
    }
    Else #If Linux go ahead.
    {
      Write-Output "Starting re-ip process for LInuxVM: $($VM.Item.Name)" | Out-File -FilePath $LogName -Append      
      #Creating VM Replica Name
      $VMName = $VM.Item.Name + $rep_sufix.Trim()      

      #Geting information about VM from vcenter
      $VMGuest = Get-VM $VMName | Select-Object -ExpandProperty ExtensionData | Select-Object -ExpandProperty guest
      $VMGuest | Out-File -FilePath $LogName -Append      

      #Waiting for VM to be responsive (Guest IP is Visible)
      $tentative = 1
      while (!$VMGuest.IpAddress) 
      {
        Start-Sleep -Seconds 10 
        $VMGuest = Get-VM $VMName  | Select-Object -ExpandProperty ExtensionData | Select-Object -ExpandProperty guest
        $VMGuest | Out-File -FilePath $LogName -Append      
        Write-Output "Waiting for Guest IP to be published..." | Out-File -FilePath $LogName -Append
        $tentative++
        if ($tentative -gt 50 ) 
        {
          Write-Output "Failed to re-ip VM $VMName" | Out-File -FilePath $LogName -Append
          break
        }
      }
        
      #locating re-ip rule for this VM
      #$VMName = "Rep-RHEL"
      $ReplicaVM = Get-VBRJob -WarningAction SilentlyContinue | Where-Object {$_.JobType -eq "Replica"} | Get-VBRJobObject -Name $VM.Item.Name
      $ReIp= Get-VBRJob -WarningAction SilentlyContinue | ? {$_.Uid -like $ReplicaVM[0].JobId.Guid} | Get-VBRViReplicaReIpRule
      #$VMIpMask = New-VmIpMask -IpAddress "10.10.1.50" -Prefix 32
      $VMIpMask =  New-VmIpMask -IpAddress $VMGuest.Net.IpConfig.IpAddress[0].IpAddress -Prefix $VMGuest.Net.IpConfig.IpAddress[0].PrefixLength
      $ReIPRule = $ReIp | Where-Object {$_.SourceIp -eq $VMIpMask} 
      
      #Looking for a custom guest credential
      $Guest_Cred = Get-StoredCredential -Target (Get-StringHash -String $VM.Item.Name)
      $Guest_Cred| Out-File -FilePath $LogName -Append 
      #$ProfileUsed = $ProfileList | Where-Object {$_.ProfileName -eq $($VM.Item.Name)} 
      #$ProfileUsed | Out-File -FilePath $LogName -Append      
      
      #Testing if VM doesn't have a custom credential.
      If (!$Guest_Cred)
      {
        $Guest_Cred = Get-StoredCredential -Target (Get-StringHash -String "Default")
        $Guest_Cred| Out-File -FilePath $LogName -Append
        #$ProfileUsed = $ProfileList | Where-Object {$_.ProfileName -eq "Default"}
        #$ProfileUsed | Out-File -FilePath $LogName -Append      
      }       

      #Creating IP data for replacing at config file
      #Creating the New Mask
      $NewIp = $ReIPRule.TargetIp.Trim().Replace(".*","")
      $NewIp | Out-File -FilePath $LogName -Append      
      #Creating the Old Mask
      $DotCount = ($NewIp.ToCharArray() | Where-Object {$_ -eq '.'} | Measure-Object).Count
      $ReplacedIp = $($VMGuest.Net.IpConfig.IpAddress[0].IpAddress).Split(".")[0..$DotCount] -join "."
      $ReplacedIp | Out-File -FilePath $LogName -Append      
      #Creating the old Mask
      $ReplacedMask = New-NetMask -Prefix $VMGuest.Net.IpConfig.IpAddress[0].PrefixLength
      $ReplacedMask | Out-File -FilePath $LogName -Append      
      #Creating the new Mask
      $NewMask = $ReIPRule.TargetMask
      $NewMask | Out-File -FilePath $LogName -Append      
      #Geting old gateway info
      $ReplacedGateway=$VMGuest.ipstack.iprouteconfig.iproute.gateway.ipaddress | where-object {$_ -ne $null}
      $ReplacedGateway | Out-File -FilePath $LogName -Append      
      #Geting new gateway info
      $NewGateway= $ReIPRule.TargetGateway.Trim() 
      $NewGateway | Out-File -FilePath $LogName -Append     
      #Creating a new prefix
      $NewPrefix = New-Prefix -IpAddress $ReIPRule.TargetMask
      $NewPrefix | Out-File -FilePath $LogName -Append
      #Creating a replaced prefix
      $ReplacedPrefix = $VMGuest.Net.IpConfig.IpAddress[0].PrefixLength 
      $ReplacedPrefix | Out-File -FilePath $LogName -Append    
      

      Switch ($VMGuest.GuestFullName)
      {
        {($_ -like "*CentOs 6*") -or ($_ -like "*RedHat 6*") } 
        {
          Write-Output "Guest OS: CentOS/RHEL 6" | Out-File -FilePath $LogName -Append      
          $ifcfg_path= "/etc/sysconfig/network-scripts/ifcfg-eth0"
          $routecmd="route -n | grep UG | awk '{print $2;}'"
          #Creating new network configuration
          $NewNetConfig= @"
sed -i `"s/IPADDR=$($ReplacedIp)/IPADDR=$($NewIp)/`" $($ifcfg_path)
sed -i `"s/NETMASK=$($ReplacedMask)/NETMASK=$($NewMask)/`" $($ifcfg_path)
sed -i `"s/GATEWAY=$($ReplacedGateway)/GATEWAY=$($NewGateway)/`" $($ifcfg_path)
sed -i `"s/PREFIX=$($ReplacedPrefix)/PREFIX=$($NewPrefix)/`" $($ifcfg_path)
service network restart
"@
        }        
        {($_ -like "*CentOs 7*") -or ($_ -like "*CentOs 8*") -or ($_ -like "*RedHat 7*") -or ($_ -like "*RedHat 8*")} 
        {
          Write-Output "Guest OS: CentOS/RHEL 7-8" | Out-File -FilePath $LogName -Append      
          $ifcfg_path= "/etc/sysconfig/network-scripts/ifcfg-ens192"
          $routecmd="ip route | grep default | awk '{print `$3;}'"
          $NewNetConfig= @"
sed -i `"s/IPADDR=$($ReplacedIp)/IPADDR=$($NewIp)/`" $($ifcfg_path)
sed -i `"s/NETMASK=$($ReplacedMask)/NETMASK=$($NewMask)/`" $($ifcfg_path)
sed -i `"s/GATEWAY=$($ReplacedGateway)/GATEWAY=$($NewGateway)/`" $($ifcfg_path)
sed -i `"s/PREFIX=$($ReplacedPrefix)/PREFIX=$($NewPrefix)/`" $($ifcfg_path)
systemctl restart network
"@          
        }
        {$_ -like "*Ubuntu 20*"} 
        {
          Write-Output "Guest OS: Ubuntu Family not implemented yet" | Out-File -FilePath $LogName -Append  
          $ifcfg_path = "/etc/netplan/config.yaml"
          break
        }
      }

      #Get VM From vCenter
      $Vi_Vm = Get-VM $VMName
      Write-Output "VMware VM Object:" $Vi_Vm | Out-File -FilePath $LogName -Append      
      #Running network config update
      Write-Output "Running the network re-ip inside guest:" | Out-File -FilePath $LogName -Append
      $NewNetConfig | Out-File -FilePath $LogName -Append      
      ($Vi_Vm | Invoke-VMScript -ScriptText $NewNetConfig -GuestCredential $Guest_Cred).ScriptOutput.Trim() | Out-File -FilePath $LogName -Append      

      #Testing if network is responsive
      $pinggw = @"
gw=`$($($routecmd))
ping -c4 `$gw | grep -Po "[[:digit:]]+ *(?=%)" 
"@    
      #Running the script 
      Write-Output "Testing Network Connectivity against default gateway:" | Out-File -FilePath $LogName -Append
      $pinggw | Out-File -FilePath $LogName -Append

      $pl = ($Vi_Vm | Invoke-VMScript -ScriptText $pinggw -GuestCredential $Guest_Cred).ScriptOutput.Trim() 
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
else #At this time only VMware is supported.
{
  Write-Output "Platform $($FPTest.Platform) not supported" | Out-File -FilePath $LogName -Append
  break
}
write-output "Finished re-ip process at: $(Get-Date)" | Out-File -FilePath $LogName -Append

#Renaming the log to a definitive name
$LogNewName = $LogPath+"Log_"+$FPlan.Name.Trim()+"_"+$logtime+".log"
Rename-Item -Path $LogName -NewName $LogNewName -Force