# ==============================================================================
# Tên File: SonDang_CoreX_V6_Cinematic.ps1
# Tác giả: Son Dang
# Phiên bản: 6.0 (Smart Scan & Cinematic UI Edition)
# Mô tả: Thuật toán kiểm tra trạng thái thông minh kèm giao diện
#        Thanh tiến trình mượt mà (Smooth Progress Bar).
# ==============================================================================

$ErrorActionPreference = 'SilentlyContinue'
$Host.UI.RawUI.WindowTitle = "SonDang CoreX - Smart Checker Protocol"

# 1. YÊU CẦU QUYỀN ADMINISTRATOR
If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Start-Process powershell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    Exit
}

# 2. GIAO DIỆN & ENGINE KIỂM TRA THÔNG MINH
Function Write-Log {
    param($Message, $Type="INFO")
    $Time = Get-Date -Format "HH:mm:ss.fff"
    if ($Type -eq "INFO") { Write-Host "[$Time] [ SYS ] $Message" -ForegroundColor Cyan }
    if ($Type -eq "SUCCESS") { Write-Host "[$Time] [ OK! ] $Message" -ForegroundColor Green }
    if ($Type -eq "RESULT") { Write-Host "  ↳ $Message" -ForegroundColor Yellow }
}

# Khởi tạo bộ đếm
$script:SkipCount = 0
$script:ApplyCount = 0

Function Reset-Counters { $script:SkipCount = 0; $script:ApplyCount = 0 }

# Engine: Kiem tra & Set Registry
Function Set-SmartReg {
    param($Path, $Name, $Value, $Type="REG_DWORD")
    $psPath = $Path -replace "^HKLM", "HKLM:" -replace "^HKCU", "HKCU:"
    $isOptimized = $false
    try {
        $curr = (Get-ItemProperty -Path $psPath -Name $Name -ErrorAction Stop).$Name
        if ($Type -eq "REG_BINARY") { $isOptimized = $false } 
        elseif ([string]$curr -eq [string]$Value) { $isOptimized = $true }
    } catch { }

    if ($isOptimized) { $script:SkipCount++ } 
    else {
        reg add "$Path" /v "$Name" /t $Type /d "$Value" /f >$null 2>&1
        $script:ApplyCount++
    }
}

# Engine: Kiem tra & Tat Service
Function Disable-SmartSvc {
    param($Name)
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if ($svc) {
        if ($svc.StartType -eq 'Disabled' -or $svc.StartType -eq 4) { $script:SkipCount++ } 
        else {
            sc.exe config $Name start= disabled >$null 2>&1
            sc.exe stop $Name >$null 2>&1
            $script:ApplyCount++
        }
    } else { $script:SkipCount++ } 
}

# Engine: Kiem tra & Tat Scheduled Task
Function Disable-SmartTask {
    param($TaskPath)
    $output = schtasks /query /tn "$TaskPath" /fo csv /nh 2>&1
    if ($output -match "Disabled" -or $output -match "ERROR:") { $script:SkipCount++ } 
    else {
        schtasks /change /tn "$TaskPath" /Disable >$null 2>&1
        $script:ApplyCount++
    }
}

# Engine: Kiem tra & Gỡ AppX
Function Remove-SmartApp {
    param($AppName)
    $app = Get-AppxPackage "*$AppName*" -ErrorAction SilentlyContinue
    if ($app) {
        Get-AppxPackage "*$AppName*" -AllUsers | Remove-AppxPackage -ErrorAction SilentlyContinue >$null 2>&1
        $script:ApplyCount++
    } else { $script:SkipCount++ }
}

Clear-Host
Write-Host @"
  _____             _____                   
 / ____|           |  __ \                  
