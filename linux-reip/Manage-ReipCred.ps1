param(   
    [Parameter(Mandatory=$true)] 
    [ValidateSet("Add","Remove")]
    [string] $Action,
    [String] $ItemName = "vCenter",    
    [String] $Username = "Administrator@vsphere.local",
    [String] $Password = "Veeam123!",
    [Parameter(Mandatory=$true)]
    [ValidateSet("v","d","c")]
    [string] $Type    
)
#Installing the Credential Manager PS module if it doesn't exist yet
$PSModule = Get-Module CredentialManager -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
if (!$PSModule) 
{
    Install-Module -Name CredentialManager -Force -Confirm:$false
}
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
Function New-ReIpCredential
{
    param
    (
        [Parameter(Mandatory=$true)]
        [String] $ClearUserName,
        [Parameter(Mandatory=$true)]
        [String] $ClearPassword
    )
        $pwd = ConvertTo-SecureString $ClearPassword -AsPlainText -Force
        return New-Object System.Management.Automation.PSCredential -ArgumentList $ClearUserName,$pwd
}

#Generating the credential ID
switch ($type) 
{
    "v" {
        $credid = Get-StringHash -String "vCenter"                        
    }
    "c" {
        $credid = Get-StringHash -String $ItemName                         
    }
    default {
        $credid = Get-StringHash -String "Default"
    }
}
If ($Action -eq "Add") 
{
    New-StoredCredential -Comment $credid -Credentials (New-ReIpCredential -ClearUserName $Username.Trim() -ClearPassword $Password.Trim()) -Target $credid | Out-Null
}
If ($Action -eq "Remove") 
{
    Remove-StoredCredential -Target $credid | Out-Null
}

Get-StoredCredential



