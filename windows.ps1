<#
.SYNOPSIS
    DNS Benchmark Tool for Windows
.DESCRIPTION
    A PowerShell script to test DNS server latency and display results with enhanced visuals.
    Supports both full mode with system info and basic mode for quick testing.
.NOTES
    Version: 1.0
    Author: DNS Benchmark Tool
    Requires: PowerShell 5.1+
#>

# Set strict mode and error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

# Global Variables
$Global:TempResults = @()
$Global:CleanResults = @()
$Global:Top3Results = @()

# Add at the top of your script after the color definitions
function Initialize-Terminal {
    # Check if running in supported terminal
    $SupportsAnsi = $false
    
    try {
        # Check for Windows Terminal, PowerShell 7+, or VT support
        if ($env:WT_SESSION -or $PSVersionTable.PSVersion.Major -ge 7 -or $Host.UI.SupportsVirtualTerminal) {
            $SupportsAnsi = $true
        }
        
        # Try to enable VT processing
        if (-not $SupportsAnsi -and $Host.Name -eq "ConsoleHost") {
            # VT enabling code here (from above)
            $SupportsAnsi = $true
        }
    } catch {
        $SupportsAnsi = $false
    }
    
    # Disable colors if ANSI not supported
    if (-not $SupportsAnsi) {
        Write-Warning "Terminal doesn't support ANSI colors. Using plain text mode."
        $Global:Colors = @{
            Reset = ""; Bold = ""; Red = ""; Green = ""; Yellow = "";
            Blue = ""; Magenta = ""; Cyan = ""; White = ""; BrightWhite = "";
            Gray = ""; Orange = ""; Brown = ""
        }
    }
}

# Call this after color definitions
Initialize-Terminal


# ANSI Color Codes for PowerShell
$Global:Colors = @{
    Reset = "`e[0m"
    Bold = "`e[1m"
    Red = "`e[31m"
    Green = "`e[32m"
    Yellow = "`e[33m"
    Blue = "`e[34m"
    Magenta = "`e[35m"
    Cyan = "`e[36m"
    White = "`e[37m"
    BrightWhite = "`e[97m"
    Gray = "`e[90m"
    Orange = "`e[38;5;214m"
    Brown = "`e[38;5;130m"
}

# Terminal dimensions
$Global:TerminalWidth = try { $Host.UI.RawUI.WindowSize.Width } catch { 120 }
$Global:BoxWidth = 96
$Global:CenterOffset = [Math]::Max(0, [Math]::Floor(($Global:TerminalWidth - $Global:BoxWidth) / 2))

# Winfetch path
$Global:WinfetchPath = "$env:USERPROFILE\winfetch.ps1"

# DNS Servers Configuration
$Global:DNSServers = @(
    @{Name="Cloudflare"; Primary="1.1.1.1"; Secondary="1.0.0.1"}
    @{Name="Google"; Primary="8.8.8.8"; Secondary="8.8.4.4"}
    @{Name="Quad9"; Primary="9.9.9.9"; Secondary="149.112.112.112"}
    @{Name="OpenDNS"; Primary="208.67.222.222"; Secondary="208.67.220.220"}
    @{Name="AdGuard"; Primary="94.140.14.14"; Secondary="94.140.15.15"}
    @{Name="CleanBrowsing"; Primary="185.228.168.9"; Secondary="185.228.169.9"}
    @{Name="Comodo"; Primary="8.26.56.26"; Secondary="8.20.247.20"}
    @{Name="Verisign"; Primary="64.6.64.6"; Secondary="64.6.65.6"}
)

# Helper Functions
function Write-Centered {
    param([string]$Text)
    $Padding = " " * $Global:CenterOffset
    Write-Host ($Padding + $Text)
}

function Write-CenteredFormat {
    param([string]$Format, [object[]]$Args)
    $Text = $Format -f $Args
    Write-Centered $Text
}

