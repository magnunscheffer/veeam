param(
  #New Network IP Range, for example: '172.16.1' or '10.10.254'
  [Parameter(Mandatory=$true)]
  [String]$nip, 

  #New Network Prefix, for example: '24' or '25'
  [Parameter(Mandatory=$true)]
  [String]$nprefix, 

  #VM Name in vCenter, for example "DC01" or "SRV01"
  [Parameter(Mandatory=$true)]
  [String]$vi_vmname, 

  #Guest username, for example "root" or "admin"
  [Parameter(Mandatory=$true)]
  [String]$guest_usr, 

  #Guest Password
  [Parameter(Mandatory=$true)]
  [String]$g_pwd, 

  #vCenter usernamme
  [String]$vi_usr= "administrator@vsphere.local",

  #vCenter Password
  [String]$v_pwd = "P@ssw0rd!",

  #vCenter FQDN
  [String]$vi_srv = "vcenter.domain.local" 
)

#Convert the PlainText PW and User to a Credential.
$vi_pwd = ConvertTo-SecureString $v_pwd -AsPlainText -Force
$vi_cred = New-Object System.Management.Automation.PSCredential -ArgumentList $vi_usr, $vi_pwd


#Creating the guest credential
$guest_pwd = ConvertTo-SecureString $g_pwd -AsPlainText -Force
$guest_cred = New-Object System.Management.Automation.PSCredential -ArgumentList $guest_usr, $guest_pwd

#Connecting to the vCenter Server
Connect-VIServer -Server $vi_srv -Credential $vi_cred -force 

#Inform the VM Name
$VM = Get-VM -Name $vi_vmname
Write-Host $VM "Is the VM"

$VMGest = $VM | Select -ExpandProperty ExtensionData | Select -ExpandProperty guest

$VMGest.Net.IpConfig.IpAddress[0].PrefixLength
$VMGest.Net.IpConfig.IpAddress[0].IpAddress

#Discoverying the Old Range based in the new range
$DotCount = ($nip.ToCharArray() | Where-Object {$_ -eq '.'} | Measure-Object).Count
$Oip = $($VMGest.Net.IpConfig.IpAddress[0].IpAddress).Split(".")[0..$DotCount] -join "."

#Recreating the old NetMask
$dec = [Convert]::ToUInt32($(("1" * $VMGest.Net.IpConfig.IpAddress[0].PrefixLength).PadRight(32, "0")), 2)
$DottedIP = $( For ($i = 3; $i -gt -1; $i--) {
        $Remainder = $dec % [Math]::Pow(256, $i)
        ($dec - $Remainder) / [Math]::Pow(256, $i)
        $dec = $Remainder
    } )
$OMask = [String]::Join('.', $DottedIP)

#Creating the new Mask
$decn = [Convert]::ToUInt32($(("1" * $nprefix).PadRight(32, "0")), 2)
$DottedIPN = $( For ($i = 3; $i -gt -1; $i--) {
        $Remainder = $decn % [Math]::Pow(256, $i)
        ($decn - $Remainder) / [Math]::Pow(256, $i)
        $decn = $Remainder
    } )
$NMask = [String]::Join('.', $DottedIPN)

#Script to try ping default gw.
$script = @'
gw=$(route -n | grep UG | awk '{print $2;}')
ping -c4 $gw | grep -Po "[[:digit:]]+ *(?=%)"  
'@


#$VM | Invoke-VMScript -ScriptText $script -GuestCredential $credential
#Running the script 
$pl = ($VM | Invoke-VMScript -ScriptText $script -GuestCredential $guest_cred).ScriptOutput.Trim() 

#Analysing the result
if ($pl -eq "0") 
    { 
        echo Not necessary change the IP Address 
    } 
else 
    {
        echo "running the script"
        $fixip="sed -i `"s/IPADDR=$($Oip)/IPADDR=$($nip)/`" /etc/sysconfig/network-scripts/ifcfg-ens192"
        $fixgw="sed -i `"s/GATEWAY=$($Oip)/GATEWAY=$($nip)/`" /etc/sysconfig/network-scripts/ifcfg-ens192"
        $fixmask="sed -i `"s/NETMASK=$($Omask)/NETMASK=$($Nmask)/`" /etc/sysconfig/network-scripts/ifcfg-ens192"
        $fixPrefix="sed -i `"s/PREFIX=$($VMGest.Net.IpConfig.IpAddress[0].PrefixLength)/PREFIX=$($nprefix)/`" /etc/sysconfig/network-scripts/ifcfg-ens192"
        $VM | Invoke-VMScript -ScriptText $fixip -GuestCredential $guest_cred  | Out-Null
        $VM | Invoke-VMScript -ScriptText $fixgw -GuestCredential $guest_cred  | Out-Null       
        $VM | Invoke-VMScript -ScriptText $fixmask -GuestCredential $guest_cred | Out-Null
        $VM | Invoke-VMScript -ScriptText $fixprefix -GuestCredential $guest_cred | Out-Null
        $VM | Invoke-VMScript -ScriptText 'systemctl restart network' -GuestCredential $guest_cred 
    } 

Disconnect-VIServer -Server $vi_srv -Force -Confirm:$false
