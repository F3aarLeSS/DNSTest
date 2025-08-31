#!/usr/bin/env pwsh
#
# Windows_DNS_Benchmark.ps1
#
# A PowerShell script to install Chocolatey & dependencies (if missing), then run a latency
# test against popular DNS servers and display a summary of the top 3.

# --- Strict Mode & Environment Setup ---
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# --- ANSI Escape Codes for Styling ---
$script:RESET = "`e[0m"
$script:BOLD = "`e[1m"
$script:DIM = "`e[2m"
$script:FG_RED = "`e[31m"
$script:FG_GREEN = "`e[32m"
$script:FG_YELLOW = "`e[33m"
$script:FG_BLUE = "`e[34m"
$script:FG_MAGENTA = "`e[35m"
$script:FG_CYAN = "`e[36m"
$script:FG_WHITE = "`e[37m"
$script:FG_GRAY = "`e[90m"
$script:FG_BROWN = "`e[38;5;130m"
$script:FG_ORANGE = "`e[38;5;214m"
$script:FG_BRIGHT_WHITE = "`e[97m"

# --- Global Variables & Cleanup ---
$script:TERMINAL_COLS = [Console]::WindowWidth
$script:BOX_WIDTH = 96
$script:CENTER_OFFSET = [Math]::Max(0, [Math]::Floor(($TERMINAL_COLS - $BOX_WIDTH) / 2))

# Create secure temporary files for results
$script:TMP_RESULTS = [System.IO.Path]::GetTempFileName()
$script:CLEAN_RESULTS = [System.IO.Path]::GetTempFileName()
$script:TOP_3_RESULTS = [System.IO.Path]::GetTempFileName()

# Cleanup function
function Cleanup {
    Write-Host "$RESET" -NoNewline
    Remove-Item -Path $TMP_RESULTS, $CLEAN_RESULTS, $TOP_3_RESULTS -Force -ErrorAction SilentlyContinue
}

# Register cleanup for script exit
Register-EngineEvent PowerShell.Exiting -Action { Cleanup }

# --- Centering Helper Functions ---
function Center-Print {
    param([string]$Content)
    Write-Host (" " * $CENTER_OFFSET + $Content)
}

function Center-Printf {
    param([string]$Format, [object[]]$Args)
    $content = $Format -f $Args
    Center-Print $content
}

# --- Installation Banner Functions ---
function Show-InstallationBanner {
    param(
        [string]$Title,
        [string]$Subtitle = ""
    )
    
    Write-Host ""
    Center-Printf "$BOLD$FG_CYAN╔══════════════════════════════════════════════════════════════════════════════╗"
    Center-Printf "$BOLD$FG_CYAN║                                                                              ║"
    Center-Printf "$BOLD$FG_CYAN║                            🚀 DNS BENCHMARK SETUP 🚀                         ║"
    Center-Printf "$BOLD$FG_CYAN║                                                                              ║"
    Center-Printf "$BOLD$FG_CYAN╠══════════════════════════════════════════════════════════════════════════════╣"
    Center-Printf "$BOLD$FG_CYAN║                                                                              ║"
    Center-Printf "$BOLD$FG_CYAN║  %-74s  ║$RESET" $Title
    if ($Subtitle) {
        Center-Printf "$BOLD$FG_CYAN║  %-74s  ║$RESET" $Subtitle
    }
    Center-Printf "$BOLD$FG_CYAN║                                                                              ║"
    Center-Printf "$BOLD$FG_CYAN╚══════════════════════════════════════════════════════════════════════════════╝$RESET"
    Write-Host ""
}

function Simple-Spinner {
    param(
        [string]$Message,
        [scriptblock]$Action
    )
    
    $spinnerChars = @("⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏")
    $i = 0
    $job = Start-Job -ScriptBlock $Action
    
    while ($job.State -eq "Running") {
        $spinnerChar = $spinnerChars[$i % $spinnerChars.Length]
        Write-Host ("`r" + " " * $CENTER_OFFSET + "$FG_YELLOW$spinnerChar$RESET $Message...") -NoNewline
        Start-Sleep -Milliseconds 200
        $i++
    }
    
    $result = Receive-Job -Job $job -Wait
    $exitCode = $job.State -eq "Completed"
    Remove-Job -Job $job
    
    if ($exitCode) {
        Write-Host ("`r" + " " * $CENTER_OFFSET + "$FG_GREEN✔$RESET $Message... ${FG_GREEN}Complete!$RESET")
    } else {
        Write-Host ("`r" + " " * $CENTER_OFFSET + "$FG_RED✖$RESET $Message... ${FG_RED}Failed!$RESET")
    }
    
    return $exitCode
}