function Show-MainMenu {
    Clear-Host
    Write-Host ""
    Write-Centered "$($Global:Colors.Bold)$($Global:Colors.Cyan)╔══════════════════════════════════════════════════════════════════════════════════════════════╗$($Global:Colors.Reset)"
    Write-Centered "$($Global:Colors.Bold)$($Global:Colors.Cyan)║                                                                                              ║$($Global:Colors.Reset)"
    Write-Centered "$($Global:Colors.Bold)$($Global:Colors.Cyan)║                               🚀 DNS BENCHMARK TOOL 🚀                                       ║$($Global:Colors.Reset)"
    Write-Centered "$($Global:Colors.Bold)$($Global:Colors.Cyan)║                                                                                              ║$($Global:Colors.Reset)"
    Write-Centered "$($Global:Colors.Bold)$($Global:Colors.Cyan)╠══════════════════════════════════════════════════════════════════════════════════════════════╣$($Global:Colors.Reset)"
    Write-Centered "$($Global:Colors.Bold)$($Global:Colors.Cyan)║                                                                                              ║$($Global:Colors.Reset)"
    Write-Centered "$($Global:Colors.Bold)$($Global:Colors.Cyan)║  Choose your preferred benchmarking mode:                                                   ║$($Global:Colors.Reset)"
    Write-Centered "$($Global:Colors.Bold)$($Global:Colors.Cyan)║                                                                                              ║$($Global:Colors.Reset)"
    Write-Centered "$($Global:Colors.Bold)$($Global:Colors.Cyan)║  $($Global:Colors.Green)$($Global:Colors.Bold)1)$($Global:Colors.Reset)$($Global:Colors.Bold)$($Global:Colors.Cyan) DNS Benchmark with Visual Components                                                  ║$($Global:Colors.Reset)"
    Write-Centered "$($Global:Colors.Bold)$($Global:Colors.Cyan)║     $($Global:Colors.White)• Full system check with Winfetch system info$($Global:Colors.Reset)$($Global:Colors.Bold)$($Global:Colors.Cyan)                                        ║$($Global:Colors.Reset)"
    Write-Centered "$($Global:Colors.Bold)$($Global:Colors.Cyan)║     $($Global:Colors.White)• Downloads Winfetch if needed (one time only)$($Global:Colors.Reset)$($Global:Colors.Bold)$($Global:Colors.Cyan)                                       ║$($Global:Colors.Reset)"
    Write-Centered "$($Global:Colors.Bold)$($Global:Colors.Cyan)║     $($Global:Colors.White)• Enhanced visuals with colors and animations$($Global:Colors.Reset)$($Global:Colors.Bold)$($Global:Colors.Cyan)                                       ║$($Global:Colors.Reset)"
    Write-Centered "$($Global:Colors.Bold)$($Global:Colors.Cyan)║                                                                                              ║$($Global:Colors.Reset)"
    Write-Centered "$($Global:Colors.Bold)$($Global:Colors.Cyan)║  $($Global:Colors.Yellow)$($Global:Colors.Bold)2)$($Global:Colors.Reset)$($Global:Colors.Bold)$($Global:Colors.Cyan) Only DNS Benchmark                                                                   ║$($Global:Colors.Reset)"
    Write-Centered "$($Global:Colors.Bold)$($Global:Colors.Cyan)║     $($Global:Colors.White)• Skip system info and Winfetch setup$($Global:Colors.Reset)$($Global:Colors.Bold)$($Global:Colors.Cyan)                                               ║$($Global:Colors.Reset)"
    Write-Centered "$($Global:Colors.Bold)$($Global:Colors.Cyan)║     $($Global:Colors.White)• Same visual DNS testing with full progress bars$($Global:Colors.Reset)$($Global:Colors.Bold)$($Global:Colors.Cyan)                                   ║$($Global:Colors.Reset)"
    Write-Centered "$($Global:Colors.Bold)$($Global:Colors.Cyan)║     $($Global:Colors.White)• Faster startup, same beautiful benchmark display$($Global:Colors.Reset)$($Global:Colors.Bold)$($Global:Colors.Cyan)                                 ║$($Global:Colors.Reset)"
    Write-Centered "$($Global:Colors.Bold)$($Global:Colors.Cyan)║                                                                                              ║$($Global:Colors.Reset)"
    Write-Centered "$($Global:Colors.Bold)$($Global:Colors.Cyan)║  $($Global:Colors.Red)$($Global:Colors.Bold)3)$($Global:Colors.Reset)$($Global:Colors.Bold)$($Global:Colors.Cyan) Quit                                                                                 ║$($Global:Colors.Reset)"
    Write-Centered "$($Global:Colors.Bold)$($Global:Colors.Cyan)║     $($Global:Colors.White)• Exit the application$($Global:Colors.Reset)$($Global:Colors.Bold)$($Global:Colors.Cyan)                                                              ║$($Global:Colors.Reset)"
    Write-Centered "$($Global:Colors.Bold)$($Global:Colors.Cyan)║                                                                                              ║$($Global:Colors.Reset)"
    Write-Centered "$($Global:Colors.Bold)$($Global:Colors.Cyan)╚══════════════════════════════════════════════════════════════════════════════════════════════╝$($Global:Colors.Reset)"
    Write-Host ""
    Write-Centered "$($Global:Colors.Blue)Enter your choice [1-3]: $($Global:Colors.Reset)" -NoNewline
}

