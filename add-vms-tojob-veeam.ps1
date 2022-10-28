Add-PSSnapin VeeamPSSnapin
$vms = Import-Csv -Path C:\Instaladores\vms.csv
foreach($vm in $vms){
$ent= Find-VBRViEntity -Name $vm.name
Write-host "Adicionando:" $ent.name
Add-VBRViJobObject -Job "BkpJob_Linux(D30,TM)" -Entities $ent
}



