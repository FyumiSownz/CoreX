# ==============================================================================
# Ten File: SonDang_Tweaks.ps1
# Tac gia: SonDang
# Chuc nang: Toi uu hoa toan dien, don rac, giam do tre va tat dich vu ngam
# ==============================================================================

$ErrorActionPreference = 'SilentlyContinue'
$Host.UI.RawUI.WindowTitle = "SonDang - Ultimate Tweaking Tool"

# ==============================================================================
# 1. YEU CAU QUYEN ADMINISTRATOR
# ==============================================================================
If (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')) {
    Start-Process powershell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"{0}`"" -f $PSCommandPath) -Verb RunAs
    Exit
}

# ==============================================================================
# 2. GIAO DIEN & ENGINE KIEM TRA THONG MINH (PERCENTAGE PROGRESS)
# ==============================================================================
$script:SkipCount = 0
$script:ApplyCount = 0
$global:CurrentPercent = 0

Function Write-Log {
    param($Message, $Type="INFO")
    $Time = Get-Date -Format "HH:mm:ss"
    $Pct = $global:CurrentPercent.ToString().PadLeft(3)
    
    if ($Type -eq "INFO") { Write-Host "[$Time] [ $Pct% ] [ SYS ] $Message" -ForegroundColor Cyan }
    if ($Type -eq "SUCCESS") { Write-Host "`n[$Time] [ 100% ] [ OK! ] $Message" -ForegroundColor Green }
    if ($Type -eq "RESULT") { Write-Host "           -> $Message" -ForegroundColor Yellow }
    if ($Type -eq "SKIP") { Write-Host "           - [BO QUA] $Message" -ForegroundColor DarkGray }
    if ($Type -eq "APPLY") { Write-Host "           + [AP DUNG] $Message" -ForegroundColor White }
}

Function Draw-ProgressBar {
    param($ModuleName, $Percent)
    $FilledLength = [math]::Floor($Percent / 2)
    $EmptyLength = 50 - $FilledLength
    $Filled = "#" * $FilledLength
    $Empty  = "-" * $EmptyLength
    Write-Host "`n========================================================================" -ForegroundColor Magenta
    Write-Host " Tien trinh: [$Filled$Empty] $Percent%" -ForegroundColor Green
    Write-Host " Module    : $ModuleName" -ForegroundColor Magenta
    Write-Host "========================================================================" -ForegroundColor Magenta
}

Function Reset-Counters { $script:SkipCount = 0; $script:ApplyCount = 0 }

# Engine: Kiem tra & Set Registry thong minh
Function Set-SmartReg {
    param($Path, $Name, $Value, $Type="DWord")
    $psPath = $Path -replace "^HKLM\\", "HKLM:\" -replace "^HKCU\\", "HKCU:\" -replace "^Registry::", ""
    if (-not (Test-Path $psPath)) { New-Item -Path $psPath -Force | Out-Null }
    
    $isOptimized = $false
    try {
        $curr = (Get-ItemProperty -Path $psPath -Name $Name -ErrorAction Stop).$Name
        if ([string]$curr -eq [string]$Value) { $isOptimized = $true }
    } catch { }

    if ($isOptimized) { 
        $script:SkipCount++ 
    } else {
        Set-ItemProperty -Path $psPath -Name $Name -Value $Value -Type $Type -Force >$null 2>&1
        $script:ApplyCount++
        Write-Log "$Name -> $Value" "APPLY"
    }
}