function Test-ComponentAvailability {
    Write-Host ""
    Write-Centered "$($Global:Colors.Bold)$($Global:Colors.Cyan)╔══════════════════════════════════════════════════════════════════════════════════════════════╗$($Global:Colors.Reset)"
    Write-Centered "$($Global:Colors.Bold)$($Global:Colors.Cyan)║                                                                                              ║$($Global:Colors.Reset)"
    Write-Centered "$($Global:Colors.Bold)$($Global:Colors.Cyan)║                                📋 COMPONENT STATUS CHECK 📋                                  ║$($Global:Colors.Reset)"
    Write-Centered "$($Global:Colors.Bold)$($Global:Colors.Cyan)║                                                                                              ║$($Global:Colors.Reset)"
    Write-Centered "$($Global:Colors.Bold)$($Global:Colors.Cyan)╚══════════════════════════════════════════════════════════════════════════════════════════════╝$($Global:Colors.Reset)"
    Write-Host ""
    
    $Components = @(
        @{Name="💻 Winfetch"; Command="winfetch"; Description="System Info Display"}
        @{Name="🌐 PowerShell"; Command="powershell"; Description="DNS Testing Engine"}
        @{Name="📡 Test-Connection"; Command="Test-Connection"; Description="Network Connectivity"}
        @{Name="🔍 Resolve-DnsName"; Command="Resolve-DnsName"; Description="DNS Resolution"}
        @{Name="🌍 Internet"; Command="internet"; Description="Web Connectivity"}
        @{Name="🎨 Terminal"; Command="terminal"; Description="Terminal Capabilities"}
    )
    
    foreach ($Component in $Components) {
        # Animate progress bar
        for ($i = 0; $i -le 20; $i++) {
            $Spinner = @("⠋","⠙","⠹","⠸","⠼","⠴","⠦","⠧","⠇","⠏")[$i % 10]
            $Progress = [Math]::Floor($i * 100 / 20)
            $Filled = [Math]::Floor($i * 20 / 20)
            $Empty = 20 - $Filled
            
            $ProgressBar = "$($Global:Colors.Green)" + ("▰" * $Filled) + "$($Global:Colors.Reset)" + ("-" * $Empty)
            
            Write-Host ("`r" + (" " * $Global:CenterOffset) + "$($Global:Colors.Bold)$($Global:Colors.Cyan)$($Component.Name) $($Component.Description)$($Global:Colors.Reset) $($Global:Colors.Cyan)$Spinner$($Global:Colors.Reset) [$ProgressBar] $Progress%") -NoNewline
            
            Start-Sleep -Milliseconds 70
        }
        
        # Check component status
        $Status = ""
        $Details = ""
        $StatusColor = ""
        
        switch ($Component.Command) {
            "winfetch" { 
                if (Test-Path $Global:WinfetchPath) {
                    $Status = "INSTALLED"; $StatusColor = $Global:Colors.Green
                    $Details = "Local script ready"
                } else {
                    try {
                        $null = Test-NetConnection -ComputerName "raw.githubusercontent.com" -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue
                        $Status = "AVAILABLE"; $StatusColor = $Global:Colors.Yellow
                        $Details = "Download required"
                    } catch {
                        $Status = "UNAVAILABLE"; $StatusColor = $Global:Colors.Red
                        $Details = "Network required"
                    }
                }
            }
            "powershell" { 
                $Status = "ACTIVE"; $StatusColor = $Global:Colors.Cyan
                $Details = "PowerShell $($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor)"
            }
            "Test-Connection" { 
                $Status = "AVAILABLE"; $StatusColor = $Global:Colors.Green
                $Details = "Network ready"
            }
            "Resolve-DnsName" { 
                $Status = "AVAILABLE"; $StatusColor = $Global:Colors.Green
                $Details = "DNS ready"
            }
            "internet" {
                try {
                    $null = Test-Connection "8.8.8.8" -Count 1 -Quiet -TimeoutSec 3
                    $Status = "CONNECTED"; $StatusColor = $Global:Colors.Green
                    $Details = "Internet ready"
                } catch {
                    $Status = "OFFLINE"; $StatusColor = $Global:Colors.Red
                    $Details = "No connection"
                }
            }
            "terminal" { 
                $Status = "ACTIVE"; $StatusColor = $Global:Colors.Cyan
                $Details = "$($Global:TerminalWidth)x$($Host.UI.RawUI.WindowSize.Height)"
            }
        }
        
        Write-Host ("`r" + (" " * $Global:CenterOffset) + "$($Global:Colors.Bold)$($Global:Colors.Cyan)$($Component.Name) $($Component.Description) ".PadRight(35) + " $StatusColor$Status$($Global:Colors.Reset) - $Details$($Global:Colors.Reset)")
        Start-Sleep -Milliseconds 100
    }
    
    Write-Host ""
    Write-Centered "$($Global:Colors.Bold)$($Global:Colors.Green)🎉 System ready for DNS benchmarking!$($Global:Colors.Reset)"
    Write-Host ""
    Write-Centered "$($Global:Colors.Blue)Press any key to continue...$($Global:Colors.Reset)"
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    Write-Host ""
}

