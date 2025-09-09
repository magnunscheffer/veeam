Param(
    #VBR Prod info
    #[Parameter(Mandatory=$false)]
    [String]$vbrServer,    
    #VBR Prod Credential
    [string]$vbrUsername,
    [string]$vbrPassword ,  
    [string]$SOBR
)

Write-Host "Enabling the Repository $($repoName) on the VBR server:$($vbrProdServer) "
Connect-VBRServer -Server $vbrServer -User $vbrUsername -Password $vbrPassword -ForceAcceptTlsCertificate

try
{
    $scaleoutrepository = Get-VBRBackupRepository -ScaleOut -Name $SOBR
    $extents = Get-VBRRepositoryExtent -Repository $scaleoutrepository
    foreach ($item in $extents) 
    {
         Disable-VBRRepositoryExtentMaintenanceMode -Extent $item
    }
    
}
catch
{
    Write-Host "Failed to enable the SOBR"
    Write-Error $_    
}
Disconnect-VBRServer

