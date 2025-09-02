<#
.SYNOPSIS
    DNS Benchmark Tool for Windows - Universal Terminal Compatible
.DESCRIPTION
    A PowerShell script to test DNS server latency and display results with enhanced visuals.
    Supports both full mode with system info and basic mode for quick testing.
    Compatible with all terminal types including legacy PowerShell consoles.
.NOTES
    Version: 2.0
    Author: DNS Benchmark Tool
    Requires: PowerShell 5.1+
    Compatible: Windows PowerShell 5.1, PowerShell 7+, Windows Terminal, VS Code Terminal
#>

# Set strict mode and error handling
Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

# === UNIVERSAL TERMINAL COMPATIBILITY ===
$script:SupportsANSI = $false
$script:IsLegacyConsole = $false

function Initialize-TerminalCapabilities {
    param()
    
    try {
        # Method 1: Check built-in PowerShell capability
        if ($Host.UI.SupportsVirtualTerminal -eq $true) {
            $script:SupportsANSI = $true
            Write-Verbose "ANSI support detected via Host.UI.SupportsVirtualTerminal"
            return
        }
        
        # Method 2: Check for Windows Terminal
        if ($env:WT_SESSION -or $env:WT_PROFILE_ID) {
            $script:SupportsANSI = $true
            Write-Verbose "Windows Terminal detected"
            return
        }
        
        # Method 3: Check PowerShell version (7+ has better ANSI support)
        if ($PSVersionTable.PSVersion.Major -ge 7) {
            $script:SupportsANSI = $true
            Write-Verbose "PowerShell 7+ detected"
            return
        }
        
        # Method 4: Try to enable VT Processing on Windows Console
        if ($PSVersionTable.Platform -eq 'Win32NT' -or [System.Environment]::OSVersion.Platform -eq 'Win32NT' -or -not (Get-Variable -Name 'IsLinux' -ErrorAction SilentlyContinue)) {
            $script:IsLegacyConsole = $true
            if (Enable-VTProcessing) {
                $script:SupportsANSI = $true
                Write-Verbose "VT Processing enabled successfully"
                return
            }
        }
        
        Write-Verbose "ANSI support not available - using fallback mode"
        
    } catch {
        Write-Verbose "Error during terminal capability detection: $($_.Exception.Message)"
    }
}

function Enable-VTProcessing {
    try {
        # Add Windows API functions
        $VTSignature = @'
            [DllImport("kernel32.dll", SetLastError = true)]
            public static extern IntPtr GetStdHandle(int nStdHandle);
            
            [DllImport("kernel32.dll", SetLastError = true)]
            public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);
            
            [DllImport("kernel32.dll", SetLastError = true)]
            public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
'@
        
        # Only add the type if it doesn't exist
        if (-not ([System.Management.Automation.PSTypeName]'Win32.Console').Type) {
            Add-Type -MemberDefinition $VTSignature -Name 'Console' -Namespace 'Win32' -ErrorAction SilentlyContinue | Out-Null
        }
        
        # Get stdout handle
        $stdOutHandle = [Win32.Console]::GetStdHandle(-11) # STD_OUTPUT_HANDLE
        
        # Get current console mode
        $currentMode = 0
        if ([Win32.Console]::GetConsoleMode($stdOutHandle, [ref]$currentMode)) {
            # Enable ENABLE_VIRTUAL_TERMINAL_PROCESSING (0x0004)
            $newMode = $currentMode -bor 0x0004
            return [Win32.Console]::SetConsoleMode($stdOutHandle, $newMode)
        }
        
        return $false
    } catch {
        return $false
    }
}