| (___   ___  _ __ | |  | | __ _ _ __   __ _ 
 \___ \ / _ \| '_ \| |  | |/ _` | '_ \ / _` |
 ____) | (_) | | | | |__| | (_| | | | | (_| |
|_____/ \___/|_| |_|_____/ \__,_|_| |_|\__, |
                                        __/ |
                                       |___/ 
   SMART CHECKER OPTIMIZATION PROTOCOL INITIATED   
"@ -ForegroundColor Red
Start-Sleep -Seconds 2

# ==============================================================================
# ĐỊNH NGHĨA CÁC KHỐI TÁC VỤ
# ==============================================================================
$Tasks = @(
    @{
        Name = "Toi uu hoa Bao mat & Windows Update (Defender, SmartScreen)";
        Action = {
            $regKeys = @(
                "HKLM\Software\Policies\Microsoft\Windows Defender|DisableAntiSpyware|1",
                "HKLM\Software\Policies\Microsoft\Windows Defender|DisableBehaviorMonitoring|1",
                "HKLM\Software\Policies\Microsoft\Windows Defender|DisableIOAVProtection|1",
                "HKLM\Software\Policies\Microsoft\Windows Defender|DisableRealtimeMonitoring|1",
                "HKLM\SOFTWARE\Policies\Microsoft\Windows\System|EnablingSmartScreen|0",
                "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate|ExcludeWUDriversInQualityUpdate|1",
                "HKLM\Software\Policies\Microsoft\Windows\WindowsUpdate|DeferFeatureUpdates|1",
                "HKLM\Software\Microsoft\Windows\CurrentVersion\DriverSearching|SearchOrderConfig|0"
            )
            foreach ($k in $regKeys) { $p = $k.Split("|"); Set-SmartReg -Path $p[0] -Name $p[1] -Value $p[2] }
        }
    },
    @{
        Name = "Vo hieu hoa Telemetry, Cortana & Privacy";
        Action = {
            $telemetryKeys = @(
                "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection|AllowTelemetry|0",
                "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search|AllowCortana|0",
                "HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Search|DisableWebSearch|1",
                "HKLM\SOFTWARE\Policies\Microsoft\Windows\CloudContent|DisableWindowsConsumerFeatures|1",
                "HKLM\SOFTWARE\Policies\Microsoft\Windows\System|PublishUserActivities|0",
                "HKLM\SOFTWARE\Policies\Microsoft\Windows\System|UploadUserActivities|0",
                "HKLM\SOFTWARE\Policies\Microsoft\Windows\SettingSync|DisableSettingSync|2",
                "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\Search|BingSearchEnabled|0"
            )
            foreach ($k in $telemetryKeys) { $p = $k.Split("|"); Set-SmartReg -Path $p[0] -Name $p[1] -Value $p[2] }
            
            $svcs = @("DiagTrack", "dmwappushservice", "diagnosticshub.standardcollector.service", "WmiPrvSE")
            foreach ($s in $svcs) { Disable-SmartSvc -Name $s }
        }
    },
    @{
        Name = "Tat Process Mitigations & Exploit Protection (Tang cuong FPS)";
        Action = {
            $mitigations = @("dwm.exe","lsass.exe","svchost.exe","csrss.exe","SearchIndexer.exe","TrustedInstaller.exe")
            foreach ($m in $mitigations) {
                Set-SmartReg -Path "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$m" -Name "MitigationOptions" -Value "22222222222222222222222222222222" -Type "REG_BINARY"
            }
            Set-SmartReg -Path "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" -Name "FeatureSettingsOverride" -Value 3
            Set-SmartReg -Path "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" -Name "DisableExceptionChainValidation" -Value 1
            Set-SmartReg -Path "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" -Name "DisableTsx" -Value 1
            Set-SmartReg -Path "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager" -Name "ProtectionMode" -Value 0
        }
    },
    @{
        Name = "Toi uu Resource Policy Store (CPU Caps, Flags, Priority)";
        Action = {
            $cpuCaps = @("HardCap0","Paused","SoftCapFull","SoftCapLow")
            foreach ($c in $cpuCaps) {
                Set-SmartReg -Path "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\CPU\$c" -Name "CapPercentage" -Value 0
                Set-SmartReg -Path "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\CPU\$c" -Name "SchedulingType" -Value 0
            }
            $importance = @("Critical","CriticalNoUi","EmptyHostPPLE","High","Low","Lowest","Medium","MediumHigh","StartHost","VeryHigh","VeryLow")
            foreach ($i in $importance) {
                Set-SmartReg -Path "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\Importance\$i" -Name "BasePriority" -Value 82
                Set-SmartReg -Path "HKLM\SYSTEM\ResourcePolicyStore\ResourceSets\Policies\Importance\$i" -Name "OverTargetPriority" -Value 50
            }
        }
    },
    @{
        Name = "Cau hinh BCD, Timer & IO Responsiveness (Safe RAM)";
        Action = {
            bcdedit /set disabledynamictick yes >$null 2>&1
            bcdedit /deletevalue useplatformclock >$null 2>&1
            bcdedit /set useplatformtick yes >$null 2>&1
            bcdedit /set x2apicpolicy Enable >$null 2>&1
            
            Set-SmartReg -Path "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "Win32PrioritySeparation" -Value 38
            Set-SmartReg -Path "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "IRQ8Priority" -Value 1
            Set-SmartReg -Path "HKLM\SYSTEM\CurrentControlSet\Control\PriorityControl" -Name "IRQ16Priority" -Value 2
            Set-SmartReg -Path "HKCU\Control Panel\Desktop" -Name "MenuShowDelay" -Value "0" -Type "REG_SZ"
            fsutil behavior set disablelastaccess 1 >$null 2>&1
        }
    },
    @{
        Name = "Toi uu Network TCP/IP, Disable SMB & QoS Minecraft";
        Action = {
            netsh int tcp set global autotuninglevel=normal >$null 2>&1
            netsh int tcp set global dca=enabled >$null 2>&1
            Set-SmartReg -Path "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "TCPNoDelay" -Value 1
            Set-SmartReg -Path "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "TcpAckFrequency" -Value 1
            Set-SmartReg -Path "HKLM\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" -Name "TcpDelAckTicks" -Value 0
            
            Set-SmartReg -Path "HKLM\SOFTWARE\Policies\Microsoft\Windows\QoS\javaw.exe" -Name "DSCP Value" -Value 46
            Set-SmartReg -Path "HKLM\SOFTWARE\Policies\Microsoft\Windows\QoS\javaw.exe" -Name "Remote Port" -Value "25565" -Type "REG_SZ"
            
            Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart >$null 2>&1
            Disable-SmartSvc -Name "lmhosts"
            Set-SmartReg -Path "HKLM\System\CurrentControlSet\Control\Lsa" -Name "RestrictAnonymous" -Value 1
        }
    },
    @{
        Name = "Tinh chinh MMCSS, DirectX, GPU & CSRSS Realtime";
        Action = {
            $mmcss = @("Games", "Low Latency")
            foreach ($m in $mmcss) {
                Set-SmartReg -Path "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\$m" -Name "GPU Priority" -Value 8
                Set-SmartReg -Path "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\$m" -Name "Priority" -Value 6
                Set-SmartReg -Path "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\$m" -Name "Scheduling Category" -Value "High" -Type "REG_SZ"
                Set-SmartReg -Path "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\$m" -Name "Latency Sensitive" -Value "True" -Type "REG_SZ"
            }
            Set-SmartReg -Path "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe\PerfOptions" -Name "CpuPriorityClass" -Value 4
            Set-SmartReg -Path "HKLM\SOFTWARE\Microsoft\DirectDraw" -Name "UseNonLocalVidMem" -Value 1
            Set-SmartReg -Path "HKLM\SYSTEM\CurrentControlSet\Services\DXGKrnl" -Name "MonitorLatencyTolerance" -Value 0
        }
    },
    @{
        Name = "Unhide Power Attributes & Disable Storage Energy Savings";
        Action = {
            powercfg -h off >$null 2>&1
            $energy = @("SD","SSD")
            foreach ($e in $energy) {
                foreach ($i in 1..3) {
                    Set-SmartReg -Path "HKLM\SYSTEM\CurrentControlSet\Control\Power\EnergyEstimation\Storage\$e\IdleState\$i" -Name "IdlePowerMw" -Value 0
                }
            }
            powercfg -setacvalueindex scheme_current sub_processor CPMINCORES 100 >$null 2>&1
            powercfg -setacvalueindex scheme_current sub_processor PERFBOOSTMODE 1 >$null 2>&1
            powercfg -setacvalueindex scheme_current sub_processor PERFBOOSTPOL 100 >$null 2>&1
            powercfg -setactive scheme_current >$null 2>&1
            Set-SmartReg -Path "HKLM\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" -Name "PowerThrottlingOff" -Value 1
        }
    },
    @{
        Name = "Go bo Windows AppX Bloatware (Thuat toan Quet hang loat)";
        Action = {
            $Bloats = "BingWeather|GetHelp|Getstarted|Messaging|Microsoft3DViewer|MicrosoftSolitaireCollection|MicrosoftStickyNotes|MixedReality.Portal|OneConnect|People|Print3D|SkypeApp|WindowsAlarms|WindowsCamera|windowscommunicationsapps|WindowsMaps|WindowsFeedbackHub|WindowsSoundRecorder|YourPhone|ZuneMusic|HEIFImageExtension|WebMediaExtensions|WebpImageExtension|3dBuilder|bing|bingfinance|bingsports|CommsPhone|Drawboard PDF|Sway|WindowsPhone"
            $AppList = $Bloats -split "\|"
            foreach ($app in $AppList) { Remove-SmartApp -AppName $app }
        }
    },
    @{
        Name = "Disable GameDVR, Xbox Services & Scheduled Tasks Rac";
        Action = {
            $xboxSvcs = @("xbgm", "XblAuthManager", "XblGameSave", "XboxGipSvc", "XboxNetApiSvc")
            foreach ($x in $xboxSvcs) { Disable-SmartSvc -Name $x }
            
            Set-SmartReg -Path "HKCU\Software\Microsoft\GameBar" -Name "GameDVR_Enabled" -Value 0
            Set-SmartReg -Path "HKCU\Software\Microsoft\Windows\CurrentVersion\GameDVR" -Name "AppCaptureEnabled" -Value 0
            
            $tasks = @(
                "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
                "\Microsoft\Windows\Customer Experience Improvement Program\BthSQM",
                "\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask",
                "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
                "\Microsoft\Windows\Customer Experience Improvement Program\Uploader",
                "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
                "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
                "\Microsoft\Windows\Application Experience\StartupAppTask",
                "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector",
                "\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem",
                "\Microsoft\Windows\Maintenance\WinSAT"
            )
            foreach ($t in $tasks) { Disable-SmartTask -TaskPath $t }
        }
    }
)

# ==============================================================================
# VÒNG LẶP THỰC THI & HIỆU ỨNG TIẾN TRÌNH (CINEMATIC)
# ==============================================================================
$TotalTasks = $Tasks.Count
$PrevPercent = 0

for ($i = 0; $i -lt $TotalTasks; $i++) {
    $Task = $Tasks[$i]
    $TargetPercent = [math]::Round((($i + 1) / $TotalTasks) * 100)
    
    Reset-Counters
    
    # In Log bat dau khoi tac vu
    Write-Log "Dang xu ly: $($Task.Name)" "INFO"
    
    # 1. Hieu ung chay % (Gia lap qua trinh Quet/Scan)
    $MidPercent = [math]::Round(($PrevPercent + $TargetPercent) / 2)
    for ($p = $PrevPercent; $p -le $MidPercent; $p++) {
        Write-Progress -Activity "SonDang CoreX - Kiem tra & Toi uu" `
                       -Status "Dang quet he thong... [$p%]" `
                       -PercentComplete $p
        Start-Sleep -Milliseconds 60
    }
    
    # 2. Thuc thi Code thuc te (Rat nhanh)
    Invoke-Command -ScriptBlock $Task.Action
    
    # 3. Hieu ung chay % (Gia lap qua trinh Ap dung/Apply)
    for ($p = $MidPercent + 1; $p -le $TargetPercent; $p++) {
        Write-Progress -Activity "SonDang CoreX - Kiem tra & Toi uu" `
                       -Status "Dang ghi de Registry & Services... [$p%]" `
                       -PercentComplete $p
        Start-Sleep -Milliseconds 60
    }
    
    # 4. In Log ket qua sau moi block
    Write-Log "Hoan tat: Ap dung $script:ApplyCount muc moi (Bo qua $script:SkipCount muc da toi uu)." "RESULT"
    
    # 5. Tam dung 1 giay de nguoi dung kip doc report cua block do
    Start-Sleep -Seconds 1 
    
    $PrevPercent = $TargetPercent
}

# Hoan tat Progress Bar
Write-Progress -Activity "SonDang CoreX - Kiem tra & Toi uu" -Completed
Write-Log "TOAN BO HE THONG DA DUOC QUET VA TOI UU HOAN TAT!" "SUCCESS"

# Don dep cuoi cung
Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue

# ==============================================================================
# KẾT THÚC VÀ KHỞI ĐỘNG LẠI
# ==============================================================================
Write-Host "`n========================================================================" -ForegroundColor Magenta
Write-Host " [!] Yeu cau Khoi dong lai (Restart) de toan bo ma lenh an vao Windows." -ForegroundColor Yellow
Write-Host " [!] May tinh se tu dong Restart sau 10 giay..." -ForegroundColor Red
Write-Host " [!] Nhan Ctrl + C de huy khoi dong lai." -ForegroundColor Gray
Write-Host "========================================================================" -ForegroundColor Magenta

for ($i=10; $i -gt 0; $i--) {
    Write-Host -NoNewline "`rRebooting in $i seconds... "
    Start-Sleep -Seconds 1
}
Restart-Computer -Force