# --- Core Logic ---
function Ensure-Dependencies {
    # Check if Chocolatey is installed
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Show-InstallationBanner "Installing Chocolatey Package Manager" "This may take a few minutes and require administrator privileges..."
        
        Center-Printf "$FG_YELLOW🍫 Starting Chocolatey installation...$RESET"
        Center-Printf "$FG_BLUE   You may be prompted for administrator privileges.$RESET"
        Write-Host ""
        
        # Install Chocolatey
        try {
            Set-ExecutionPolicy Bypass -Scope Process -Force
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
            # Refresh environment path after installation
            $env:PATH = [Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [Environment]::GetEnvironmentVariable("PATH", "User")
        } catch {
            Write-Host ""
            Center-Printf "$FG_RED❌ Chocolatey installation failed. Continuing with basic visuals.$RESET"
            Start-Sleep 2
            return
        }
        
        Write-Host ""
        Center-Printf "$FG_GREEN🎉 Chocolatey installation completed successfully!$RESET"
        Start-Sleep 1
    }
    
    # Verify Chocolatey is now available
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host ""
        Center-Printf "$FG_RED❌ Chocolatey installation failed. Continuing with basic visuals.$RESET"
        Start-Sleep 2
        return
    }
    
    # Check for missing packages
    $missingPackages = @()
    $packages = @("winfetch", "figlet")
    
    foreach ($pkg in $packages) {
        if (-not (Get-Command $pkg -ErrorAction SilentlyContinue)) {
            $missingPackages += $pkg
        }
    }
    
    # Install missing packages if any
    if ($missingPackages.Count -gt 0) {
        Show-InstallationBanner "Installing Required Dependencies" "Installing: $($missingPackages -join ', ')"
        
        Center-Printf "$FG_YELLOW📦 Installing dependencies for enhanced visuals...$RESET"
        Write-Host ""
        
        # Install each package
        $failedPackages = @()
        foreach ($pkg in $missingPackages) {
            Center-Printf "$FG_BLUE📦 Installing $BOLD$pkg$RESET$FG_BLUE...$RESET"
            
            $success = Simple-Spinner "Installing $pkg" {
                try {
                    choco install $using:pkg -y --no-progress | Out-Null
                    return $true
                } catch {
                    return $false
                }
            }
            
            if (-not $success) {
                $failedPackages += $pkg
            }
            Write-Host ""
        }
        
        # Report results
        $successfulCount = $missingPackages.Count - $failedPackages.Count
        if ($successfulCount -gt 0) {
            Center-Printf "$FG_GREEN🎉 Successfully installed $successfulCount package(s)!$RESET"
        }
        
        if ($failedPackages.Count -gt 0) {
            Center-Printf "$FG_YELLOW⚠️  Some packages failed to install: $($failedPackages -join ', ')$RESET"
            Center-Printf "$FG_YELLOW   Continuing with reduced visuals...$RESET"
        } else {
            Center-Printf "$FG_CYAN🌟 Enhanced visuals are now available!$RESET"
        }
        
        Start-Sleep 2
    }
}

# --- Visual Helper Functions ---
function Print-Header {
    param(
        [string]$Title,
        [string]$Color = $FG_BLUE
    )
    
    $titleWithSpaces = " $Title "
    $padLen = [Math]::Max(0, [Math]::Floor(($BOX_WIDTH - $titleWithSpaces.Length) / 2))
    $padding = "─" * $padLen
    $extraChar = if (($titleWithSpaces.Length + $padLen * 2) -lt $BOX_WIDTH) { "─" } else { "" }
    
    Write-Host ""
    Center-Printf "$BOLD$Color$padding$titleWithSpaces$padding$extraChar$RESET"
    Write-Host ""
}

function Print-DoubleLineHeader {
    param(
        [string]$Title,
        [string]$Color = $FG_BLUE
    )
    
    $titleWithSpaces = " $Title "
    $cleanTitle = $titleWithSpaces -replace '\x1b\[[0-9;]*m', ''
    $titleLen = $cleanTitle.Length
    
    Write-Host ""
    Center-Printf "$BOLD$Color╔$('═' * $titleLen)╗"
    Center-Printf "$BOLD$Color║$titleWithSpaces║"
    Center-Printf "$BOLD$Color╚$('═' * $titleLen)╝$RESET"
    Write-Host ""
}

# --- Box Drawing Functions ---
function Box-Print {
    param([string]$Content)
    $cleanContent = $Content -replace '\x1b\[[0-9;]*m', ''
    $contentLen = $cleanContent.Length
    $padding = [Math]::Max(0, $BOX_WIDTH - 4 - $contentLen)
    Center-Printf "│ $Content$(' ' * $padding) │"
}

