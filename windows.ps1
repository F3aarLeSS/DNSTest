#Requires -Version 7.0

<#
.SYNOPSIS
    DNS Benchmark Tool - PowerShell 7+ Native Implementation
    
.DESCRIPTION
    A comprehensive DNS latency benchmark tool that tests common DNS providers,
    ranks them by performance, and displays results with animated progress and
    styled console output. Native Windows implementation without WSL dependencies.

.PARAMETER Count
    Number of ping tests per DNS server (default: 5)
    
.PARAMETER TimeoutMs
    Timeout in milliseconds per ping test (default: 500)
    
.PARAMETER BoxWidth
    Width of the display box (default: 96)
    
.PARAMETER NoColor
    Disable ANSI color output for compatibility
    
.EXAMPLE
    .\DNS-Benchmark.ps1
    
.EXAMPLE
    .\DNS-Benchmark.ps1 -Count 10 -TimeoutMs 1000 -NoColor
#>

[CmdletBinding()]
param(
    [int]$Count = 5,
    [int]$TimeoutMs = 500,
    [int]$BoxWidth = 96,
    [switch]$NoColor
)

# =============================================================================
# GLOBAL VARIABLES AND CONFIGURATION
# =============================================================================

$Global:BOX_WIDTH = $BoxWidth
$Global:PING_COUNT = $Count
$Global:PING_TIMEOUT_MS = $TimeoutMs
$Global:USE_ANSI = -not $NoColor -and $PSVersionTable.PSVersion.Major -ge 7

# ANSI Escape sequences for PowerShell 7+
if ($Global:USE_ANSI) {
    $esc = "`e"
} else {
    $esc = [char]0x1b
}

# ANSI Color codes
$Global:Colors = @{
    Reset     = if ($Global:USE_ANSI) { "$esc[0m" } else { "" }
    Bold      = if ($Global:USE_ANSI) { "$esc[1m" } else { "" }
    Red       = if ($Global:USE_ANSI) { "$esc[31m" } else { "" }
    Green     = if ($Global:USE_ANSI) { "$esc[32m" } else { "" }
    Yellow    = if ($Global:USE_ANSI) { "$esc[33m" } else { "" }
    Blue      = if ($Global:USE_ANSI) { "$esc[34m" } else { "" }
    Magenta   = if ($Global:USE_ANSI) { "$esc[35m" } else { "" }
    Cyan      = if ($Global:USE_ANSI) { "$esc[36m" } else { "" }
    White     = if ($Global:USE_ANSI) { "$esc[37m" } else { "" }
    BgBlue    = if ($Global:USE_ANSI) { "$esc[44m" } else { "" }
    BgGreen   = if ($Global:USE_ANSI) { "$esc[42m" } else { "" }
}

# DNS Provider Configuration
$Global:DNSProviders = @(
    @{ Name = "Cloudflare"; Primary = "1.1.1.1"; Secondary = "1.0.0.1"; Tag = "Speed, Privacy, Modern" },
    @{ Name = "Google"; Primary = "8.8.8.8"; Secondary = "8.8.4.4"; Tag = "Reliable, Fast, Global" },
    @{ Name = "Quad9"; Primary = "9.9.9.9"; Secondary = "149.112.112.112"; Tag = "Security, Threat Blocking" },
    @{ Name = "OpenDNS"; Primary = "208.67.222.222"; Secondary = "208.67.220.220"; Tag = "Family Safe, Filtering" },
    @{ Name = "AdGuard"; Primary = "94.140.14.14"; Secondary = "94.140.15.15"; Tag = "Ad Blocking, Privacy" },
    @{ Name = "CleanBrowsing"; Primary = "185.228.168.9"; Secondary = "185.228.169.9"; Tag = "Family Filter, Safe" },
    @{ Name = "Comodo"; Primary = "8.26.56.26"; Secondary = "8.20.247.20"; Tag = "Secure, Malware Protection" },
    @{ Name = "Verisign"; Primary = "64.6.64.6"; Secondary = "64.6.65.6"; Tag = "Stable, Public DNS" }
)

# Results storage
$Global:TestResults = @()

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

function Strip-AnsiCodes {
    param([string]$Text)
    return $Text -replace '\x1b\[[0-9;]*m', ''
}

function Get-ConsoleWidth {
    try {
        $width = $Host.UI.RawUI.WindowSize.Width
        if ($width -lt 80) { return 80 }
        return $width
    }
    catch {
        return 120
    }
}

