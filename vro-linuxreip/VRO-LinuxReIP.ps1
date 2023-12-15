Param(
    #vCenter Address
    [Parameter(Mandatory=$false)]
    [String]$VCenterFQDN,    
    #vCenter Credential
    [string]$VcenterCredUsername,
    [string]$VcenterCredPassword,
    #VM Credential
    [string]$VmCredUsername,
    [string]$VmCredPassword,
    #VM data
    [string]$SourceVmName,
    [string]$SourceVmIp,
    [string]$TargetVmName,        
    #Log Path
    [string]$Path = "C:\Scripts\"
)

#Validate de parameters
Write-Host "---vCenter parameters --------- `
FQDN: $VCenterFQDN `
Username: $VcenterCredUsername `
Password: $($VcenterCredPassword.Replace($VcenterCredPassword,"********"))"
Write-Host "---VM parameters ---------`
SourceName: $SourceVmName SourceIP:$SourceVmIp 
TargetName: $TargetVmName `
Username: $VmCredUsername `
Password: $($VmCredPassword.Replace($VmCredPassword,"********"))"

###################################################### Functions ########################################################################
#Function to convert a netmask into a prefix.
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

#Function to classify the Guest Os Family
function Get-OsFamily {
  param (
    [Parameter(Mandatory=$true)]
    [string]$GuestOSFullName
  ) 

  #$VMConfigOS.GuestFullName
    Switch ($GuestOSFullName)
    {
    {($_ -like "*CentOs 5*") -or ($_ -like "*RedHat 5*") -or ($_ -like "*CentOs 6*") -or ($_ -like "*RedHat 6*") -or ($_ -like "*Oracle Linux 6*")} 
        {          
            $GuestOSFamily= "RH1"
            Write-Output "Guest OS Family: [RH1] CentOS/RHEL [5-6]" | Out-File -FilePath $LogName -Append      
        }        
    {($_ -like "*CentOs 7*") -or ($_ -like "*CentOs 8*") -or ($_ -like "*RedHat 7*") -or ($_ -like "*RedHat 8*") -or ($_ -like "*Oracle Linux 7*") -or ($_ -like "*Oracle Linux 8*")} 
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
            $GuestOSFamily= "NotSupported" 
        }
    }
  return $GuestOSFamily  
}