function Set-ColorSupport {
    if ($script:SupportsANSI) {
        # Enable full ANSI color support
        try {
            [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
        } catch {
            # Fallback for older PowerShell versions
            [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        }
        
        # Define ANSI colors
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
        return
    }
    
    # Disable all colors by making them empty strings
    $Global:Colors = @{
        Reset = ""; Bold = ""; Red = ""; Green = ""; Yellow = "";
        Blue = ""; Magenta = ""; Cyan = ""; White = ""; BrightWhite = "";
        Gray = ""; Orange = ""; Brown = ""
    }
}

# Initialize terminal capabilities
Initialize-TerminalCapabilities
Set-ColorSupport

# Global Variables
$Global:TempResults = @()
$Global:CleanResults = @()
$Global:Top3Results = @()

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

function Show-TerminalInfo {
    Write-Host ""
    if ($script:SupportsANSI) {
        Write-Centered "$($Global:Colors.Green)✅ Enhanced visual mode enabled$($Global:Colors.Reset)"
        if ($script:IsLegacyConsole) {
            Write-Centered "$($Global:Colors.Yellow)ℹ️  VT Processing enabled for legacy console$($Global:Colors.Reset)"
        }
    } else {
        Write-Centered "$($Global:Colors.Yellow)⚠️  Running in compatibility mode (no colors)$($Global:Colors.Reset)"
        Write-Centered "   For enhanced visuals, use Windows Terminal or PowerShell 7+"
    }
    Write-Host ""
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
    
    Show-TerminalInfo
    
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
                        $TestConnection = Test-NetConnection -ComputerName "raw.githubusercontent.com" -Port 443 -InformationLevel Quiet -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
                        if ($TestConnection) {
                            $Status = "AVAILABLE"; $StatusColor = $Global:Colors.Yellow
                            $Details = "Download required"
                        } else {
                            $Status = "UNAVAILABLE"; $StatusColor = $Global:Colors.Red
                            $Details = "Network required"
                        }
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
                    $TestResult = Test-Connection "8.8.8.8" -Count 1 -Quiet -TimeoutSec 3 -ErrorAction SilentlyContinue
                    if ($TestResult) {
                        $Status = "CONNECTED"; $StatusColor = $Global:Colors.Green
                        $Details = "Internet ready"
                    } else {
                        $Status = "OFFLINE"; $StatusColor = $Global:Colors.Red
                        $Details = "No connection"
                    }
                } catch {
                    $Status = "OFFLINE"; $StatusColor = $Global:Colors.Red
                    $Details = "No connection"
                }
            }
            "terminal" { 
                if ($script:SupportsANSI) {
                    $Status = "ENHANCED"; $StatusColor = $Global:Colors.Green
                    $Details = "$($Global:TerminalWidth)x$($Host.UI.RawUI.WindowSize.Height) ANSI"
                } else {
                    $Status = "BASIC"; $StatusColor = $Global:Colors.Yellow
                    $Details = "$($Global:TerminalWidth)x$($Host.UI.RawUI.WindowSize.Height) Text"
                }
            }
        }
        
        Write-Host ("`r" + (" " * $Global:CenterOffset) + "$($Global:Colors.Bold)$($Global:Colors.Cyan)$($Component.Name) $($Component.Description) ".PadRight(35) + " $StatusColor$Status$($Global:Colors.Reset) - $Details$($Global:Colors.Reset)")
        Start-Sleep -Milliseconds 100
    }
    
    Write-Host ""
    Write-Centered "$($Global:Colors.Bold)$($Global:Colors.Green)🎉 System ready for DNS benchmarking!$($Global:Colors.Reset)"
    Write-Host ""
    Write-Centered "$($Global:Colors.Blue)Press any key to continue...$($Global:Colors.Reset)"
    try {
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    } catch {
        Read-Host
    }
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
    param(
        [switch]$NoCache  # If set, forces fresh download & in-memory run
    )

    Write-Host ""
    Write-Centered "$($Global:Colors.Yellow)💻 Loading system information with Winfetch...$($Global:Colors.Reset)"
    Write-Host ""

    try {
        # Initialize global variables Winfetch may expect
        if (-not (Get-Variable -Name CustomAscii -Scope Global -ErrorAction SilentlyContinue)) {
            $Global:CustomAscii = $null
        }
        if (-not (Get-Variable -Name CustomPkgs -Scope Global -ErrorAction SilentlyContinue)) {
            $Global:CustomPkgs = @()
        }

        # Initialize scoop variables to avoid errors
        if (-not (Get-Variable -Name scooppkg -Scope Script -ErrorAction SilentlyContinue)) {
            $script:scooppkg = @()
        }
        if (-not (Get-Variable -Name scoopapps -Scope Script -ErrorAction SilentlyContinue)) {
            $script:scoopapps = @()
        }

        if ($NoCache) {
            # Run Winfetch directly in memory
            Write-Centered "$($Global:Colors.Cyan)⬇️ Downloading and running Winfetch in-memory...$($Global:Colors.Reset)"
            $scriptContent = (Invoke-WebRequest "https://raw.githubusercontent.com/lptstr/winfetch/master/winfetch.ps1" -UseBasicParsing).Content
            . ([scriptblock]::Create($scriptContent))
        } else {
            # Cache path
            $cachePath = "$env:TEMP\winfetch.ps1"
            if (-not (Test-Path $cachePath)) {
                Write-Centered "$($Global:Colors.Cyan)⬇️ Downloading Winfetch...$($Global:Colors.Reset)"
                (Invoke-WebRequest "https://raw.githubusercontent.com/lptstr/winfetch/master/winfetch.ps1" -UseBasicParsing).Content |
                    Out-File -FilePath $cachePath -Encoding UTF8
            }
            . $cachePath
        }

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

# (script header stays the same)

# … [all your existing functions above remain unchanged] …

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
        
        # --- Primary DNS Test ---
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
        
        # --- Secondary DNS Test ---
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
    Write-Host ""
    Write-Centered "$($Global:Colors.Green)✔ Benchmark completed successfully!$($Global:Colors.Reset)"
}

# === Entry Point ===
do {
    Show-MainMenu
    $choice = Read-Host
    
    switch ($choice) {
        "1" {
            Test-ComponentAvailability
            Invoke-Winfetch
            Start-DNSBenchmark
            Pause
        }
        "2" {
            Start-DNSBenchmark
            Pause
        }
        "3" {
            Write-Centered "$($Global:Colors.Red)👋 Exiting DNS Benchmark Tool...$($Global:Colors.Reset)"
            break
        }
        default {
            Write-Centered "$($Global:Colors.Yellow)⚠️ Invalid choice. Please enter 1, 2, or 3.$($Global:Colors.Reset)"
            Start-Sleep -Seconds 2
        }
    }
} while ($true)