function Center-Print {
    param(
        [string]$Text,
        [string]$Color = "White"
    )
    
    $consoleWidth = Get-ConsoleWidth
    $cleanText = Strip-AnsiCodes -Text $Text
    $textLength = $cleanText.Length
    $leftPadding = [Math]::Max(0, [Math]::Floor(($consoleWidth - $textLength) / 2))
    
    $colorCode = $Global:Colors[$Color]
    $resetCode = $Global:Colors.Reset
    
    Write-Host (" " * $leftPadding) -NoNewline
    Write-Host "$colorCode$Text$resetCode"
}

function Center-Format {
    param(
        [string]$Text,
        [int]$Width = $Global:BOX_WIDTH
    )
    
    $cleanText = Strip-AnsiCodes -Text $Text
    $textLength = $cleanText.Length
    $consoleWidth = Get-ConsoleWidth
    $leftOffset = [Math]::Max(0, [Math]::Floor(($consoleWidth - $Width) / 2))
    $leftPadding = [Math]::Max(0, [Math]::Floor(($Width - $textLength) / 2))
    
    return (" " * $leftOffset) + (" " * $leftPadding) + $Text
}

function Print-BoxTop {
    $line = "╭" + ("─" * ($Global:BOX_WIDTH - 2)) + "╮"
    Center-Print -Text $line -Color "Cyan"
}

function Print-BoxBottom {
    $line = "╰" + ("─" * ($Global:BOX_WIDTH - 2)) + "╯"
    Center-Print -Text $line -Color "Cyan"
}

function Print-BoxSeparator {
    $line = "├" + ("─" * ($Global:BOX_WIDTH - 2)) + "┤"
    Center-Print -Text $line -Color "Cyan"
}

function Print-BoxBlank {
    $line = "│" + (" " * ($Global:BOX_WIDTH - 2)) + "│"
    Center-Print -Text $line -Color "Cyan"
}

function Print-BoxLine {
    param([string]$Content)
    
    $cleanContent = Strip-AnsiCodes -Text $Content
    $contentLength = $cleanContent.Length
    $maxContentWidth = $Global:BOX_WIDTH - 4
    
    if ($contentLength -gt $maxContentWidth) {
        $Content = $Content.Substring(0, $maxContentWidth - 3) + "..."
        $contentLength = $maxContentWidth
    }
    
    $padding = $maxContentWidth - $contentLength
    $line = "│ $Content" + (" " * $padding) + " │"
    Center-Print -Text $line -Color "Cyan"
}

# =============================================================================
# ANIMATION AND PROGRESS FUNCTIONS
# =============================================================================

function Show-Spinner {
    param(
        [string]$Message,
        [scriptblock]$ScriptBlock
    )
    
    $spinnerChars = @('⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏')
    $spinnerIndex = 0
    
    # Start the background job
    $job = Start-Job -ScriptBlock $ScriptBlock
    
    # Show spinner while job is running
    while ($job.State -eq 'Running') {
        $spinnerChar = $spinnerChars[$spinnerIndex % $spinnerChars.Length]
        $displayMessage = " $spinnerChar $Message"
        Print-BoxLine -Content "$($Global:Colors.Yellow)$displayMessage$($Global:Colors.Reset)"
        
        Start-Sleep -Milliseconds 100
        $spinnerIndex++
        
        # Move cursor up to overwrite the spinner line
        if ($Global:USE_ANSI) {
            Write-Host "$esc[1A$esc[2K" -NoNewline
        }
    }
    
    # Get the job result and clean up
    $result = Receive-Job -Job $job
    Remove-Job -Job $job
    
    return $result
}

function Generate-LatencyBar {
    param(
        [double]$Latency,
        [double]$MaxLatency,
        [int]$MaxBarLength = 40
    )
    
    if ($Latency -le 0 -or $MaxLatency -le 0) {
        return ""
    }
    
    # Inverse relationship: lower latency = longer bar
    $barLength = [Math]::Max(1, [Math]::Round($MaxBarLength * (1 - ($Latency / ($MaxLatency * 1.2)))))
    
    # Color coding based on latency
    $color = if ($Latency -lt 30) { "Green" }
             elseif ($Latency -lt 80) { "Yellow" }
             else { "Red" }
    
    $bar = "█" * $barLength
    $colorCode = $Global:Colors[$color]
    $resetCode = $Global:Colors.Reset
    
    return "$colorCode$bar$resetCode"
}

# =============================================================================
# HEADER AND BANNER FUNCTIONS
# =============================================================================