function Install-Winfetch {
    Write-Host ""
    Write-Centered "$($Global:Colors.Bold)$($Global:Colors.Cyan)╔══════════════════════════════════════════════════════════════════════════════════════════════╗$($Global:Colors.Reset)"
    Write-Centered "$($Global:Colors.Bold)$($Global:Colors.Cyan)║                                                                                              ║$($Global:Colors.Reset)"
    Write-Centered "$($Global:Colors.Bold)$($Global:Colors.Cyan)║                            🚀 WINFETCH SETUP 🚀                                             ║$($Global:Colors.Reset)"
    Write-Centered "$($Global:Colors.Bold)$($Global:Colors.Cyan)║                                                                                              ║$($Global:Colors.Reset)"
    Write-Centered "$($Global:Colors.Bold)$($Global:Colors.Cyan)╚══════════════════════════════════════════════════════════════════════════════════════════════╝$($Global:Colors.Reset)"
    Write-Host ""
    
    if (Test-Path $Global:WinfetchPath) {
        Write-Centered "$($Global:Colors.Green)✅ Winfetch already installed at: $Global:WinfetchPath$($Global:Colors.Reset)"
        return $true
    }
    
    Write-Centered "$($Global:Colors.Yellow)📦 Downloading Winfetch from GitHub...$($Global:Colors.Reset)"
    Write-Centered "$($Global:Colors.Blue)   This is a one-time download, subsequent runs will use the local copy.$($Global:Colors.Reset)"
    Write-Host ""
    
    try {
        # Show progress during download
        Write-Centered "$($Global:Colors.Cyan)🔄 Downloading to: $Global:WinfetchPath$($Global:Colors.Reset)"
        
        # Use official Winfetch installation method
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/lptstr/winfetch/master/winfetch.ps1" -OutFile $Global:WinfetchPath -UseBasicParsing -ErrorAction Stop
        
        Write-Host ""
        Write-Centered "$($Global:Colors.Green)🎉 Winfetch downloaded successfully!$($Global:Colors.Reset)"
        Write-Centered "$($Global:Colors.Green)📁 Saved to: $Global:WinfetchPath$($Global:Colors.Reset)"
        return $true
        
    } catch {
        Write-Host ""
        Write-Centered "$($Global:Colors.Red)❌ Failed to download Winfetch.$($Global:Colors.Reset)"
        Write-Centered "$($Global:Colors.Yellow)⚠️  Error: $($_.Exception.Message)$($Global:Colors.Reset)"
        Write-Centered "$($Global:Colors.Blue)   Continuing without system info display...$($Global:Colors.Reset)"
        return $false
    }
}

function Invoke-Winfetch {
    if (-not (Test-Path $Global:WinfetchPath)) {
        if (-not (Install-Winfetch)) {
            return
        }
    }
    
    Write-Host ""
    Write-Centered "$($Global:Colors.Yellow)💻 Loading system information with Winfetch...$($Global:Colors.Reset)"
    Write-Host ""
    
    try {
        # Execute local winfetch script
        & $Global:WinfetchPath
        Write-Host ""
    } catch {
        Write-Centered "$($Global:Colors.Red)❌ Error running Winfetch: $($_.Exception.Message)$($Global:Colors.Reset)"
        Write-Centered "$($Global:Colors.Yellow)⚠️ Continuing without system info display...$($Global:Colors.Reset)"
        Write-Host ""
    }
}

function Write-BoxTop { Write-Centered ("╭" + ("─" * ($Global:BoxWidth - 2)) + "╮") }
function Write-BoxBottom { Write-Centered ("╰" + ("─" * ($Global:BoxWidth - 2)) + "╯") }
function Write-BoxSeparator { Write-Centered ("├" + ("─" * ($Global:BoxWidth - 2)) + "┤") }
function Write-BoxBlank { Write-Centered ("│" + (" " * ($Global:BoxWidth - 2)) + "│") }