function Set-IPAddress {
    param (
        #Request type
        [Parameter(Mandatory=$true)]
        [ValidateSet("Full","Route")][string]$Type,
        #GuestOS Name
        [Parameter(Mandatory=$true)]
        [string]$OSFamily,
        [string]$SrcIP,
        [string]$TgtIP,
        [string]$SrcMask,
        [string]$TgtMask,
        [string]$SrcGateway,
        [string]$TgtGateway,
        [string]$SrcPrefix,
        [string]$TgtPrefix,
        #Virtual Machine Credential
        [Parameter(Mandatory=$true)]
        $VmCredential,
        #Virtual Machine Name
        [Parameter(Mandatory=$true)]
        $VM
      ) 
    Switch ($OSFamily)
    {
        #ls /sys/class/net | grep -v lo 
    {"RH1" -or "RH2"}
    {
        #Getting NIC name from guest..Ex: Ethx or ENSxxx
        $NicName = ($VM | Invoke-VMScript -ScriptText "ls /sys/class/net | grep -v lo -m 1" -GuestCredential $VmCredential).ScriptOutput.Trim()  
        #Mounting the NIC file path
        $ifcfg_path= "/etc/sysconfig/network-scripts/ifcfg-$($NicName)"
        if ($OSFamily -eq "RH1") 
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
        sed -i "s/IPADDR=$($SrcIP)/IPADDR=$($TgtIP)/" $($ifcfg_path)
        sed -i "s/NETMASK=$($SrcMask)/NETMASK=$($TgtMask)/" $($ifcfg_path)
        sed -i "s/GATEWAY=$($SrcGateway)/GATEWAY=$($TgtGateway)/" $($ifcfg_path)
        sed -i "s/PREFIX=$($SrcPrefix)/PREFIX=$($TgtPrefix)/" $($ifcfg_path)
        $($ServiceCmd)
"@
    }        
    "UBDB"
    {
        #Getting info abount netplan
        $Netplan = ($VM | Invoke-VMScript -ScriptText "if which netplan >/dev/null; then echo yes; else echo no; fi" -GuestCredential $VmCredential).ScriptOutput.Trim()  
        #Converting password to use with SUDO
        $ClearPw= [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($VmCredential.Password))
        #New Ubuntu using Netplan
        If($Netplan -eq "yes")
        {
        $ifcfg_path = "/etc/netplan/*.yaml"            
        $routecmd="ip route | grep default | awk '{print `$3;}'"
        $NewNetConfig = @"
        export HISTIGNORE='*sudo -S*'
        echo $ClearPw | sudo -S sed -i "s,- $($SrcIP)/$($SrcPrefix),- $($TgtIP)/$($TgtPrefix)," $($ifcfg_path)
        echo $ClearPw | sudo -S sed -i "s,gateway4: $($SrcGateway),gateway4: $($TgtGateway)," $($ifcfg_path)
        echo $ClearPw | sudo -S netplan apply --debug
        unset HISTIGNORE
"@ 
        }
        else #Debian and Old Ubuntu distros
        {
        #Nic Config file path
        $ifcfg_path = "/etc/network/interfaces"
        #Getting route command line:
        $IpRoute = ($Netplan = ($VM | Invoke-VMScript -ScriptText "if which ip >/dev/null; then echo yes; else echo no; fi" -GuestCredential $VmCredential).ScriptOutput.Trim()  ) 
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
        export HISTIGNORE='*sudo -S*'            
        echo $ClearPw | sudo -S sed -i "s,address $($SrcIP),address $($TgtIP)," $($ifcfg_path)
        echo $ClearPw | sudo -S sed -i "s,netmask $($SrcMask),netmask $($TgtMask)," $($ifcfg_path)
        echo $ClearPw | sudo -S sed -i "s,gateway $($SrcGateway),gateway $($TgtGateway)," $($ifcfg_path)
        echo $ClearPw | sudo -S $ServiceCmd            
"@
        }
    }
    "SLES"
    {
        #Getting NIC name from guest..Ex: Ethx or ENSxxx
        $NicName = ($VM | Invoke-VMScript -ScriptText "ls /sys/class/net | grep -v lo -m 1" -GuestCredential $VmCredential).ScriptOutput.Trim() 
        #Mounting the NIC file path 
        $ifcfg_path= "/etc/sysconfig/network/ifcfg-$($NicName)"
        #Route command line
        $RouteCmd = "ip route | grep default | awk '{print `$3;}'"
        #Converting password to use with SUDO
        $ClearPw= [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($VmCredential.Password))
        #ReIP Command
        $NewNetConfig = @"
        export HISTIGNORE='*sudo -S*'
        echo $ClearPw | sudo -S sed -i "s,$($SrcIP),$($TgtIP)," $($ifcfg_path)
        echo $ClearPw | sudo -S sed -i "s,NETMASK='$($SrcMask)',NETMASK='$($TgtMask)'," $($ifcfg_path)
        echo $ClearPw | sudo -S sed -i "s,/$($SrcPrefix),/$($TgtPrefix)," $($ifcfg_path)
        echo $ClearPw | sudo -S sed -i "s,default $($SrcGateway),default $($TgtGateway)," /etc/sysconfig/network/ifroute-$NicName 
        echo $ClearPw | sudo -S systemctl restart network
        unset HISTIGNORE
"@ 
    }
    Default
    {
        #Generic OSe
    }
    } 
    
    #Type of Return...
    If ($Type -eq "Full")
    {
      return $NewNetConfig  
    }
    else
    {
      return $RouteCmd  
    }
    

}