function Box-Printf {
    param([string]$Format, [object[]]$Args)
    $content = $Format -f $Args
    Box-Print $content
}

function Print-BoxTop {
    Center-Printf "╭$('─' * ($BOX_WIDTH - 2))╮"
}

function Print-BoxSeparator {
    Center-Printf "├$('─' * ($BOX_WIDTH - 2))┤"
}

function Print-BoxBottom {
    Center-Printf "╰$('─' * ($BOX_WIDTH - 2))╯"
}

function Box-PrintBlank {
    Center-Printf "│$(' ' * ($BOX_WIDTH - 2))│"
}

function Box-PrintProviderHeader {
    param([string]$ProviderName)
    
    $providerWithSpaces = " $ProviderName "
    $totalWidth = $BOX_WIDTH - 4
    $nameLen = $providerWithSpaces.Length
    $padLen = [Math]::Max(0, [Math]::Floor(($totalWidth - $nameLen) / 2))
    $leftPad = "╌" * $padLen
    $rightPad = $leftPad
    if (($nameLen + $padLen * 2) -lt $totalWidth) {
        $rightPad += "╌"
    }
    Box-Print "$leftPad$BOLD$FG_YELLOW$providerWithSpaces$RESET$rightPad"
}

function Generate-LatencyBar {
    param([string]$LatencyMs)
    
    if (-not ($LatencyMs -match '^\d+(\.\d+)?$')) {
        return ""
    }
    
    $latInt = [int][float]$LatencyMs
    $barChar = "■"
    
    if ($latInt -lt 30) {
        $barColor = $FG_GREEN
    } elseif ($latInt -lt 80) {
        $barColor = $FG_YELLOW
    } else {
        $barColor = $FG_RED
    }
    
    $barLen = 1
    if ($latInt -gt 50) { $barLen = 2 }
    if ($latInt -gt 100) { $barLen = 3 }
    
    $bar = $barChar * $barLen
    return " $barColor$bar$RESET"
}

function Animated-Bar {
    param(
        [string]$Label,
        [int]$TotalSteps = 3,
        [int]$DurationMs = 1000
    )
    
    $width = [Math]::Min(80, $BOX_WIDTH) - 32
    if ($width -lt 12) { $width = 12 }
    
    $sleepInterval = 30
    $numFrames = [Math]::Floor($DurationMs / $sleepInterval)
    $progressChar = "▰"
    $remainingChar = "-"
    $spinnerChars = @("⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏")
    
    for ($f = 0; $f -le $numFrames; $f++) {
        $stepsDone = [Math]::Floor(($f * $TotalSteps) / $numFrames)
        $filled = [Math]::Min($width, [Math]::Floor(($f * $width) / $numFrames))
        $empty = $width - $filled
        $spinnerChar = $spinnerChars[$f % $spinnerChars.Length]
        
        Write-Host ("`r" + " " * $CENTER_OFFSET + "│   $FG_CYAN$spinnerChar$RESET $Label".PadRight(10) + 
                   " [$FG_GREEN$($progressChar * $filled)$RESET$($remainingChar * $empty)] $stepsDone/$TotalSteps".PadLeft(8)) -NoNewline
        Start-Sleep -Milliseconds $sleepInterval
    }
    
    Write-Host ("`r" + " " * $CENTER_OFFSET + "│   $FG_GREEN✔$RESET $Label".PadRight(10) + 
               " [$($progressChar * $width)] $TotalSteps/$TotalSteps".PadLeft(8))
}

