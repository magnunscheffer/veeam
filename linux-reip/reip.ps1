<#
.Requirements 
- Visit https://github.com/magnunscheffer/veeam/tree/main/linux-reip#requirements-for-this-script

.DESCRIPTION
 This script search for VM in DR PLan and re-ip linux VMs only.
.EXAMPLE 
 Put this script on "Post-failover" session at Failover Plan Job. For more detailed instructions visit:
 https://github.com/magnunscheffer/veeam/tree/main/linux-reip#requirements-for-this-script

.NOTES
  Version:        1.2 >> Added support for Debian, Suse[12-15].
  Author:         Magnun Scheffer
  Contact Info: mfs_@outlook.com
  Creation Date:  21/11/2022

This script can be attached to multiple replications jobs.
.PARAMETERS
#>
param(
  #vCenter Server Name
  [String]$vi_srv= "vcenter.vbrdemo.local",

  #Number of tentatives to get Guest IP Address from VMware
  [int]$GetIpTentatives = 3 ,

  #Log path
  [string]$Path = $PSScriptRoot+"\",

  #Name of the credentials CSV file
  [string]$credfile = $Path + "creds.csv"
)

###################################################### Functions ########################################################################

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
###################################################### Functions End ########################################################################

#Getting Parent Process ID and Filtering the job ID
$parentPid = (Get-WmiObject Win32_Process -Filter "processid='$pid'").parentprocessid.ToString()
$parentCmd = (Get-WmiObject Win32_Process -Filter "processid='$parentPid'").CommandLine
$FpId = ($parentCmd.Replace('" "','","').Replace('"','').Split(','))[4]

#Formating log file name and Start logg transcript...
$logtime = (Get-Date -Format "dd-MM-yyyy_HH.mm.ss") #Log Formatted date & time.
$LogName = $Path + $FpId.Trim()+"_"+$logtime+".log"
write-output "Starting re-ip process at: $(Get-Date)" | Out-File -FilePath $LogName 
Write-Output "Process ID: $parentPid"  | Out-File -FilePath $LogName -Append
Write-Output "Process ID: $parentCmd.Trim()" | Out-File -FilePath $LogName -Append
Write-Output "Nº of Get IP Tentatives: $GetIpTentatives" | Out-File -FilePath $LogName -Append
cmdkey /list | Out-File -FilePath $LogName -Append

#Getting information about Failover Plan
$FPlan = Get-VBRFailoverPlan | Where-Object {$FpId -eq $_.Id.ToString()}
Write-Output "Failover Plan:"  | Out-File -FilePath $LogName -Append
$FPlan | Out-File -FilePath $LogName -Append

#Loading Credentials to Windows Credential Manager
$CredList = Import-Csv -Path $credfile -Delimiter ";"  | Out-File -FilePath $LogName -Append 
Write-Output "Creds to Manage"  | Out-File -FilePath $LogName -Append
$CredList | Out-File -FilePath $LogName -Append 

If ($CredList) 
{ 
  ForEach ($Cred in $CredList) 
  {
    #masking the profile name
    $CredId =Get-StringHash -String $Cred.Profile
    If ($Cred.Action -eq "Add") 
    {    
      New-StoredCredential -Target $($CredId) -UserName $($Cred.Username) -Password $($Cred.Password) -Persist LocalMachine #| Out-File -FilePath $LogName -Append  #Atention: Can expose the passwords on log, enable only for troubleshooting.   
    }  
    If ($Cred.Action -eq "Delete") 
    {
      Remove-StoredCredential -Target $($CredId) | Out-File -FilePath $LogName -Append
    }
  }
  #Confidential information cleaning
  remove-item -Force -Path $credfile -Confirm:$false | Out-File -FilePath $LogName -Append
  Add-Content -Path $credfile -Value 'Profile;Username;Password;Action' -Force | Out-File -FilePath $LogName -Append
}

#Getting information about VMs in Failover Plan
Write-Output "VM List:"  | Out-File -FilePath $LogName -Append
$VMlist = $FPlan.FailoverPlanObject 
$VMlist | Out-File -FilePath $LogName -Append