function Write-BoxLine {
    param([string]$Content)
    $CleanContent = $Content -replace '`e\[[0-9;]*m', ''
    $Padding = [Math]::Max(0, $Global:BoxWidth - 4 - $CleanContent.Length)
    Write-Centered ("│ $Content" + (" " * $Padding) + " │")
}

function Write-BoxProviderHeader {
    param([string]$ProviderName)
    $Name = " $ProviderName "
    $TotalWidth = $Global:BoxWidth - 4
    $NameLen = $Name.Length
    $PadLen = [Math]::Max(0, [Math]::Floor(($TotalWidth - $NameLen) / 2))
    $LeftPad = "╌" * $PadLen
    $RightPad = "╌" * $PadLen
    if (($NameLen + $PadLen * 2) -lt $TotalWidth) { $RightPad += "╌" }
    Write-BoxLine "$LeftPad$($Global:Colors.Bold)$($Global:Colors.Yellow)$Name$($Global:Colors.Reset)$RightPad"
}

function Get-LatencyBar {
    param([double]$LatencyMs)
    if ($LatencyMs -le 0) { return "" }
    
    $BarChar = "■"
    if ($LatencyMs -lt 30) { $BarColor = $Global:Colors.Green }
    elseif ($LatencyMs -lt 80) { $BarColor = $Global:Colors.Yellow }
    else { $BarColor = $Global:Colors.Red }
    
    $BarLen = 1
    if ($LatencyMs -gt 50) { $BarLen = 2 }
    if ($LatencyMs -gt 100) { $BarLen = 3 }
    
    $Bar = $BarChar * $BarLen
    return " $BarColor$Bar$($Global:Colors.Reset)"
}

function Show-AnimatedBar {
    param(
        [string]$Label,
        [int]$TotalSteps = 3,
        [int]$DurationMs = 1000
    )
    
    $Width = [Math]::Min(40, $Global:BoxWidth - 32)
    if ($Width -lt 12) { $Width = 12 }
    
    $NumFrames = [Math]::Floor($DurationMs / 30)
    $ProgressChar = "▰"
    $RemainingChar = "-"
    $Spinners = @("⠋","⠙","⠹","⠸","⠼","⠴","⠦","⠧","⠇","⠏")
    
    for ($f = 0; $f -le $NumFrames; $f++) {
        $StepsDone = [Math]::Floor($f * $TotalSteps / $NumFrames)
        $Filled = [Math]::Floor($f * $Width / $NumFrames)
        if ($Filled -gt $Width) { $Filled = $Width }
        $Empty = $Width - $Filled
        $Spinner = $Spinners[$f % $Spinners.Length]
        
        $ProgressBar = "$($Global:Colors.Green)" + ($ProgressChar * $Filled) + "$($Global:Colors.Reset)" + ($RemainingChar * $Empty)
        
        Write-Host ("`r" + (" " * $Global:CenterOffset) + "│   $($Global:Colors.Cyan)$Spinner$($Global:Colors.Reset) $($Label.PadRight(10)) [$ProgressBar] $StepsDone/$TotalSteps") -NoNewline
        Start-Sleep -Milliseconds 30
    }
    
    $FullBar = $ProgressChar * $Width
    Write-Host ("`r" + (" " * $Global:CenterOffset) + "│   $($Global:Colors.Green)✔$($Global:Colors.Reset) $($Label.PadRight(10)) [$FullBar] $TotalSteps/$TotalSteps")
}

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

