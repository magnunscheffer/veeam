Param(
    #Repository Data
    [string]$repository      
)

Write-Host "Scanning for backups in $($repository)"
try
{
	$repository = Get-VBRBackupRepository -Name  $repository
	Sync-VBRBackupRepository -Repository $repository
}
catch
{
    Write-Host "Failed to scanning the repository"
    Write-Error $_    
}
