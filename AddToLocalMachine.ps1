## This first part parses the computer. Our company uses a two letter prefix followed by the serial.
## You may have to modify it to fit your infastructure.

Set-ExecutionPolicy -ExecutionPolicy Bypass
$serial = gwmi win32_bios | Select –ExpandProperty SerialNumber
$name = 'MachinePrefix-' + $serial
$name
#$serial


#Create a scheduled task to add the machine to the collection after login.
ipmo ScheduledTasks
$action = New-ScheduledTaskAction -Execute '"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"' -Argument "http://sccm-server/PowerShellScriptService/PowerShellScriptService.asmx/RunScriptWithArgument?argument='$name'"
$trigger =  New-ScheduledTaskTrigger -AtLogOn
Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "Add To SCCM Collection" -Description "Add Computer to Dynamic Provisioning Collection" -User "SYSTEM" -Force