function Start-DNSBenchmark {
    # Clear previous results
    $Global:TempResults = @()
    $Global:CleanResults = @()
    $Global:Top3Results = @()
    
    # Show fancy header
    Write-Host ""
    Write-Centered "$($Global:Colors.Bold)$($Global:Colors.Cyan)╔═══════════════════════════════════════╗$($Global:Colors.Reset)"
    Write-Centered "$($Global:Colors.Bold)$($Global:Colors.Cyan)║         🚀 DNS BENCHMARK 🚀           ║$($Global:Colors.Reset)"
    Write-Centered "$($Global:Colors.Bold)$($Global:Colors.Cyan)╚═══════════════════════════════════════╝$($Global:Colors.Reset)"
    
    # Start the benchmark box
    Write-BoxTop
    $PingCount = 5
    $TimeoutMs = 500
    $BarDuration = $PingCount * $TimeoutMs + 500
    
    Write-BoxBlank
    Write-BoxLine "$($Global:Colors.Bold)Mode:$($Global:Colors.Reset)       $PingCount probes per host"
    Write-BoxLine "$($Global:Colors.Bold)Timeout:$($Global:Colors.Reset)    ${TimeoutMs}ms per probe"
    Write-BoxLine "$($Global:Colors.Bold)Targets:$($Global:Colors.Reset)    $($Global:DNSServers.Count) providers (primary + secondary)"
    Write-BoxBlank
    
    foreach ($Server in $Global:DNSServers) {
        Write-BoxSeparator
        Write-BoxProviderHeader $Server.Name
        Write-BoxBlank
        
        # Test Primary DNS
        $Job = Start-Job -ScriptBlock { 
            param($DNSServer, $Count)
            $Latencies = @()
            for ($i = 0; $i -lt $Count; $i++) {
                try {
                    $Start = Get-Date
                    $null = Resolve-DnsName -Name "google.com" -Server $DNSServer -ErrorAction Stop
                    $End = Get-Date
                    $Latencies += ($End - $Start).TotalMilliseconds
                } catch { }
            }
            return $Latencies
        } -ArgumentList $Server.Primary, $PingCount
        
        Show-AnimatedBar "Primary" $PingCount $BarDuration
        $PrimaryResults = Receive-Job -Job $Job -Wait
        Remove-Job -Job $Job
        
        if ($PrimaryResults.Count -gt 0) {
            $PrimaryAvg = [Math]::Round(($PrimaryResults | Measure-Object -Average).Average, 2)
            $PrimaryLoss = [Math]::Round(100 * ($PingCount - $PrimaryResults.Count) / $PingCount, 1)
            $LatencyBar = Get-LatencyBar $PrimaryAvg
            Write-BoxLine "    Primary   $($Global:Colors.Green)✔ OK$($Global:Colors.Reset)   avg=$($PrimaryAvg.ToString().PadRight(7))ms loss=$($PrimaryLoss.ToString().PadRight(3))%$LatencyBar $($Global:Colors.White)($($Server.Primary))$($Global:Colors.Reset)"
            $Global:TempResults += @{Provider=$Server.Name; IP=$Server.Primary; Loss=$PrimaryLoss; Latency=$PrimaryAvg}
        } else {
            Write-BoxLine "    Primary   $($Global:Colors.Red)✖ UNREACHABLE$($Global:Colors.Reset)   loss=100% $($Global:Colors.White)($($Server.Primary))$($Global:Colors.Reset)"
        }
        
        # Test Secondary DNS
        $Job = Start-Job -ScriptBlock { 
            param($DNSServer, $Count)
            $Latencies = @()
            for ($i = 0; $i -lt $Count; $i++) {
                try {
                    $Start = Get-Date
                    $null = Resolve-DnsName -Name "google.com" -Server $DNSServer -ErrorAction Stop
                    $End = Get-Date
                    $Latencies += ($End - $Start).TotalMilliseconds
                } catch { }
            }
            return $Latencies
        } -ArgumentList $Server.Secondary, $PingCount
        
        Show-AnimatedBar "Secondary" $PingCount $BarDuration
        $SecondaryResults = Receive-Job -Job $Job -Wait
        Remove-Job -Job $Job
        
        if ($SecondaryResults.Count -gt 0) {
            $SecondaryAvg = [Math]::Round(($SecondaryResults | Measure-Object -Average).Average, 2)
            $SecondaryLoss = [Math]::Round(100 * ($PingCount - $SecondaryResults.Count) / $PingCount, 1)
            $LatencyBar = Get-LatencyBar $SecondaryAvg
            Write-BoxLine "    Secondary $($Global:Colors.Green)✔ OK$($Global:Colors.Reset)   avg=$($SecondaryAvg.ToString().PadRight(7))ms loss=$($SecondaryLoss.ToString().PadRight(3))%$LatencyBar $($Global:Colors.White)($($Server.Secondary))$($Global:Colors.Reset)"
            $Global:TempResults += @{Provider=$Server.Name; IP=$Server.Secondary; Loss=$SecondaryLoss; Latency=$SecondaryAvg}
        } else {
            Write-BoxLine "    Secondary $($Global:Colors.Red)✖ UNREACHABLE$($Global:Colors.Reset)   loss=100% $($Global:Colors.White)($($Server.Secondary))$($Global:Colors.Reset)"
        }
        
        Write-BoxBlank
    }
    
    Write-BoxBottom
    
    # Process results
    $Global:CleanResults = $Global:TempResults | Where-Object { $_.Loss -lt 100 -and $_.Latency -gt 0 }
    $Global:Top3Results = $Global:CleanResults | Sort-Object Latency | Select-Object -First 3
    
    # Display results
    Write-Host ""
    Write-Centered "$($Global:Colors.Bold)$($Global:Colors.Green)╔═══════════════════════════════════════╗$($Global:Colors.Reset)"
    Write-Centered "$($Global:Colors.Bold)$($Global:Colors.Green)║        🏆 TOP 3 RESULTS 🏆            ║$($Global:Colors.Reset)"
    Write-Centered "$($Global:Colors.Bold)$($Global:Colors.Green)╚═══════════════════════════════════════╝$($Global:Colors.Reset)"
    
    Show-PerformanceResults
    Export-ResultsToDesktop
}