###################################################### Functions End ########################################################################
try {     
    #Formating log file name and Start logg transcript...
    $logtime = (Get-Date -Format "dd-MM-yyyy_HH.mm.ss") #Log Formatted date & time.
    $LogName = $Path + $SourceVmName.Trim()+"_"+$logtime+".log"
    write-output "Starting re-ip process at: $(Get-Date)" | Out-File -FilePath $LogName 
    Write-Host "Starting re-ip process at: $(Get-Date) logfile $LogName" 

    #Creating credencials for vCenter   
    $password_vi = ConvertTo-SecureString $VcenterCredPassword -AsPlainText -Force
    $VcenterCred = New-Object System.Management.Automation.PSCredential ($VcenterCredUsername, $password_vi)  
    
    #Creating credentialsfro VM (Source Replication Job)
    $password_vm = ConvertTo-SecureString $VmCredPassword -AsPlainText -Force
    $VmCred = New-Object System.Management.Automation.PSCredential ($VmCredUsername, $password_vm)  
    
    Write-Host "Connecting to vCenter..."
    try 
    {      
      $viConnection = Connect-VIServer -Server $VCenterFQDN -Credential $VcenterCred -Force -ErrorAction Stop 
      $viConnection | Out-File -FilePath $LogName -Append    
      Write-Host "Connected with Session ID:$($viConnection.SessionId)"       
    }
    catch 
    {
      $_.Exception.Message | Out-File -FilePath $LogName -Append 
      Write-Output "Fatal Error: Failed to connect to $VCenterFQDN, aborting re-ip rules process at: $(Get-Date)."  | Out-File -FilePath $LogName -Append
      [Environment]::Exit(1) 
      exit;
    }

    #Getting information about VM from vcenter 
    Write-Output "Getting information about VM from vcenter:" | Out-File -FilePath $LogName -Append
    Write-Host "Getting information about VM OS from vcenter..."
    $VirtualMachine = Get-VM $TargetVmName   

    if( $VirtualMachine.guestid.contains("windows"))
    {
      Write-Output "Warning: This script works only with Linux VMs, Veeam already has native RE-IP for Windows VMs!"  | Out-File -FilePath $LogName -Append
      Write-Warning "This script works only with Linux VMs, Veeam already has native RE-IP for Windows VMs!"
      Write-Output "Info: Re-ip process ignored for this VM!" | Out-File -FilePath $LogName -Append
      Write-Host "Re-ip process ignored for this VM!"
      exit;      
    }

    #Start Linux VM ReIP
    Write-Output "Starting re-ip process for VM: $($TargetVmName)" | Out-File -FilePath $LogName -Append      
    Write-Host "Starting re-ip process for VM: $($TargetVmName)"
    $VMConfigOS = $VirtualMachine | Select-Object -ExpandProperty ExtensionData | Select-Object -ExpandProperty config        
    Write-Output "Guest OS Name:" | Out-File -FilePath $LogName -Append          
    $VMConfigOS.GuestFullName | Out-File -FilePath $LogName -Append 
    Write-Host "Guest OS Name:$($VMConfigOS.GuestFullName)"

    #Quering OS Family for Reip Rules...
    $GuestOSFamily = Get-OsFamily -GuestOSFullName $VMConfigOS.GuestFullName     
    If ($GuestOSFamily -eq "NotSupported")
    {
        Write-Output "Error: This Distro $($VMConfigOS.GuestFullName) is not supported by the script yet :("  | Out-File -FilePath $LogName -Append        
        Write-Error "This Distro $($VMConfigOS.GuestFullName) is not supported by the script yet :("        
        exit;
    }
    else 
    {
        Write-Output "$($VMConfigOS.GuestFullName) is supported by the script \0/"  | Out-File -FilePath $LogName -Append        
        Write-Host "$($VMConfigOS.GuestFullName) is supported by the script \0/"
    }
    
    #Finding re-ip rule for this VM
    $ReplicatedVM = Get-VBRJob -WarningAction SilentlyContinue | Where-Object {$_.JobType -eq "Replica"} | Get-VBRJobObject -Name $SourceVmName  
    $ReIp= Get-VBRJob -WarningAction SilentlyContinue | Where-Object {$_.Uid -like $ReplicatedVM[0].JobId.Guid} | Get-VBRViReplicaReIpRule 
    Write-Output "$($ReIp.Count) ReIP Rule(s) were found" | Out-File -FilePath $LogName -Append    
    Write-Host "$($ReIp.Count) ReIP Rule(s) were found"    

    #Colleting adtional information about source network config... (Prefix,GW,Etc)
    $GuestInfo = $VirtualMachine | Select-Object -ExpandProperty ExtensionData | Select-Object -ExpandProperty guest
      
    #Converting VM-IP into VM-IP-Masking like [10.10.1.100/24 to 10.10.1.*]
    $VMIpMask =  New-VmIpMask -IpAddress $SourceVmIp -Prefix $GuestInfo.Net.IpConfig.IpAddress[0].PrefixLength    
    $ReIPRule = $ReIp | Where-Object {$_.SourceIp -eq $VMIpMask} 
    IF (!$ReIPRule) 
    {
      Write-Output "Error: Re-IP rule compatible with source network '$VMIpMask' were not found:" | Out-File -FilePath $LogName -Append
      Write-Error "Re-IP rule compatible with source network '$VMIpMask' were not found:" 
      exit;
    }
    else
    {
      Write-Output "Info: The Re-IP rule selected is $($ReIPRule.Description,"-",$ReIPRule.SourceIp)"| Out-File -FilePath $LogName -Append
      Write-Host "The Re-IP rule selected is $($ReIPRule.Description,"-",$ReIPRule.SourceIp)."
    } 
           
    #Testing if VM Credential is not emput
    If (!$VmCred)
    {
        Write-Output "It's mandatory to have the parameter [VmCred] filled. It is necessary to to inject the new network config inside of the VM using VIX" | Out-File -FilePath $LogName -Append
        Write-Error "It's mandatory to have the parameter [VmCred] filled. It is necessary to to inject the new network config inside of the VM using VIX"
        exit;
    }
        
    #Creating IP data for replacing at config file
    #Creating the Target IP
    $OctToChange = $ReIPRule.TargetIp.split("*").Count -1
    switch ($OctToChange) 
    {
    1 {$NewIP = $ReIPRule.TargetIp.Replace(".*","")+"."+$SourceVmIp.Split(".")[3]}
    2 {$NewIP = $ReIPRule.TargetIp.Replace(".*","")+"."+$SourceVmIp.Split(".")[2]+"."+$SourceVmIp.Split(".")[3]  }
    3 {$NewIP = $ReIPRule.TargetIp.Replace(".*","")+"."+$SourceVmIp.Split(".")[1]+"."+$SourceVmIp.Split(".")[2]+"."+$SourceVmIp.Split(".")[3]}            
    }
    Write-Output "The new ip for the VM will be:$($NewIp)" | Out-File -FilePath $LogName -Append      
    Write-Host "The new ip for the VM will be:$($NewIp)"    

    #Making some Guest OS preparation necessary to run GuestOS Script inside VM.
    Write-Output "Preparating the Guest OS script to: $($GuestOSFamily,"-",$VMConfigOS.GuestFullName)" | Out-File -FilePath $LogName -Append
    Write-Host "Preparating the Guest OS script to: $($GuestOSFamily,"-",$VMConfigOS.GuestFullName)" | Out-File -FilePath $LogName -Append
    
    #Creating command line to imput inside of Guest OS.
    $Commandline = Set-IPAddress -OSFamily $GuestOSFamily `
    -SrcIP $SourceVmIp -TgtIP $NewIP `
    -SrcMask (New-NetMask -Prefix $GuestInfo.Net.IpConfig.IpAddress[0].PrefixLength) -TgtMask $ReIPRule.TargetMask `
    -SrcPrefix $GuestInfo.Net.IpConfig.IpAddress[0].PrefixLength -TgtPrefix (New-Prefix -IpAddress $ReIPRule.TargetMask) `
    -SrcGateway ($GuestInfo.ipstack.iprouteconfig.iproute.gateway.ipaddress | where-object {$_ -ne $null}) -TgtGateway $ReIPRule.TargetGateway.Trim() `
    -VM $VirtualMachine -VmCredential $VmCred `
    -Type Full

    #Running network config update
    Write-Output "Running this network re-ip script inside of the guest:" | Out-File -FilePath $LogName -Append    
    Write-Host "Running this network re-ip script inside of the guest:" 
    
    #Hiding the SUDO Password if is necessary.
    if (($GuestOSFamily -eq "UBDB") -or ($GuestOSFamily -eq "SLES"))    
    {
        $Commandline.Replace($VmCredPassword,"*********") | Out-File -FilePath $LogName -Append  -ErrorAction SilentlyContinue    
        Write-Host $Commandline.Replace($VmCredPassword,"*********") -ErrorAction SilentlyContinue
    }
    else {
        $Commandline | Out-File -FilePath $LogName -Append  -ErrorAction SilentlyContinue    
        Write-Host $Commandline
    }
    $cmd = ($VirtualMachine | Invoke-VMScript -ScriptText $Commandline -GuestCredential $VmCred).ScriptOutput.Trim() 
    $cmd | Out-File -FilePath $LogName -Append      
    Write-Host $Cmd
    
    #Testing if network is responsive
    $RouteCommand = Set-IPAddress -OSFamily $GuestOSFamily -VM $VirtualMachine -VmCredential $VmCred -Type Route
    $pinggw = @"
gw=`$($($RouteCommand))
ping -c4 `$gw | grep -Po "[[:digit:]]+ *(?=%)" 
"@    
    #Running the script 
    Write-Output "Testing Network Connectivity to default gateway:" | Out-File -FilePath $LogName -Append
    Write-Host "Testing Network Connectivity to default gateway:"
    Write-Output "Ping Command:`n $($pinggw)"  | Out-File -FilePath $LogName -Append
    Write-Host "Ping Command:`n $($pinggw)"

    $PingLinux = ($VirtualMachine | Invoke-VMScript -ScriptText $pinggw -GuestCredential $VmCred).ScriptOutput.Trim() 
    Write-Output "Packages Lost : $($PingLinux.Trim()) %" | Out-File -FilePath $LogName -Append
    Write-Host "Packages Lost : $($PingLinux.Trim()) %"

    Write-Host "Disconnecting from vCenter ..."
    Disconnect-VIServer -Server $VCenterFQDN -Force -confirm:$false | Out-File -FilePath $LogName -Append
    #Analysing the result
    if ($PingLinux -ne "0") 
      { 
          Write-Output "Error: Re-IP failed, please check the VM config!" | Out-File -FilePath $LogName -Append                                          
          Write-Error "Re-IP failed, please check the VM config!"
      } 
    else 
      {
        Write-Output  "Info: Successfully re-ip this VM! <o> \o/ <o>" | Out-File -FilePath $LogName -Append
        Write-Host  "Successfully re-ip this VM! <o> \o/ <o>" 
      } 
}
catch {
    Write-Error "Error to run this script"
    Write-Error $_.Exception.Message
}