function Print-Header {
    Clear-Host
    Print-BoxTop
    Print-BoxBlank
    
    # DNS BENCHMARK title
    $title = "$($Global:Colors.Bold)$($Global:Colors.Blue)DNS BENCHMARK$($Global:Colors.Reset)"
    Print-BoxLine -Content (Center-Format -Text $title -Width ($Global:BOX_WIDTH - 4))
    Print-BoxBlank
    
    # System information
    try {
        $computerInfo = Get-ComputerInfo -Property WindowsProductName, TotalPhysicalMemory -ErrorAction SilentlyContinue
        if ($computerInfo) {
            $os = $computerInfo.WindowsProductName
            $ram = [Math]::Round($computerInfo.TotalPhysicalMemory / 1GB, 1)
            $sysInfo = "System: $os | RAM: ${ram}GB | PS: $($PSVersionTable.PSVersion)"
            Print-BoxLine -Content (Center-Format -Text $sysInfo -Width ($Global:BOX_WIDTH - 4))
            Print-BoxBlank
        }
    }
    catch {
        # Skip system info if unavailable
    }
    
    Print-BoxSeparator
}

function Print-ProviderHeader {
    param([string]$ProviderName)
    
    $header = "$($Global:Colors.Bold)$($Global:Colors.Magenta)Testing $ProviderName DNS Servers$($Global:Colors.Reset)"
    Print-BoxLine -Content (Center-Format -Text $header -Width ($Global:BOX_WIDTH - 4))
    Print-BoxBlank
}

function Print-TopResultsHeader {
    Print-BoxSeparator
    Print-BoxBlank
    
    $title = "$($Global:Colors.Bold)$($Global:Colors.Green)🏆 TOP 3 DNS SERVERS 🏆$($Global:Colors.Reset)"
    Print-BoxLine -Content (Center-Format -Text $title -Width ($Global:BOX_WIDTH - 4))
    Print-BoxBlank
    Print-BoxSeparator
}

# =============================================================================
# DNS TESTING FUNCTIONS
# =============================================================================

function Test-DNSLatency {
    param(
        [string]$IPAddress,
        [int]$Count = $Global:PING_COUNT,
        [int]$TimeoutMs = $Global:PING_TIMEOUT_MS
    )
    
    try {
        $results = Test-Connection -ComputerName $IPAddress -Count $Count -TimeoutSeconds ($TimeoutMs / 1000) -ErrorAction Stop
        
        $successfulPings = $results | Where-Object { $_.Status -eq 'Success' }
        $totalPings = $results.Count
        $successfulCount = $successfulPings.Count
        
        if ($successfulCount -gt 0) {
            $avgLatency = ($successfulPings | Measure-Object -Property Latency -Average).Average
            $packetLoss = (($totalPings - $successfulCount) / $totalPings) * 100
        } else {
            $avgLatency = $null
            $packetLoss = 100
        }
        
        return @{
            AvgLatency = $avgLatency
            PacketLoss = $packetLoss
            SuccessfulPings = $successfulCount
            TotalPings = $totalPings
        }
    }
    catch {
        return @{
            AvgLatency = $null
            PacketLoss = 100
            SuccessfulPings = 0
            TotalPings = $Count
        }
    }
}

function Test-DNSProvider {
    param($Provider)
    
    Print-ProviderHeader -ProviderName $Provider.Name
    
    # Test Primary DNS
    $primaryResult = Show-Spinner -Message "Testing Primary DNS ($($Provider.Primary))..." -ScriptBlock {
        Test-DNSLatency -IPAddress $using:Provider.Primary
    }
    
    # Display primary result
    if ($primaryResult.PacketLoss -lt 100) {
        $latencyText = "{0:F1}ms" -f $primaryResult.AvgLatency
        $lossText = "{0:F1}%" -f $primaryResult.PacketLoss
        $status = "$($Global:Colors.Green)✓ PRIMARY$($Global:Colors.Reset) $($Provider.Primary) - ${latencyText} (${lossText} loss)"
    } else {
        $status = "$($Global:Colors.Red)✗ PRIMARY$($Global:Colors.Reset) $($Provider.Primary) - Unreachable"
    }
    Print-BoxLine -Content " $status"
    
    # Test Secondary DNS
    $secondaryResult = Show-Spinner -Message "Testing Secondary DNS ($($Provider.Secondary))..." -ScriptBlock {
        Test-DNSLatency -IPAddress $using:Provider.Secondary
    }
    
    # Display secondary result
    if ($secondaryResult.PacketLoss -lt 100) {
        $latencyText = "{0:F1}ms" -f $secondaryResult.AvgLatency
        $lossText = "{0:F1}%" -f $secondaryResult.PacketLoss
        $status = "$($Global:Colors.Green)✓ SECONDARY$($Global:Colors.Reset) $($Provider.Secondary) - ${latencyText} (${lossText} loss)"
    } else {
        $status = "$($Global:Colors.Red)✗ SECONDARY$($Global:Colors.Reset) $($Provider.Secondary) - Unreachable"
    }
    Print-BoxLine -Content " $status"
    
    # Provider tag
    $tagText = "$($Global:Colors.Blue)📋 $($Provider.Tag)$($Global:Colors.Reset)"
    Print-BoxLine -Content " $tagText"
    Print-BoxBlank
    
    # Store results
    if ($primaryResult.PacketLoss -lt 100) {
        $Global:TestResults += [PSCustomObject]@{
            Provider = $Provider.Name
            IP = $Provider.Primary
            Type = "Primary"
            AvgLatency = $primaryResult.AvgLatency
            PacketLoss = $primaryResult.PacketLoss
        }
    }
    
    if ($secondaryResult.PacketLoss -lt 100) {
        $Global:TestResults += [PSCustomObject]@{
            Provider = $Provider.Name
            IP = $Provider.Secondary
            Type = "Secondary"
            AvgLatency = $secondaryResult.AvgLatency
            PacketLoss = $secondaryResult.PacketLoss
        }
    }
}