# Engine: Kiem tra & Tat Service thong minh
Function Disable-SmartSvc {
    param($Name)
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if ($svc) {
        if ($svc.StartType -eq 'Disabled') { 
            $script:SkipCount++ 
        } else {
            Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue
            Set-Service -Name $Name -StartupType Disabled -ErrorAction SilentlyContinue
            $script:ApplyCount++
            Write-Log "Da tat dich vu: $Name" "APPLY"
        }
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
                                                                        
    Ultimate Tweaking Tool Made By Son Dang   
"@ -ForegroundColor Cyan
Start-Sleep -Seconds 2

# ==============================================================================
# 3. DINH NGHIA CAC KHOI TAC VU CHINH TU FILE NGUOI DUNG
# ==============================================================================
$Tasks = @(
    @{
        Name = "Don dep Temp, Recycle Bin & Cap nhat thiet bi (Clean System)";
        Action = {
            Write-Log "Quet tap tin tam thoi (Temp Files)..." "INFO"
            $pathGlobPattern = "$($directoryGlob = '%TEMP%'; if ($directoryGlob.EndsWith('*')) { $directoryGlob } elseif ($directoryGlob.EndsWith('\')) { "$($directoryGlob)*" } else { "$($directoryGlob)\*" } )"
            $expandedPath = [System.Environment]::ExpandEnvironmentVariables($pathGlobPattern)
            $deletedCount = 0; $failedCount = 0; $foundAbsolutePaths = @()
            try { $foundAbsolutePaths += @(Get-ChildItem -Path $expandedPath -Force -Recurse -ErrorAction Stop | Select-Object -ExpandProperty FullName) } catch { }
            try { $foundAbsolutePaths += @(Get-Item -Path $expandedPath -ErrorAction Stop | Select-Object -ExpandProperty FullName) } catch { }
            $foundAbsolutePaths = $foundAbsolutePaths | Select-Object -Unique | Sort-Object -Property { $_.Length } -Descending
            if ($foundAbsolutePaths) {
                foreach ($path in $foundAbsolutePaths) {
                    if (-not (Test-Path $path)) { $deletedCount++; continue }
                    try { Remove-Item -Path $path -Force -Recurse -ErrorAction Stop; $deletedCount++; $script:ApplyCount++ } catch { $failedCount++ }
                }
                Write-Log "Da don dep $deletedCount muc rac Temp." "APPLY"
            }

            Write-Log "Quet Thung rac (Recycle Bin)..." "INFO"
            if (Test-Path 'C:\$Recycle.Bin') {
                Remove-Item -Path 'C:\$Recycle.Bin\*' -Recurse -Force -ErrorAction SilentlyContinue
                $script:ApplyCount++
                Write-Log "Da lam trong thung rac (Recycle Bin)." "APPLY"
            }

            Write-Log "Quet thiet bi an/loi (PnP Devices)..." "INFO"
            $Devices = Get-PnpDevice | Where-Object { $_.Status -eq 'Unknown' }
            if ($Devices) {
                foreach ($Device in $Devices) {
                    & pnputil.exe /remove-device $Device.InstanceId | Out-Null
                    $script:ApplyCount++
                }
                Write-Log "Da go bo $($Devices.Count) thiet bi an/loi." "APPLY"
            } else { $script:SkipCount++ }
        }
    },
    @{
        Name = "Xoa File Log va Vo hieu hoa Prefetcher";
        Action = {
            Set-SmartReg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" "EnablingPrefetcher" 0 "DWord"
            
            Write-Log "Tim va xoa cac file .log trong he thong..." "INFO"
            Push-Location -Path "C:\Windows"
            $logs = Get-ChildItem -Path ".\*.log" -Recurse -Force -ErrorAction SilentlyContinue
            if ($logs.Count -gt 0) {
                $logs | Remove-Item -Force -ErrorAction SilentlyContinue
                $script:ApplyCount++
                Write-Log "Da xoa sach cac file .log trong Windows." "APPLY"
            } else { $script:SkipCount++ }
            Pop-Location
        }
    },
    @{
        Name = "Tat UAC & Toi uu hoa Ban phim/NumLock";
        Action = {
            Set-SmartReg "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System" "EnableLUA" 0 "DWord"
            Set-SmartReg "Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard" "InitialKeyboardIndicators" "2147483650" "String"
            Set-SmartReg "HKCU:\Control Panel\Keyboard" "KeyboardSpeed" "31" "String"
            Set-SmartReg "Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard" "InitialKeyboardIndicators" "2" "String"
            Set-SmartReg "HKCU:\Control Panel\Keyboard" "InitialKeyboardIndicators" "2" "String"
            Set-SmartReg "Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard" "KeyboardDelay" "0" "String"
            Set-SmartReg "Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard" "KeyboardSpeed" "31" "String"
        }
    },
    @{
        Name = "Toi uu Am thanh (MMCSS) va Chat luong hinh nen";
        Action = {
            $AudioPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Audio"
            Set-SmartReg $AudioPath "Background Only" "True" "String"
            Set-SmartReg $AudioPath "Clock Rate" 10000 "DWord"
            Set-SmartReg $AudioPath "GPU Priority" 12 "DWord"
            Set-SmartReg $AudioPath "Priority" 6 "DWord"
            Set-SmartReg $AudioPath "Scheduling Category" "Medium" "String"
            Set-SmartReg $AudioPath "SFIO Priority" "Normal" "String"
            Set-SmartReg "HKCU:\Control Panel\Desktop" "JPEGImportQuality" 100 "DWord"
        }
    },
    @{
        Name = "Vo hieu hoa cac Dich vu ngam (Advanced Services & WSearch)";
        Action = {
            $SvcList = @("DoSvc", "diagsvc", "DPS", "dmwappushservice", "MapsBroker", "lfsvc", "CscService", "SEMgrSvc", "PhoneSvc", "RemoteRegistry", "RetailDemo", "SysMain", "WalletService", "W32Time")
            foreach ($s in $SvcList) { Disable-SmartSvc -Name $s }

            Set-SmartReg "HKLM:\SYSTEM\CurrentControlSet\Services\MessagingService" "Start" 4 "DWord"
            Set-SmartReg "HKLM:\SYSTEM\ControlSet001\Services\WpnUserService" "Start" 4 "DWord"
            Disable-SmartSvc -Name "WSearch"
        }
    },
    @{
        Name = "Ep xung ngat MSI Mode cho Card Do hoa & O cung";
        Action = {
            Write-Log "Dang quet thiet bi phan cung de ep xung MSI Mode..." "INFO"
            $targets = Get-PnpDevice -PresentOnly | Where-Object { 
                $_.FriendlyName -like "*NVIDIA*" -or 
                $_.FriendlyName -like "*AMD*" -or 
                $_.FriendlyName -like "*SATA*" -or 
                $_.FriendlyName -like "*NVMe*" -or
                $_.FriendlyName -like "*Controller*"
            }
            foreach ($dev in $targets) {
                $path = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($dev.InstanceId)\Device Parameters\Interrupt Management"
                Set-SmartReg "$path\MessageSignaledInterruptProperties" "MSISupported" 1 "DWord"
                Set-SmartReg "$path\Affinity Policy" "DevicePriority" 3 "DWord"
            }
        }
    },
    @{
        Name = "Toi uu hoa PowerPlan (Fyumi Power Plan) & CPU";
        Action = {
            Write-Log "Cai dat Power Plan..." "INFO"
            $PlanName = "Fyumi Power Plan"
            $PlanDescription = "Made by SonDang"
            $ExistingPlan = powercfg /list | Where-Object { $_ -like "*$PlanName*" }
            $Guid = ""

            if ($ExistingPlan) {
                $Guid = ($ExistingPlan -split " ")[3]
                $script:SkipCount++
            } else {
                $Output = powercfg /duplicate 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c
                $Guid = ($Output -split " ")[4]
                powercfg /changename $Guid $PlanName $PlanDescription
                $script:ApplyCount++
            }
            powercfg /setactive $Guid | Out-Null

            Write-Log "Cai dat AC/DC Powercfg..." "INFO"
            powercfg.exe -setdcvalueindex scheme_current sub_processor PROCTHROTTLEMAX 100
            powercfg.exe -setdcvalueindex scheme_current sub_processor PROCTHROTTLEMIN 50
            Set-SmartReg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" "DistributeTimers" 1 "DWord"
            Set-SmartReg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" "DisableTsx" 1 "DWord"
            
            powercfg.exe -setacvalueindex scheme_current SUB_SLEEP AWAYMODE 0
            powercfg.exe -setacvalueindex scheme_current SUB_SLEEP ALLOWSTANDBY 0
            powercfg.exe -setacvalueindex scheme_current SUB_SLEEP HYBRIDSLEEP 0
            powercfg.exe -setacvalueindex scheme_current sub_processor PROCTHROTTLEMIN 100
            powercfg.exe /setACvalueindex scheme_current SUB_PROCESSOR SYSCOOLPOL 1
            powercfg.exe /setDCvalueindex scheme_current SUB_PROCESSOR SYSCOOLPOL 1

            $ProcessorPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Processor"
            Set-SmartReg $ProcessorPath "Cstates" 0 "DWord"
            Set-SmartReg $ProcessorPath "Capabilities" 516198 "DWord"

            $ControlSets = @("ControlSet001", "ControlSet002", "CurrentControlSet")
            $SubPath = "Control\Power\PowerSettings\54533251-82be-4824-96c1-47b60b740d00\0cc5b647-c1df-4637-891a-dec35c318583"
            foreach ($Set in $ControlSets) {
                Set-SmartReg "HKLM:\SYSTEM\$Set\$SubPath" "ValueMax" 0 "DWord"
                Set-SmartReg "HKLM:\SYSTEM\$Set\$SubPath" "ValueMin" 0 "DWord"
            }
            Set-SmartReg "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "CoreParkingDisablingd" 0 "DWord"
            powercfg.exe -setacvalueindex scheme_current sub_processor CPMINCORES 100

            Set-SmartReg "HKLM:\SYSTEM\CurrentControlSet\Services\IntelPPM" "Start" 3 "DWord"
        }
    },
    @{
        Name = "Tinh chinh Intel, CSRSS & Tat Autologgers";
        Action = {
            Write-Log "Tinh chinh he thong BCDedit..." "INFO"
            bcdedit.exe /set allowedinmemorysettings 0x0 | Out-Null
            bcdedit.exe /set isolatedcontext No | Out-Null
            $script:ApplyCount++

            Set-SmartReg "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "EventProcessorEnablingd" 0 "DWord"
            Set-SmartReg "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "EventProcessorEnabled" 0 "DWord"

            $CsrssPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe\PerfOptions"
            Set-SmartReg $CsrssPath "CpuPriorityClass" 4 "DWord"
            Set-SmartReg $CsrssPath "IoPriority" 4 "DWord"

            $Autologgers = @("AppModel", "Cellcore", "Circular Kernel Context Logger", "CloudExperienceHostOobe", "DataMarket", "DefenderApiLogger", "DefenderAuditLogger", "DiagLog", "HolographicDevice", "iclsClient", "iclsProxy", "LwtNetLog", "Mellanox-Kernel", "Microsoft-Windows-AssignedAccess-Trace", "Microsoft-Windows-Setup", "NBSMBLOGGER", "PEAuthLog", "RdrLog", "ReadyBoot", "SetupPlatform", "SetupPlatformTel", "SocketHeciServer", "SpoolerLogger", "SQMLogger", "TCPIPLOGGER", "TileStore", "Tpm", "TPMProvisioningService", "UBPM", "WdiContextLog", "WFP-IPsec Trace", "WiFiDriverIHVSession", "WiFiDriverIHVSessionRepro", "WiFiSession", "WinPhoneCritical")
            foreach ($Logger in $Autologgers) {
                Set-SmartReg "HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger\$Logger" "Start" 0 "DWord"
            }
            Set-SmartReg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WUDF" "LogEnable" 0 "DWord"
            Set-SmartReg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\WUDF" "LogLevel" 0 "DWord"
            Set-SmartReg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableThirdPartySuggestions" 1 "DWord"
            Set-SmartReg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableWindowsConsumerFeatures" 1 "DWord"
            Set-SmartReg "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\Credssp" "DebugLogLevel" 0 "DWord"
        }
    },
    @{
        Name = "Toi uu Kernel, DPC & Tre Driver (Latency Tweaks)";
        Action = {
            $DXGPath = "HKLM:\SYSTEM\CurrentControlSet\Services\DXGKrnl"
            Set-SmartReg $DXGPath "MonitorLatencyTolerance" 0 "DWord"
            Set-SmartReg $DXGPath "MonitorRefreshLatencyTolerance" 0 "DWord"

            $KernelPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel"
            Set-SmartReg $KernelPath "DpcWatchdogProfileOffset" 0 "DWord"
            Set-SmartReg $KernelPath "DisableExceptionChainValidation" 1 "DWord"
            Set-SmartReg $KernelPath "KernelSEHOPEnabled" 0 "DWord"
            Set-SmartReg $KernelPath "DisableAutoBoost" 0 "DWord"
            Set-SmartReg $KernelPath "DpcTimeout" 0 "DWord"
            Set-SmartReg $KernelPath "ThreadDpcEnable" 1 "DWord"
            Set-SmartReg $KernelPath "DpcWatchdogPeriod" 0 "DWord"
            Set-SmartReg $KernelPath "InterruptSteeringDisabled" 1 "DWord"

            Write-Log "Tim kiem IoLatencyCap trong Services..." "INFO"
            $ServicesPath = "Registry::HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services"
            Get-ChildItem -Path $ServicesPath -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Property -contains "IoLatencyCap" } | ForEach-Object {
                Set-SmartReg $_.PSPath "IoLatencyCap" 0 "DWord"
            }

            $PowerPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Power"
            Set-SmartReg $PowerPath "CoalescingTimerInterval" 0 "DWord"
            Set-SmartReg $PowerPath "QosManagesIdleProcessors" 0 "DWord"
            Set-SmartReg $PowerPath "DisableSensorWatchdog" 1 "DWord"
            Set-SmartReg $PowerPath "InterruptSteeringDisabled" 1 "DWord"
            Set-SmartReg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "RmDisableRegistryCaching" 1 "DWord"

            Set-SmartReg "HKLM:\SYSTEM\CurrentControlSet\Services\DXGKrnl\Parameters" "ThreadPriority" 15 "DWord"
            Set-SmartReg "HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\Parameters" "ThreadPriority" 15 "DWord"
        }
    },
    @{
        Name = "Toi uu hoa Mang TCP/IP, QoS & NetBIOS";
        Action = {
            $TcpipPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\ServiceProvider"
            Set-SmartReg $TcpipPath "LocalPriority" 4 "DWord"
            Set-SmartReg $TcpipPath "HostsPriority" 5 "DWord"
            Set-SmartReg $TcpipPath "DnsPriority" 6 "DWord"
            Set-SmartReg $TcpipPath "NetbtPriority" 7 "DWord"

            Write-Log "Cau hinh TCP Heuristics..." "INFO"
            & netsh interface tcp set heuristics disabled | Out-Null
            $script:ApplyCount++

            Write-Log "Cau hinh the mang TCP/IP NetBIOS..." "INFO"
            $NetworkAdapters = Get-WmiObject Win32_NetworkAdapterConfiguration -Filter "IPEnabled = 'True'"
            if ($NetworkAdapters) {
                foreach ($Adapter in $NetworkAdapters) {
                    $Adapter.SetTcpipNetbios(2) | Out-Null
                    $script:ApplyCount++
                }
            }
        }
    },
    @{
        Name = "Debloat - Chay kich ban go cai dat he thong (Win11Debloat)";
        Action = {
            Write-Log "Kiem tra chinh sach bao mat he thong..." "INFO"
            if ($ExecutionContext.SessionState.LanguageMode -ne "FullLanguage") {
                Write-Log "PowerShell execution is restricted by security policies. Skipping Debloat." "SKIP"
                return
            }

            $tempRootPath = $env:TEMP
            $tempWorkPath = Join-Path $tempRootPath 'Win11Debloat'
            $tempArchivePath = Join-Path $tempRootPath 'win11debloat.zip'

            Write-Log "Dang tai script Win11Debloat tu GitHub..." "INFO"
            try {
                $LatestReleaseUri = (Invoke-RestMethod https://api.github.com/repos/Raphire/Win11Debloat/releases/latest).zipball_url
                Invoke-RestMethod $LatestReleaseUri -OutFile $tempArchivePath
            } catch {
                Write-Log "Unable to fetch Win11Debloat from GitHub. Skipping." "SKIP"
                return
            }

            if (Test-Path $tempWorkPath) {
                Get-ChildItem -Path $tempWorkPath -Exclude CustomAppsList,LastUsedSettings.json,Win11Debloat.log,Config,Logs,Backups | Remove-Item -Recurse -Force
            }

            $configDir = Join-Path $tempWorkPath 'Config'
            $backupDir = Join-Path $tempWorkPath 'ConfigOld'

            if (Test-Path "$configDir") {
                New-Item -ItemType Directory -Path "$backupDir" -Force | Out-Null
                $filesToKeep = @('CustomAppsList', 'LastUsedSettings.json')
                Get-ChildItem -Path "$configDir" -Recurse | Where-Object { $_.Name -in $filesToKeep } | Move-Item -Destination "$backupDir"
                Remove-Item "$configDir" -Recurse -Force
            }

            Write-Log "Giai nen file ZIP Win11Debloat..." "INFO"
            Expand-Archive $tempArchivePath $tempWorkPath -Force
            Remove-Item $tempArchivePath -Force
            Get-ChildItem -Path (Join-Path $tempWorkPath 'Raphire-Win11Debloat-*') -Recurse | Move-Item -Destination $tempWorkPath -Force

            if (Test-Path "$backupDir") {
                if (-not (Test-Path "$configDir")) { New-Item -ItemType Directory -Path "$configDir" -Force | Out-Null }
                Get-ChildItem -Path "$backupDir" -Recurse | Move-Item -Destination "$configDir"
                Remove-Item "$backupDir" -Recurse -Force
            }

            $arguments = $($PSBoundParameters.GetEnumerator() | ForEach-Object {
                if ($_.Value -eq $true) { "-$($_.Key)" } else { "-$($_.Key) ""$($_.Value)""" }
            })

            $windowStyle = if ($arguments.Count -eq 0) { "Minimized" } else { "Normal" }

            if ($PSVersionTable.PSVersion.Major -ge 7) {
                $NewPSModulePath = $env:PSModulePath -split ';' | Where-Object -FilterScript { $_ -like '*WindowsPowerShell*' }
                $env:PSModulePath = $NewPSModulePath -join ';'
            }

            Write-Log "Dang thuc thi Win11Debloat (Cua so an)..." "INFO"
            $debloatScriptPath = Join-Path $tempWorkPath 'Win11Debloat.ps1'
            $debloatProcess = Start-Process powershell.exe -WindowStyle $windowStyle -PassThru -ArgumentList "-executionpolicy bypass -File `"$debloatScriptPath`" $arguments" -Verb RunAs

            if ($null -ne $debloatProcess) { $debloatProcess.WaitForExit() }

            if (Test-Path $tempWorkPath) {
                Get-ChildItem -Path $tempWorkPath -Exclude CustomAppsList,LastUsedSettings.json,Win11Debloat.log,Win11Debloat-Run.log,Config,Logs,Backups | Remove-Item -Recurse -Force
            }
            $script:ApplyCount++
            Write-Log "Hoan thanh chay Win11Debloat Custom." "APPLY"
        }
    },
    @{
        Name = "Khoi All-In-One (Xac minh vong cuoi theo yeu cau)";
        Action = {
            Set-SmartReg "HKLM:\SYSTEM\CurrentControlSet\Control\Processor" "Cstates" 0 "DWord"
            Set-SmartReg "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" "PowerThrottlingOff" 1 "DWord"
            Set-SmartReg "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "EventProcessorEnabled" 0 "DWord"
            Set-SmartReg "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "PlatformAoAcOverride" 0 "DWord"
            
            Set-SmartReg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" "CoalescingTimerInterval" 0 "DWord"
            Set-SmartReg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Executive" "CoalescingTimerInterval" 0 "DWord"
            Set-SmartReg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" "DistributeTimers" 1 "DWord"

            Write-Log "Xac minh BCDedit System Timer..." "INFO"
            bcdedit /set disabledynamictick yes | Out-Null
            bcdedit /set useplatformtick yes | Out-Null
            bcdedit /deletevalue useplatformclock >$null 2>&1
            bcdedit /set tpmbootentropy ForceDisable | Out-Null
            bcdedit /set vsmlaunchtype Off | Out-Null

            Set-SmartReg "HKLM:\Software\Policies\Microsoft\Windows\DeviceGuard" "EnableVirtualizationBasedSecurity" 0 "DWord"
            Set-SmartReg "HKLM:\Software\Policies\Microsoft\Windows\DeviceGuard" "HVCIMATRequired" 0 "DWord"
            
            Set-SmartReg "HKLM:\SYSTEM\CurrentControlSet\Services\DXGKrnl\Parameters" "ThreadPriority" 15 "DWord"
            Set-SmartReg "HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\Parameters" "ThreadPriority" 15 "DWord"
            Set-SmartReg "HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\NVTweak" "DisplayPowerSaving" 0 "DWord"
            Set-SmartReg "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000" "RMIntrDetailedLogs" 0 "DWord"
            Set-SmartReg "HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm" "RmGpsPsEnablePerCpuCoreDpc" 1 "DWord"
            
            Set-SmartReg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "SystemResponsiveness" 0 "DWord"
            Set-SmartReg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" 4294967295 "DWord"
            Set-SmartReg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "GPU Priority" 8 "DWord"
            Set-SmartReg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "Priority" 6 "DWord"
            Set-SmartReg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" "Scheduling Category" "High" "String"

            try { Disable-MMAgent -MemoryCompression -ErrorAction SilentlyContinue; $script:ApplyCount++ } catch {}
            Set-SmartReg "HKLM:\SYSTEM\CurrentControlSet\Services\Ndu" "Start" 4 "DWord"
            Set-SmartReg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" "EnablePrefetcher" 0 "DWord"
            Set-SmartReg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" "EnableSuperfetch" 0 "DWord"
            Set-SmartReg "HKLM:\SYSTEM\CurrentControlSet\Control\Classpnp" "NVMeDisablePerfThrottling" 1 "DWord"
            Set-SmartReg "HKLM:\SYSTEM\CurrentControlSet\Services\stornvme\Parameters\Device" "IdlePowerMode" 0 "DWord"

            Write-Log "Xac minh Network TCP Options..." "INFO"
            & netsh int tcp set global ecncapability=disabled | Out-Null
            & netsh int tcp set global timestamps=disabled | Out-Null
            & netsh int tcp set global rss=enabled | Out-Null
            & netsh int tcp set global rsc=disabled | Out-Null
            $script:ApplyCount++

            Set-SmartReg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe\PerfOptions" "CpuPriorityClass" 4 "DWord"
            Set-SmartReg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\csrss.exe\PerfOptions" "IoPriority" 4 "DWord"
            Set-SmartReg "HKLM:\SYSTEM\CurrentControlSet\Services\HidUsb\Parameters" "ThreadPriority" 31 "DWord"
            Set-SmartReg "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters" "MouseDataQueueSize" 23 "DWord"
            Set-SmartReg "HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters" "KeyboardDataQueueSize" 23 "DWord"
            Set-SmartReg "HKCU:\Control Panel\Mouse" "MouseSpeed" "0" "String"
            Set-SmartReg "HKCU:\Control Panel\Mouse" "MouseThreshold1" "0" "String"
            Set-SmartReg "HKCU:\Control Panel\Mouse" "MouseThreshold2" "0" "String"
            Set-SmartReg "HKCU:\Control Panel\Desktop" "MenuShowDelay" "0" "String"

            Set-SmartReg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 0 "DWord"
            Set-SmartReg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" 1 "DWord"
            Set-SmartReg "HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications" "GlobalUserDisabled" 1 "DWord"
            Set-SmartReg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "AllowCortana" 0 "DWord"
            Set-SmartReg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "DisableWebSearch" 1 "DWord"
            Set-SmartReg "HKCU:\System\GameConfigStore" "GameDVR_Enabled" 0 "DWord"
            Set-SmartReg "HKLM:\Software\Policies\Microsoft\Windows\GameDVR" "AllowgameDVR" 0 "DWord"
        }
    },
    @{
        Name = "Tai va chay MSI Utility V3 (Buoc Cuoi Cung)";
        Action = {
            Write-Log "Dang ket noi voi GitHub de tai MSI Utility V3..." "INFO"
            $url = "https://github.com/Sathango/Msi-Utility-v3/raw/refs/heads/main/Msi%20Utility%20v3.exe"
            $dest = "$env:TEMP\Msi_Utility_v3.exe"
            
            try {
                Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
                Write-Log "Tai thanh cong! Dang mo MSI Utility..." "APPLY"
                Write-Log "=======================================================" "RESULT"
                Write-Log " CHU Y: Script dang TAM DUNG de ban cau hinh MSI Utility!" "RESULT"
                Write-Log " 1. Hay tich vao o 'MSI' cho NVIDIA RTX 2060 Super." "RESULT"
                Write-Log " 2. Chon muc Interrupt Priority thanh 'High'." "RESULT"
                Write-Log " 3. Nhan Apply, sau do TAT (X) CUA SO ung dung di." "RESULT"
                Write-Log "=======================================================" "RESULT"
                
                # Su dung -Wait de buoc PowerShell phai dung lai doi den khi app duoc tat
                Start-Process -FilePath $dest -Verb RunAs -Wait
                $script:ApplyCount++
                Write-Log "Da nhan dien viec dong MSI Utility. Tiep tuc..." "INFO"
            } catch {
                Write-Log "Khong the tai hoac chay MSI Utility V3: $_" "SKIP"
            }
        }
    }
)

# ==============================================================================
# 4. VONG LAP CHAY PROGRESS BAR & THUC THI (ENGINE)
# ==============================================================================
$TotalTasks = $Tasks.Count

For ($i = 0; $i -lt $TotalTasks; $i++) {
    $CurrentTask = $Tasks[$i]
    $global:CurrentPercent = [math]::Round((($i) / $TotalTasks) * 100)
    
    # Ve thanh tien trinh (ProgressBar) bang Text cuc ngau truoc khi chay tung Module
    Draw-ProgressBar $CurrentTask.Name $global:CurrentPercent
    Reset-Counters

    # Thuc thi doan code - Phan tram % se duoc update kem vao moi dong Log
    & $CurrentTask.Action
    
    Write-Log "Hoan tat module: Ap dung $script:ApplyCount tinh chinh (Bo qua $script:SkipCount muc da co truoc do)." "RESULT"
}

# Ve thanh tien trinh 100% cuoi cung
$global:CurrentPercent = 100
Draw-ProgressBar "HOAN TAT TOAN BO" 100
Write-Log "TOAN BO MA LENH DA DUOC NAP VA TOI UU HOAN TAT CHO I5-12400F & RTX 2060 SUPER!" "SUCCESS"

# ==============================================================================
# 5. KET THUC VA KHOI DONG LAI
# ==============================================================================
Write-Host "`n========================================================================" -ForegroundColor Green
Write-Host " [!] Yeu cau Khoi dong lai (Restart) de toan bo ma lenh an sau vao Windows." -ForegroundColor Yellow
Write-Host " [!] May tinh se tu dong Restart sau 15 giay..." -ForegroundColor Red
Write-Host " [!] Nhan Ctrl + C de huy qua trinh khoi dong lai." -ForegroundColor Gray
Write-Host "========================================================================" -ForegroundColor Green

Start-Sleep -Seconds 15
Restart-Computer -Force