# --- Progress Bar Style Display Function ---
function Display-ProgressBars {
    if (-not (Test-Path $TOP_3_RESULTS) -or (Get-Content $TOP_3_RESULTS | Measure-Object).Count -eq 0) {
        Center-Printf "  $FG_RED No reachable DNS servers were found during the test.$RESET"
        return
    }
    
    Write-Host ""
    Center-Printf "$FG_CYAN$BOLD📊 DNS PERFORMANCE COMPARISON 📊$RESET"
    Write-Host ""
    Center-Printf "$FG_BRIGHT_WHITE Longer bars = Better performance (lower latency)$RESET"
    Write-Host ""
    Write-Host ""
    
    # Find max latency for scaling
    $latencies = @()
    Get-Content $TOP_3_RESULTS | ForEach-Object {
        $parts = $_ -split ','
        if ($parts.Length -eq 4) {
            $latencies += [float]$parts[3]
        }
    }
    
    $maxLat = ($latencies | Measure-Object -Maximum).Maximum
    $maxLatInt = [int]$maxLat
    
    $rank = 1
    Get-Content $TOP_3_RESULTS | ForEach-Object {
        $parts = $_ -split ','
        if ($parts.Length -eq 4) {
            $pname, $pip, $ploss, $plat = $parts
            
            $medal, $color = switch ($rank) {
                1 { "🥇", $FG_YELLOW }
                2 { "🥈", $FG_WHITE }
                3 { "🥉", $FG_BROWN }
            }
            
            # Calculate bar length (inverse - shorter latency = longer bar)
            $latInt = [int][float]$plat
            $barLen = [Math]::Max(10, [Math]::Min(45, 50 - [Math]::Floor($latInt * 35 / $maxLatInt)))
            $bar = "█" * $barLen
            
            # Performance rating based on latency
            $rating = if ($latInt -lt 25) {
                "$FG_GREEN${BOLD}BLAZING FAST$RESET"
            } elseif ($latInt -lt 40) {
                "$FG_YELLOW${BOLD}VERY FAST$RESET"
            } elseif ($latInt -lt 60) {
                "$FG_ORANGE${BOLD}FAST$RESET"
            } else {
                "$FG_RED${BOLD}GOOD$RESET"
            }
            
            Center-Printf "$medal $BOLD%-12s$RESET $color$bar$RESET $FG_GREEN%6sms$RESET $rating" $pname $plat $rating
            Center-Printf "    $FG_CYAN%s$RESET - $FG_WHITE%s$RESET" $pip (Get-ProviderTags $pname)
            Write-Host ""
            
            $rank++
        }
    }
    
    # Winner celebration
    $winnerLine = Get-Content $TOP_3_RESULTS | Select-Object -First 1
    if ($winnerLine) {
        $parts = $winnerLine -split ','
        $firstName = $parts[0]
        $firstLat = $parts[3]
        [Console]::Beep(800, 100)
        Center-Printf "⚡ $FG_YELLOW${BOLD}SPEED CHAMPION: $firstName leads with ${firstLat}ms response time!$RESET ⚡"
        Center-Printf "$FG_GREEN🏆 Optimal DNS performance achieved! 🏆$RESET"
    }
    
    Write-Host ""
}

# --- DNS Provider Data ---
$DNS_SERVERS = @(
    "Cloudflare,1.1.1.1,1.0.0.1",
    "Google,8.8.8.8,8.8.4.4",
    "Quad9,9.9.9.9,149.112.112.112",
    "OpenDNS,208.67.222.222,208.67.220.220",
    "AdGuard,94.140.14.14,94.140.15.15",
    "CleanBrowsing,185.228.168.9,185.228.169.9",
    "Comodo,8.26.56.26,8.20.247.20",
    "Verisign,64.6.64.6,64.6.65.6"
)

function Get-ProviderTags {
    param([string]$Provider)
    
    switch ($Provider) {
        "Cloudflare" { return "Speed, Privacy, Modern" }
        "Google" { return "Speed, Reliable, Global" }
        "Quad9" { return "Security, Malware-Protection, Privacy" }
        "OpenDNS" { return "Stable, Filtering, Security" }
        "AdGuard" { return "Ad-Filtering, Privacy, Stable" }
        "CleanBrowsing" { return "Family-Filtering, Security, Stable" }
        "Comodo" { return "Security, Malware-Protection, Stable" }
        "Verisign" { return "Stable, Reliable, No-Redirection" }
        default { return "General Purpose" }
    }
}

# --- Main Execution ---
Print-Header "System & Dependencies Check" $FG_MAGENTA
Ensure-Dependencies

# Show system info
Write-Host ""
if (Get-Command winfetch -ErrorAction SilentlyContinue) {
    winfetch
}

# Display custom banner for the benchmark
if (Get-Command figlet -ErrorAction SilentlyContinue) {
    figlet "DNS BENCHMARK"
} else {
    Print-DoubleLineHeader "🚀 DNS BENCHMARK 🚀" $FG_CYAN
}

# START THE BOX for the benchmark
Print-BoxTop
$PING_COUNT = 5
$PING_TIMEOUT_MS = 500
$BAR_DURATION_MS = $PING_COUNT * $PING_TIMEOUT_MS + 500

Box-PrintBlank
Box-Print "$BOLD Mode:$RESET       $PING_COUNT probes per host"
Box-Print "$BOLD Timeout:$RESET    ${PING_TIMEOUT_MS}ms per probe"
Box-Print "$BOLD Targets:$RESET    $($DNS_SERVERS.Count) providers (primary + secondary)"
Box-PrintBlank