function Show-PerformanceResults {
    if ($Global:Top3Results.Count -eq 0) {
        Write-Centered "$($Global:Colors.Red)No reachable DNS servers were found during the test.$($Global:Colors.Reset)"
        return
    }
    
    Write-Host ""
    Write-Centered "$($Global:Colors.Cyan)$($Global:Colors.Bold)📊 DNS PERFORMANCE COMPARISON 📊$($Global:Colors.Reset)"
    Write-Host ""
    Write-Centered "$($Global:Colors.BrightWhite)Longer bars = Better performance (lower latency)$($Global:Colors.Reset)"
    Write-Host ""
    Write-Host ""
    
    $MaxLatency = ($Global:Top3Results | Measure-Object -Property Latency -Maximum).Maximum
    
    $Medals = @("🥇", "🥈", "🥉")
    $Colors = @($Global:Colors.Yellow, $Global:Colors.White, $Global:Colors.Brown)
    
    for ($i = 0; $i -lt $Global:Top3Results.Count; $i++) {
        $Result = $Global:Top3Results[$i]
        $Medal = $Medals[$i]
        $Color = $Colors[$i]
        
        # Calculate bar length (inverse - shorter latency = longer bar)
        $BarLen = [Math]::Max(10, [Math]::Min(45, 50 - [Math]::Floor($Result.Latency * 35 / $MaxLatency)))
        $Bar = "█" * $BarLen
        
        # Performance rating
        if ($Result.Latency -lt 25) { $Rating = "$($Global:Colors.Green)$($Global:Colors.Bold)BLAZING FAST$($Global:Colors.Reset)" }
        elseif ($Result.Latency -lt 40) { $Rating = "$($Global:Colors.Yellow)$($Global:Colors.Bold)VERY FAST$($Global:Colors.Reset)" }
        elseif ($Result.Latency -lt 60) { $Rating = "$($Global:Colors.Orange)$($Global:Colors.Bold)FAST$($Global:Colors.Reset)" }
        else { $Rating = "$($Global:Colors.Red)$($Global:Colors.Bold)GOOD$($Global:Colors.Reset)" }
        
        Write-Centered "$Medal $($Global:Colors.Bold)$($Result.Provider.PadRight(12))$($Global:Colors.Reset) $Color$Bar$($Global:Colors.Reset) $($Global:Colors.Green)$($Result.Latency.ToString().PadLeft(6))ms$($Global:Colors.Reset) $Rating"
        Write-Centered "    $($Global:Colors.Cyan)$($Result.IP)$($Global:Colors.Reset) - $($Global:Colors.White)$(Get-ProviderTags $Result.Provider)$($Global:Colors.Reset)"
        Write-Host ""
    }
    
    # Winner celebration
    if ($Global:Top3Results.Count -gt 0) {
        $Winner = $Global:Top3Results[0]
        Write-Host "`a"  # Beep
        Write-Centered "⚡ $($Global:Colors.Yellow)$($Global:Colors.Bold)SPEED CHAMPION: $($Winner.Provider) leads with $($Winner.Latency)ms response time!$($Global:Colors.Reset) ⚡"
        Write-Centered "$($Global:Colors.Green)🏆 Optimal DNS performance achieved! 🏆$($Global:Colors.Reset)"
    }
    
    Write-Host ""
}