# =============================================================================
# RESULTS PROCESSING AND DISPLAY
# =============================================================================

function Show-TopResults {
    # Filter and sort results
    $validResults = $Global:TestResults | Where-Object { 
        $_.AvgLatency -ne $null -and $_.PacketLoss -lt 100 
    } | Sort-Object AvgLatency | Select-Object -First 3
    
    if ($validResults.Count -eq 0) {
        Print-BoxLine -Content " $($Global:Colors.Red)No DNS servers were reachable!$($Global:Colors.Reset)"
        Print-BoxBlank
        return
    }
    
    Print-TopResultsHeader
    
    $maxLatency = ($validResults | Measure-Object -Property AvgLatency -Maximum).Maximum
    $medals = @("🥇", "🥈", "🥉")
    
    for ($i = 0; $i -lt $validResults.Count; $i++) {
        $result = $validResults[$i]
        $medal = $medals[$i]
        $rank = $i + 1
        
        $latencyText = "{0:F1}ms" -f $result.AvgLatency
        $lossText = "{0:F1}%" -f $result.PacketLoss
        
        # Generate latency bar
        $bar = Generate-LatencyBar -Latency $result.AvgLatency -MaxLatency $maxLatency
        
        # Format the result line
        $resultLine = " $medal #$rank $($Global:Colors.Bold)$($result.Provider)$($Global:Colors.Reset) ($($result.IP)) - $latencyText"
        Print-BoxLine -Content $resultLine
        
        $barLine = "     $bar ($lossText loss)"
        Print-BoxLine -Content $barLine
        
        if ($i -lt $validResults.Count - 1) {
            Print-BoxBlank
        }
    }
    
    Print-BoxBlank
}

# =============================================================================
# MAIN EXECUTION FUNCTION
# =============================================================================

function Start-DNSBenchmark {
    # Initialize
    $Global:TestResults = @()
    
    # Print header
    Print-Header
    
    # Test each DNS provider
    foreach ($provider in $Global:DNSProviders) {
        Test-DNSProvider -Provider $provider
    }
    
    # Show top results
    Show-TopResults
    
    # Footer
    Print-BoxSeparator
    $footerText = "Benchmark completed! Tested $($Global:DNSProviders.Count) DNS providers with $Global:PING_COUNT pings each."
    Print-BoxLine -Content (Center-Format -Text $footerText -Width ($Global:BOX_WIDTH - 4))
    Print-BoxBlank
    Print-BoxBottom
    
    Write-Host ""
    Write-Host "$($Global:Colors.Green)DNS Benchmark Complete!$($Global:Colors.Reset)" -ForegroundColor Green
    Write-Host "Results saved to `$Global:TestResults variable for further analysis." -ForegroundColor Gray
}

# =============================================================================
# SCRIPT ENTRY POINT
# =============================================================================

# Validate PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Error "This script requires PowerShell 7.0 or higher. Current version: $($PSVersionTable.PSVersion)"
    exit 1
}

# Check for Windows platform
if (-not $IsWindows -and $PSVersionTable.PSVersion.Major -ge 6) {
    Write-Warning "This script is optimized for Windows. Some features may not work correctly on other platforms."
}

# Run the benchmark
try {
    Start-DNSBenchmark
}
catch {
    Write-Error "An error occurred during the DNS benchmark: $($_.Exception.Message)"
    Write-Error "Stack Trace: $($_.ScriptStackTrace)"
}

# Export results to CSV option
$exportChoice = Read-Host "`nWould you like to export results to CSV? (y/N)"
if ($exportChoice -eq 'y' -or $exportChoice -eq 'Y') {
    $csvPath = "DNS-Benchmark-Results-$(Get-Date -Format 'yyyyMMdd-HHmmss').csv"
    $Global:TestResults | Export-Csv -Path $csvPath -NoTypeInformation
    Write-Host "Results exported to: $csvPath" -ForegroundColor Green
}