foreach ($entry in $DNS_SERVERS) {
    $provider, $ip1, $ip2 = $entry -split ','
    Print-BoxSeparator
    
    Box-PrintProviderHeader $provider
    Box-PrintBlank
    
    # Test Primary IP
    $job1 = Start-Job -ScriptBlock {
        param($ip, $count, $timeout)
        try {
            # Ping with count and timeout
            $results = Test-Connection -ComputerName $ip -Count $count -Quiet -TimeoutSeconds ($timeout / 1000)
            if ($results) {
                $fullResults = Test-Connection -ComputerName $ip -Count $count -TimeoutSeconds ($timeout / 1000)
                $avg = ($fullResults | Measure-Object -Property ResponseTime -Average).Average
                return @{ Success = $true; Avg = $avg; Loss = 0 }
            } else {
                return @{ Success = $false; Loss = 100 }
            }
        } catch {
            return @{ Success = $false; Loss = 100 }
        }
    } -ArgumentList $ip1, $PING_COUNT, $PING_TIMEOUT_MS
    
    Animated-Bar "Primary" $PING_COUNT $BAR_DURATION_MS
    $result1 = Receive-Job -Job $job1 -Wait
    Remove-Job -Job $job1
    
    if ($result1.Success) {
        Box-Printf "    %-9s $FG_GREEN✔ OK$RESET   avg=%-7sms loss=%-3s%% %s $FG_WHITE(%s)$RESET" `
            "Primary" $result1.Avg $result1.Loss (Generate-LatencyBar $result1.Avg) $ip1
        "$provider,$ip1,$($result1.Loss),$($result1.Avg)" | Add-Content $TMP_RESULTS
    } else {
        Box-Printf "    %-9s $FG_RED✖ UNREACHABLE$RESET   loss=%-3s%% $FG_WHITE(%s)$RESET" `
            "Primary" $result1.Loss $ip1
    }
    
    # Test Secondary IP
    $job2 = Start-Job -ScriptBlock {
        param($ip, $count, $timeout)
        try {
            $results = Test-Connection -ComputerName $ip -Count $count -Quiet -TimeoutSeconds ($timeout / 1000)
            if ($results) {
                $fullResults = Test-Connection -ComputerName $ip -Count $count -TimeoutSeconds ($timeout / 1000)
                $avg = ($fullResults | Measure-Object -Property ResponseTime -Average).Average
                return @{ Success = $true; Avg = $avg; Loss = 0 }
            } else {
                return @{ Success = $false; Loss = 100 }
            }
        } catch {
            return @{ Success = $false; Loss = 100 }
        }
    } -ArgumentList $ip2, $PING_COUNT, $PING_TIMEOUT_MS
    
    Animated-Bar "Secondary" $PING_COUNT $BAR_DURATION_MS
    $result2 = Receive-Job -Job $job2 -Wait
    Remove-Job -Job $job2
    
    if ($result2.Success) {
        Box-Printf "    %-9s $FG_GREEN✔ OK$RESET   avg=%-7sms loss=%-3s%% %s $FG_WHITE(%s)$RESET" `
            "Secondary" $result2.Avg $result2.Loss (Generate-LatencyBar $result2.Avg) $ip2
        "$provider,$ip2,$($result2.Loss),$($result2.Avg)" | Add-Content $TMP_RESULTS
    } else {
        Box-Printf "    %-9s $FG_RED✖ UNREACHABLE$RESET   loss=%-3s%% $FG_WHITE(%s)$RESET" `
            "Secondary" $result2.Loss $ip2
    }
    Box-PrintBlank
}

Print-BoxBottom

# --- Process and Display Final Summary ---
if (Test-Path $TMP_RESULTS) {
    Get-Content $TMP_RESULTS | Where-Object {
        $parts = $_ -split ','
        $parts.Length -eq 4 -and $parts[3] -match '^\d+(\.\d+)?$' -and [float]$parts[2] -lt 100
    } | Set-Content $CLEAN_RESULTS
    
    Get-Content $CLEAN_RESULTS | Sort-Object { [float]($_ -split ',')[3] } | Select-Object -First 3 | Set-Content $TOP_3_RESULTS
}

# Display styled header for the results
if (Get-Command figlet -ErrorAction SilentlyContinue) {
    figlet "TOP 3 RESULTS"
} else {
    Print-DoubleLineHeader "🏆 TOP 3 RESULTS 🏆" $FG_GREEN
}

# Display the progress bar results
Display-ProgressBars

Write-Host ""

# Cleanup temp files
Cleanup