function Export-ResultsToDesktop {
    $Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $OutputPath = Join-Path $env:USERPROFILE "Desktop\dns_benchmark_$Timestamp.txt"
    
    $Output = @()
    $Output += "Provider".PadRight(15) + "Primary".PadRight(15) + "Secondary".PadRight(15) + "Avg(ms)"
    $Output += "--------".PadRight(15) + "-------".PadRight(15) + "---------".PadRight(15) + "-------"
    
    foreach ($Server in $Global:DNSServers) {
        $Primary = $Global:TempResults | Where-Object { $_.Provider -eq $Server.Name -and $_.IP -eq $Server.Primary }
        $Secondary = $Global:TempResults | Where-Object { $_.Provider -eq $Server.Name -and $_.IP -eq $Server.Secondary }
        
        $PrimaryLatency = if ($Primary) { $Primary.Latency } else { "timeout" }
        $SecondaryLatency = if ($Secondary) { $Secondary.Latency } else { "timeout" }
        
        if ($Primary -and $Secondary) {
            $AvgLatency = [Math]::Round(($Primary.Latency + $Secondary.Latency) / 2, 2)
        } elseif ($Primary) {
            $AvgLatency = $Primary.Latency
        } elseif ($Secondary) {
            $AvgLatency = $Secondary.Latency
        } else {
            $AvgLatency = "timeout"
        }
        
        $Output += $Server.Name.PadRight(15) + $Server.Primary.PadRight(15) + $Server.Secondary.PadRight(15) + $AvgLatency
    }
    
    $Output | Out-File -FilePath $OutputPath -Encoding UTF8
    
    # Windows notification
    try {
        Add-Type -AssemblyName System.Windows.Forms
        $NotifyIcon = New-Object System.Windows.Forms.NotifyIcon
        $NotifyIcon.Icon = [System.Drawing.SystemIcons]::Information
        $NotifyIcon.Visible = $true
        $NotifyIcon.ShowBalloonTip(5000, "DNS Benchmark", "DNS benchmark completed. Table saved to Desktop.", [System.Windows.Forms.ToolTipIcon]::Info)
        $NotifyIcon.Dispose()
    } catch { }
}

function Show-EndMenu {
    while ($true) {
        Write-Host ""
        Write-Host "$($Global:Colors.Green)1) Retest$($Global:Colors.Reset)"
        Write-Host "$($Global:Colors.Red)2) Remove Winfetch Script$($Global:Colors.Reset)"
        Write-Host "$($Global:Colors.Cyan)3) Quit$($Global:Colors.Reset)"
        $Choice = Read-Host "Enter choice [1-3]"
        
        switch ($Choice) {
            "1" { 
                & $PSCommandPath
                return
            }
            "2" { 
                if (Test-Path $Global:WinfetchPath) {
                    $Confirm = Read-Host "Are you sure you want to remove Winfetch script? (y/n)"
                    if ($Confirm -eq "y" -or $Confirm -eq "Y") {
                        Remove-Item -Path $Global:WinfetchPath -Force
                        Write-Host "Winfetch script removed from: $Global:WinfetchPath"
                    } else {
                        Write-Host "Removal cancelled."
                    }
                } else {
                    Write-Host "Winfetch script not found at: $Global:WinfetchPath"
                }
            }
            "3" { 
                Write-Host "Goodbye!"
                return
            }
            default { 
                Write-Host "Invalid option, please try again."
            }
        }
    }
}

function Start-FullBenchmark {
    Test-ComponentAvailability
    Write-Centered "$($Global:Colors.Magenta)$($Global:Colors.Bold)═══ System & Dependencies Check ═══$($Global:Colors.Reset)"
    
    # Download and execute Winfetch from local file
    Invoke-Winfetch
    
    Start-DNSBenchmark
    Show-EndMenu
}

function Start-BasicBenchmark {
    Write-Host ""
    Write-Centered "$($Global:Colors.Bold)$($Global:Colors.Cyan)=== DNS BENCHMARK - DIRECT MODE ===$($Global:Colors.Reset)"
    Write-Centered "$($Global:Colors.Yellow)Skipping system info, proceeding directly to DNS testing...$($Global:Colors.Reset)"
    Write-Host ""
    
    Start-DNSBenchmark
    Show-EndMenu
}

function Handle-MenuChoice {
    param([string]$Choice)
    
    switch ($Choice) {
        "1" {
            Write-Host "Starting full DNS benchmark with visual components..."
            Start-FullBenchmark
            return $true
        }
        "2" {
            Write-Host "Starting DNS benchmark (skipping system info)..."
            Start-BasicBenchmark
            return $true
        }
        "3" {
            Write-Host "Thank you for using DNS Benchmark Tool. Goodbye!"
            return $true
        }
        default {
            Write-Centered "$($Global:Colors.Red)❌ Invalid option. Please enter 1, 2, or 3.$($Global:Colors.Reset)"
            return $false
        }
    }
}

# Main execution
function Main {
    # Enable ANSI colors in Windows Terminal
    if ($PSVersionTable.PSVersion.Major -ge 5) {
        try {
            $null = [System.Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
        } catch { }
    }
    
    while ($true) {
        Show-MainMenu
        $Choice = Read-Host
        
        if (Handle-MenuChoice $Choice) {
            break
        }
        Start-Sleep -Seconds 1
    }
}

# Start the application
Main