If ($FPlan.Platform -eq "VMWare") #Because hyper-v is not supported by the script.
{
  #Connecting to vCenter Server if is Vmware  
  $vi_cred = Get-StoredCredential -Target (Get-StringHash -String "vCenter")
  Write-Output "vCenter Credential:"  | Out-File -FilePath $LogName -Append
  $vi_Cred | Out-File -FilePath $LogName -Append
  Write-Output "vCenter Connection:"  | Out-File -FilePath $LogName -Append
  Connect-VIServer -Server $vi_srv -Credential $vi_cred -Force | Out-File -FilePath $LogName -Append
  Foreach ($VM in $VMList) 
  {
    #Finding the Replica Suffix
    $ReplicaVM = Get-VBRJob -WarningAction SilentlyContinue | Where-Object {$_.JobType -eq "Replica"} | Get-VBRJobObject -Name $VM.Item.Name    
    $ReplicaSuffix = (Get-VBRJob -WarningAction SilentlyContinue | Where-Object {$_.Uid -like $ReplicaVM[0].JobId.Guid} | Get-VBRJobOptions).ViReplicaTargetOptions.ReplicaNameSuffix        

    #Creating VM Replica Name    
    $VMName = $VM.Item.Name + $ReplicaSuffix.Trim() 
    Write-Output "[VM: $VMName]------------------------------------------------------------------------------------------------------------|" | Out-File -FilePath $LogName -Append
    Write-Output "Linux VM: $($VM.Item.GuestInfo.IsUnixBased)" | Out-File -FilePath $LogName -Append

    #Testing O.S type
    If ($VM.Item.GuestInfo.IsUnixBased -eq $false)
    {
      #Skipping Windows VM
      Write-Output "Skipping re-ip for Windows VM: $($VMName)" | Out-File -FilePath $LogName -Append
      Write-Output "[SVMW]---------------------------------------------------------------------------------------------------------|" | Out-File -FilePath $LogName -Append      
      $VmSkipped+= @($VMName)
    }
    Else #If Linux go ahead.
    {  
      #Start Linux VM ReIP
      Write-Output "Starting re-ip process for LInuxVM: $($VMName)" | Out-File -FilePath $LogName -Append      
      
      #Getting information about VM from vcenter
      $VMGuest = Get-VM $VMName | Select-Object -ExpandProperty ExtensionData | Select-Object -ExpandProperty guest      
      
      #Identifying the Guest OS because some distro are not supported.
      #Clear variables before loop
      Clear-Variable NicName -Scope Global      
      Clear-Variable GuestOSFamily -Scope Global
      #$VMGuest.GuestFullName = "CentOS 6"
      Switch ($VMGuest.GuestFullName)
      {
        {($_ -like "*CentOs 5*") -or ($_ -like "*RedHat 5*") -or ($_ -like "*CentOs 6*") -or ($_ -like "*RedHat 6*")} 
        {          
          $GuestOSFamily= "RH1"
          Write-Output "Guest OS Family: [RH1] CentOS/RHEL [5-6]" | Out-File -FilePath $LogName -Append      
        }        
        {($_ -like "*CentOs 7*") -or ($_ -like "*CentOs 8*") -or ($_ -like "*RedHat 7*") -or ($_ -like "*RedHat 8*")} 
        {
          $GuestOSFamily= "RH2"
          Write-Output "Guest OS Family: [RH2] CentOS/RHEL [7+]" | Out-File -FilePath $LogName -Append      
        }
        {($_ -like "*Ubuntu Linux*") -or ($_ -like "*Debian*")} #Tested with 20.04 using netplan if you have older distro, maybe ajustments can be necessary.
        {
          $GuestOSFamily= "UBDB"
          Write-Output "Guest OS Family: [UBDB] Ubuntu" | Out-File -FilePath $LogName -Append  
        }
        {($_ -like "*SUSE Linux Enterprise 12*") -or ($_ -like "*SUSE Linux Enterprise 13*") -or ($_ -like "*SUSE Linux Enterprise 14*") -or ($_ -like "*SUSE Linux Enterprise 15*")}  #Tested from SLES12 until SLES15
        {
          $GuestOSFamily= "SLES"
          Write-Output "Guest OS Family: [SLES] Suse Linux [12-15]" | Out-File -FilePath $LogName -Append  
        }
        default
        {
          #Guest not supported by the script jump to the next VM inside the loop
          Write-Output "Error: This Distro $($VMGuest.GuestFullName) is not supported by the script yet"  | Out-File -FilePath $LogName -Append
          Write-Output "[GNST]---------------------------------------------------------------------------------------------------------|" | Out-File -FilePath $LogName -Append
          $VmError+= @($VMName) 
          Write-Output "Errors:$($VmError.count)" | Out-File -FilePath $LogName -Append                     
          continue
        }
      }
      
      #Waiting for VM to be responsive (Guest IP is Visible)
      $i = 1 #tentative number ...
      while (!$VMGuest.IpAddress) 
      {
        Write-Output "Waiting for Guest IP to be published..." | Out-File -FilePath $LogName -Append
        Start-Sleep -Seconds 10 
        $VMGuest = Get-VM $VMName  | Select-Object -ExpandProperty ExtensionData | Select-Object -ExpandProperty guest
        Write-Output "VM Guest Detail Tentative $($i):"  | Out-File -FilePath $LogName -Append
        $VMGuest | Out-File -FilePath $LogName -Append              
        $i++
        if ($i -gt $GetIpTentatives) 
        {
          Write-Output "Reip-VM of VM $VMName failed because was unable to get current IP address from VMware VIX" | Out-File -FilePath $LogName -Append
          $FailedToGetIP = $true          
          break  
        }
      }

      if ($i -eq 1) #Just to populate the log file if the while loop is not necessary.
      {
        Write-Output "VM Guest Detail:"  | Out-File -FilePath $LogName -Append
        $VMGuest | Out-File -FilePath $LogName -Append   
      }

      #If this vm doesn't have a source ip it's because the ethernet connection changed (Ex: Eth0 to Eth1) or VMwareTools is not installed, so for now skip the reip for this VM. 
      IF ($FailedToGetIP) 
      {
        Write-Output "[FGIP]---------------------------------------------------------------------------------------------------------|" | Out-File -FilePath $LogName -Append
        $VmError+= @($VMName) 
        Write-Output "Errors:$($VmError.count)" | Out-File -FilePath $LogName -Append              
        continue
      } 
      
      #Finding re-ip rule for this VM
      $ReIp= Get-VBRJob -WarningAction SilentlyContinue | Where-Object {$_.Uid -like $ReplicaVM[0].JobId.Guid} | Get-VBRViReplicaReIpRule  
          
      #Converting VM-IP into VM-IP-Masking like [10.10.1.100/24 to 10.10.1.*]
      $VMIpMask =  New-VmIpMask -IpAddress $VMGuest.Net.IpConfig.IpAddress[0].IpAddress -Prefix $VMGuest.Net.IpConfig.IpAddress[0].PrefixLength
      $ReIPRule = $ReIp | Where-Object {$_.SourceIp -eq $VMIpMask} 
      
      IF (!$ReIPRule) 
      {
        Write-Output "Error: Re-IP Rule compatible with source network '$VMIpMask' not found:" | Out-File -FilePath $LogName -Append
        Write-Output "[FGRI]---------------------------------------------------------------------------------------------------------|" | Out-File -FilePath $LogName -Append
        $VmError+= @($VMName) 
        Write-Output "Errors:$($VmError.count)" | Out-File -FilePath $LogName -Append              
        continue
      }      
      Write-Output "Selected ReIP:" | Out-File -FilePath $LogName -Append
      $ReIPRule | Out-File -FilePath $LogName -Append      
      
      #Looking for a custom guest credential
      $Guest_Cred = Get-StoredCredential -Target (Get-StringHash -String $VM.Item.Name)
            
      #Testing if VM doesn't have a custom credential.
      If (!$Guest_Cred)
      {
        $Guest_Cred = Get-StoredCredential -Target (Get-StringHash -String "Default")
        Write-Output "Selected Guest Credential:" | Out-File -FilePath $LogName -Append
        $Guest_Cred| Out-File -FilePath $LogName -Append
      }
      else{
        Write-Output "Selected Guest Credential:" | Out-File -FilePath $LogName -Append
        $Guest_Cred| Out-File -FilePath $LogName -Append 
      }       

      #Creating IP data for replacing at config file
      #Creating the New IP
      $SourceIP = $VMGuest.Net.IpConfig.IpAddress[0].IpAddress
      $OctToChange = $ReIPRule.TargetIp.split("*").Count -1
      switch ($OctToChange) 
      {
        1 {$NewIP = $ReIPRule.TargetIp.Replace(".*","")+"."+$SourceIP.Split(".")[3]}
        2 {$NewIP = $ReIPRule.TargetIp.Replace(".*","")+"."+$SourceIP.Split(".")[2]+"."+$SourceIP.Split(".")[3]  }
        3 {$NewIP = $ReIPRule.TargetIp.Replace(".*","")+"."+$SourceIP.Split(".")[1]+"."+$SourceIP.Split(".")[2]+"."+$SourceIP.Split(".")[3]}            
      } 
      Write-Output "New IP: $($NewIp)" | Out-File -FilePath $LogName -Append      
      #Creating the Replaced Mask
      $ReplacedIp = $SourceIP
      Write-Output "Replaced IP: $($ReplacedIp)" | Out-File -FilePath $LogName -Append  
      #Creating the new Mask
      $NewMask = $ReIPRule.TargetMask      
      Write-Output "New NetMask: $($NewMask)" | Out-File -FilePath $LogName -Append
      #Creating the replaced Mask
      $ReplacedMask = New-NetMask -Prefix $VMGuest.Net.IpConfig.IpAddress[0].PrefixLength
      Write-Output "Replaced NetMask: $($ReplacedMask)" | Out-File -FilePath $LogName -Append   
      #Getting new gateway info
      $NewGateway= $ReIPRule.TargetGateway.Trim() 
      Write-Output "New Gateway: $($NewGateway)" | Out-File -FilePath $LogName -Append
      #Getting replaced gateway info
      $ReplacedGateway=$VMGuest.ipstack.iprouteconfig.iproute.gateway.ipaddress | where-object {$_ -ne $null}
      Write-Output "Replaced Gateway: $($ReplacedGateway)" | Out-File -FilePath $LogName -Append
      #Creating a new prefix
      $NewPrefix = New-Prefix -IpAddress $ReIPRule.TargetMask
      Write-Output "New Prefix: $($NewPrefix)" | Out-File -FilePath $LogName -Append      
      #Creating a replaced prefix
      $ReplacedPrefix = $VMGuest.Net.IpConfig.IpAddress[0].PrefixLength 
      Write-Output "Replaced Prefix: $($ReplacedPrefix)" | Out-File -FilePath $LogName -Append

      #Get VM From vCenter
      $Vi_Vm = Get-VM $VMName      
      Write-Output "VMware VM Object:" $Vi_Vm | Out-File -FilePath $LogName -Append

      #Making some Guest OS preparation necessary to run GuestOS Script inside VM.
      Write-Output "Preparation of the Guest OS Family: $($GuestOSFamily)" | Out-File -FilePath $LogName -Append   
      Switch ($GuestOSFamily)
      {
         #ls /sys/class/net | grep -v lo 
        {"RH1" -or "RH2"}
        {
          #Getting NIC name from guest..Ex: Ethx or ENSxxx
          $NicName = ($Vi_Vm | Invoke-VMScript -ScriptText "ls /sys/class/net | grep -v lo -m 1" -GuestCredential $Guest_Cred).ScriptOutput.Trim()  
          #Mounting the NIC file path
          $ifcfg_path= "/etc/sysconfig/network-scripts/ifcfg-$($NicName)"
          if ($GuestOSFamily -eq "RH1") 
          {
            $RouteCmd="route -n | grep UG | awk '{print `$2;}'"
            $ServiceCmd="service network restart" 
          }
          else 
          {
            $RouteCmd="ip route | grep default | awk '{print `$3;}'"
            $ServiceCmd="systemctl restart network"  
          }
          #Creating new network configuration
          $NewNetConfig = @"
          sed -i "s/IPADDR=$($ReplacedIp)/IPADDR=$($NewIp)/" $($ifcfg_path)
          sed -i "s/NETMASK=$($ReplacedMask)/NETMASK=$($NewMask)/" $($ifcfg_path)
          sed -i "s/GATEWAY=$($ReplacedGateway)/GATEWAY=$($NewGateway)/" $($ifcfg_path)
          sed -i "s/PREFIX=$($ReplacedPrefix)/PREFIX=$($NewPrefix)/" $($ifcfg_path)
          $($ServiceCmd)
"@
        }        
        "UBDB"
        {
          #Getting info abount netplan
          $Netplan = ($Vi_Vm | Invoke-VMScript -ScriptText "if which netplan >/dev/null; then echo yes; else echo no; fi" -GuestCredential $Guest_Cred).ScriptOutput.Trim()  
          #Converting password to use with SUDO
          $ClearPw= [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Guest_Cred.Password))
          #New Ubuntu using Netplan
          If($Netplan -eq "yes")
          {
            $ifcfg_path = "/etc/netplan/*.yaml"            
            $routecmd="ip route | grep default | awk '{print `$3;}'"
            $NewNetConfig = @"
            export HISTIGNORE='*sudo -S*'
            echo $ClearPw | sudo -S sed -i "s,- $($ReplacedIp)/$($ReplacedPrefix),- $($NewIp)/$($NewPrefix)," $($ifcfg_path)
            echo $ClearPw | sudo -S sed -i "s,gateway4: $($ReplacedGateway),gateway4: $($NewGateway)," $($ifcfg_path)
            echo $ClearPw | sudo -S netplan apply --debug
            unset HISTIGNORE
"@ 
          }
          else #Debian and Old Ubuntu distros
          {
            #Nic Config file path
            $ifcfg_path = "/etc/network/interfaces"
            #Getting route command line:
            $IpRoute = ($Netplan = ($Vi_Vm | Invoke-VMScript -ScriptText "if which ip >/dev/null; then echo yes; else echo no; fi" -GuestCredential $Guest_Cred).ScriptOutput.Trim()  ) 
            if ($IpRoute -eq "yes")  #New distros          
            {
              $routecmd="ip route | grep default | awk '{print `$3;}'"
              $ServiceCmd="systemctl restart networking.service"
                
            }
            else  #Old Distros
            {              
              $RouteCmd="route -n | grep UG | awk '{print `$2;}'"
              $ServiceCmd = "service networking stop; sleep 5; service networking start"
            }
            #ReIP Command
            $NewNetConfig = @"            
            sed -i "s,address $($ReplacedIp),address $($NewIp)," $($ifcfg_path)
            sed -i "s,netmask $($ReplacedMask),netmask $($NewMask)," $($ifcfg_path)
            sed -i "s,gateway $($ReplacedGateway),gateway $($NewGateway)," $($ifcfg_path)
            $ServiceCmd            
"@
          }
        }
        "SLES"
        {
          #Getting NIC name from guest..Ex: Ethx or ENSxxx
          $NicName = ($Vi_Vm | Invoke-VMScript -ScriptText "ls /sys/class/net | grep -v lo -m 1" -GuestCredential $Guest_Cred).ScriptOutput.Trim() 
          #Mounting the NIC file path 
          $ifcfg_path= "/etc/sysconfig/network/ifcfg-$($NicName)"
          #Route command line
          $RouteCmd = "ip route | grep default | awk '{print `$3;}'"
          #Converting password to use with SUDO
          $ClearPw= [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Guest_Cred.Password))
          #ReIP Command
          $NewNetConfig = @"
          export HISTIGNORE='*sudo -S*'
          echo $ClearPw | sudo -S sed -i "s,$($ReplacedIp),$($NewIp)," $($ifcfg_path)
          echo $ClearPw | sudo -S sed -i "s,NETMASK='$($ReplacedMask)',NETMASK='$($NewMask)'," $($ifcfg_path)
          echo $ClearPw | sudo -S sed -i "s,/$($ReplacedPrefix),/$($NewPrefix)," $($ifcfg_path)
          echo $ClearPw | sudo -S sed -i "s,default $($ReplacedGateway),default $($NewGateway)," /etc/sysconfig/network/ifroute-$NicName 
          echo $ClearPw | sudo -S systemctl restart network
          unset HISTIGNORE
"@ 
        }
        Default
        {
          #Generic OSe
        }
      }      

      #Running network config update
      Write-Output "Running the network re-ip inside guest:" | Out-File -FilePath $LogName -Append
      $NewNetConfig.Replace($ClearPw,"*********") | Out-File -FilePath $LogName -Append      
      ($Vi_Vm | Invoke-VMScript -ScriptText $NewNetConfig -GuestCredential $Guest_Cred).ScriptOutput.Trim() | Out-File -FilePath $LogName -Append      

      #Testing if network is responsive
      $pinggw = @"
gw=`$($($routecmd))
ping -c4 `$gw | grep -Po "[[:digit:]]+ *(?=%)" 
"@    
      #Running the script 
      Write-Output "Testing Network Connectivity against default gateway:" | Out-File -FilePath $LogName -Append
      Write-Output "Ping Command:`n $($pinggw)"  | Out-File -FilePath $LogName -Append

      $pl = ($Vi_Vm | Invoke-VMScript -ScriptText $pinggw -GuestCredential $Guest_Cred).ScriptOutput.Trim() 
      Write-Output "" | Out-File -FilePath $LogName -Append
      Write-Output "Package Lost : $($pl.Trim()) %" | Out-File -FilePath $LogName -Append
      #Analysing the result
      if ($pl -ne "0") 
        { 
            Write-Output "Error: Re-IP failed, please check the VM config!" | Out-File -FilePath $LogName -Append
            Write-Output "[FRIP]---------------------------------------------------------------------------------------------------------|" | Out-File -FilePath $LogName -Append
            $VmError+= @($VMName) 
            Write-Output "Errors:$($VmError.count)" | Out-File -FilePath $LogName -Append  
                                            
        } 
      else 
        {
          Write-Output  "Info: Successfully re-ip!" | Out-File -FilePath $LogName -Append
          $VmSuccessful+= @($VMName)
          Write-Output "[SRIP]---------------------------------------------------------------------------------------------------------|" | Out-File -FilePath $LogName -Append
        } 
    }  
  }
  #Disconnecting from vCenter
  Disconnect-VIServer -Server $vi_srv -Force -confirm:$false | Out-File -FilePath $LogName -Append
}
else #At this time only VMware is supported.
{
  Write-Output "Platform $($FPTest.Platform) not supported" | Out-File -FilePath $LogName -Append
  break
}

#Jb Statistics
Write-Output "[Job Statistics]________________________________________________________________________________________________________"
If ($VmSuccessful)
{
  Write-Output "$($VmSuccessful.Count) VM(s) with Successufull Re-IP: $($VmSuccessful)" | Out-File -FilePath $LogName -Append
}
If ($VmSkipped)
{
  Write-Output "$($VmSkipped.Count) VM(s) with Skipped Re-IP: $($VmSkipped)" | Out-File -FilePath $LogName -Append
}
If ($VmError)
{
  Write-Output "$($VmError.Count) VM(s) with Failed Re-IP: $($VmError)" | Out-File -FilePath $LogName -Append 
}
Write-Output "[END]___________________________________________________________________________________________________________________"

#Finish log
write-output "Finished re-ip process at: $(Get-Date)" | Out-File -FilePath $LogName -Append

if ($VmError.Count -ge 1)
{
    [Environment]::Exit(1) 
}

