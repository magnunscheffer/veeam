Param(
    #VBR info
    #[Parameter(Mandatory=$false)]
    [String]$vbrServer,    
    #VBR Credential
    [string]$vbrUsername,
    [string]$vbrPassword ,    
    #Repository info
    [String]$repoServer,    
    #Repository Credential
    [string]$sshUsername,
    [string]$sshPassword ,
    #Root Password
    [string]$rootPassword ,
    #Repository Data
    [string]$repoName ,
    [string]$repoPath ,
    [string]$immutability,        
    #Log Path
    [string]$Path = "C:\Scripts\"
)

Write-Host "Connecting the repository $($repoName) to the VBR server $($vbrServer)"
Connect-VBRServer -Server $vbrServer -User $vbrUsername -Password $vbrPassword -ForceAcceptTlsCertificate
Write-Host "Adding Repository Server $($repoServer) with temporary user $($sshUsername), with backups stored in $($repoPath)"
try
{
    $linuxServer = Add-VBRLinux -Name $repoServer -SSHUser $sshUsername -SSHPassword $sshPassword -SSHElevateToRoot -SSHTempCredentials -SSHFailoverToSu -SSHRootPassword $rootPassword
	Add-VBRBackupRepository -Folder $repoPath -Type Hardened -Name $repoName -Server $linuxServer -EnableBackupImmutability -ImmutabilityPeriod $immutability -EnableXFSFastClone
}
catch
{
    Write-Host "Error to add the new repository"
    Write-Error $_
}

Write-Host "Scanning for backups in $($repoServer) stored in $($repoPath)"
try
{
	$repository = Get-VBRBackupRepository -Name  $repoName
	Sync-VBRBackupRepository -Repository $repository
}
catch
{
    Write-Host "Failed to scanning the new repository"
    Write-Error $_    
}
Disconnect-VBRServer