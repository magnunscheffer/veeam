param(
    [Parameter(Mandatory=$true)]
    [string]$VBRServer,

    [Parameter(Mandatory=$true)]
    [string]$SOBR,

    [Parameter(Mandatory=$true)]
    [string]$VBRUsername,

    [Parameter(Mandatory=$true)]
    [string]$VBRPassword
)

# Converte a senha para SecureString
$Password = $VBRPassword | ConvertTo-SecureString -AsPlainText -Force
$VBR = New-Object System.Management.Automation.PSCredential ($VBRUsername, $Password)

# Habilita o PowerShell Remoting e configura o cliente WinRM
Enable-PSRemoting -Force
winrm set winrm/config/client '@{AllowUnencrypted="true"}'
Set-Item WSMan:\localhost\Client\TrustedHosts -Value $VBRServer -Force

# Cria a sessão remota
$Session = New-PSSession -ComputerName $VBRServer -Credential $VBR
Write-Host "Putting the SOBR '$SOBR' in maintenance mode..."

try {
    $result = Invoke-Command -Session $Session -ScriptBlock {
        param($SOBRName)
        Write-Host "Processing SOBR: $SOBRName"
        $scaleoutrepository = Get-VBRBackupRepository -ScaleOut -Name $SOBRName
        $extents = Get-VBRRepositoryExtent -Repository $scaleoutrepository
        foreach ($item in $extents) {
            Write-Host "Enabling maintenance mode for extent: $($item.Name)"
            Enable-VBRRepositoryExtentMaintenanceMode -Extent $item
        }
    } -ArgumentList $SOBR -ErrorAction Stop

    Write-Host "✅ Command executed successfully."
    Write-Host $result
}
catch {
    Write-Host "❌ Command failed: $($_.Exception.Message)"
}
finally {
    Remove-PSSession $Session
    Write-Host "🔒 Remote session closed."
}