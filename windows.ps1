#!/usr/bin/env pwsh
#
# Redesigned Windows_DNS_Benchmark.ps1 with improved visuals
#

# Strict mode & env setup
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# ANSI Escape Codes for Styling
$RESET = "`e[0m"
$BOLD = "`e[1m"
$FG_RED = "`e[31m"
$FG_GREEN = "`e[32m"
$FG_YELLOW = "`e[33m"
$FG_BLUE = "`e[34m"
$FG_MAGENTA = "`e[35m"
$FG_CYAN = "`e[36m"
$FG_WHITE = "`e[37m"
$FG_GRAY = "`e[90m"

# Terminal width and centering helper
$TERMINAL_COLS = [Console]::WindowWidth
$BOX_WIDTH = 70
$CENTER_OFFSET = [Math]::Max(0, [Math]::Floor(($TERMINAL_COLS - $BOX_WIDTH) / 2))

function Center-Print {
    param([string]$Content)
    Write-Host (" " * $CENTER_OFFSET + $Content)
}
function Center-Printf {
    param([string]$Format, [object[]]$Args)
    $content = $Format -f $Args
    Center-Print $content
}

function Print-BoxTop {
    Center-Print ("╭" + ("─" * ($BOX_WIDTH - 2)) + "╮")
}
function Print-BoxBottom {
    Center-Print ("╰" + ("─" * ($BOX_WIDTH - 2)) + "╯")
}
function Print-BoxSeparator {
    Center-Print ("├" + ("─" * ($BOX_WIDTH - 2)) + "┤")
}
function Box-Print {
    param([string]$Content)
    $cleanLength = ($Content -replace '\x1b\[[0-9;]*m','').Length
    $padding = [Math]::Max(0, $BOX_WIDTH - 4 - $cleanLength)
    Center-Print ("│ " + $Content + (" " * $padding) + " │")
}
function Box-PrintBlank {
    Center-Print ("│" + (" " * ($BOX_WIDTH - 2)) + "│")
}

function Show-Header {
    param([string]$Text)
    Write-Host ""
    Center-Print "$BOLD$FG_CYAN$text$RESET"
    Write-Host ""
}

function Generate-LatencyBar {
    param([double]$Latency)
    $maxBarLen = 40
    $barChar = "█"
    if ($Latency -lt 30) { $color = $FG_GREEN }
    elseif ($Latency -lt 80) { $color = $FG_YELLOW }
    else { $color = $FG_RED }
    $len = [Math]::Max(5, [Math]::Min($maxBarLen, [Math]::Floor(($maxBarLen * (100 - $Latency))/100)))
    return "$color" + ($barChar * $len) + "$RESET"
}

# Simple progress spinner while running background jobs
function Spinner {
    param([string]$msg, [job]$job)
    $spinnerChars = @("⠋","⠙","⠹","⠸","⠼","⠴","⠦","⠧","⠇","⠏")
    $i = 0
    while ($job.State -eq "Running") {
        $char = $spinnerChars[$i % $spinnerChars.Length]
        Write-Host -NoNewline ("`r" + (" " * $CENTER_OFFSET) + "$FG_YELLOW$char$RESET $msg...")
        Start-Sleep -Milliseconds 150
        $i++
    }
    Write-Host "`r" + " " * $CENTER_OFFSET + " " * ($msg.Length + 5)
}

function Display-Results {
    param([string[]]$Results)

    Print-BoxTop
    Box-PrintBlank
    Box-Print "$BOLD DNS Provider       │ Avg Latency │ Packet Loss │ Performance Bar $RESET"
    Print-BoxSeparator

    $rank = 1
    foreach ($result in $Results) {
        $fields = $result -split ","
        $provider = $fields[0]
        $ip = $fields[1]
        $loss = [double]$fields[2]
        $latency = [double]$fields[3]

        $status = if ($loss -ge 100) {
            "$FG_RED✖ Unreachable$RESET"
        } else {
            "$FG_GREEN✔ Reachable$RESET"
        }

        $bar = if ($loss -ge 100) { "" } else { Generate-LatencyBar $latency }
        $lossStr = "{0:N1}%" -f $loss
        $latStr = if ($loss -ge 100) { "--" } else { "{0:N1} ms" -f $latency }
        $providerName = "{0,-18}" -f $provider

        Box-Print "$providerName │ $latStr     │ $lossStr     │ $bar"
        $rank++
    }
    Box-PrintBlank
    Print-BoxBottom
    Write-Host ""

    # Highlight winner
    $winner = $Results | Where-Object { ($_ -split ",")[2] -lt 100 } | Sort-Object { [double](($_ -split ",")[3]) } | Select-Object -First 1
    if ($winner) {
        $winParts = $winner -split ","
        $winProvider = $winParts[0]
        $winLatency = [double]$winParts[3]
        Center-Printf "$FG_GREEN$BOLD🏆 Speed Champion: $winProvider with average latency $winLatency ms! 🏆$RESET"
        Write-Host ""
    }
}

function Run-DnsTest {
    param([string[]]$dnsEntries)
    # Clean previous results
    Remove-Item -Path $TMP_RESULTS, $CLEAN_RESULTS, $TOP_3_RESULTS -ErrorAction SilentlyContinue

    $allResults = @()

    foreach ($entry in $dnsEntries) {
        $fields = $entry -split ","
        $provider = $fields[0]
        $primaryIp = $fields[1]
        $secondaryIp = $fields[2]

        foreach ($ipType in @("Primary", "Secondary")) {
            $ip = if ($ipType -eq "Primary") { $primaryIp } else { $secondaryIp }

            # Run test in background job
            $job = Start-Job -ScriptBlock {
                param($ipAddr)
                try {
                    $pingResults = Test-Connection -ComputerName $ipAddr -Count 5 -TimeoutSeconds 1
                    if ($pingResults) {
                        $avg = ($pingResults | Measure-Object -Property ResponseTime -Average).Average
                        return @{ Success = $true; Loss = 0; Latency = $avg }
                    } else {
                        return @{ Success = $false; Loss = 100; Latency = 0 }
                    }
                } catch {
                    return @{ Success = $false; Loss = 100; Latency = 0 }
                }
            } -ArgumentList $ip

            Spinner "$provider $ipType ($ip)" $job
            $result = Receive-Job -Job $job -Wait
            Remove-Job -Job $job

            $loss = if ($result.Loss) { $result.Loss } else { 100 }
            $latency = if ($result.Latency) { $result.Latency } else { 0 }

            $allResults += "$provider,$ip,$loss,$latency"
        }
    }

    # Filter reachable only and sort by latency
    $filtered = $allResults | Where-Object {
        $parts = $_ -split ","
        ([double]$parts[2]) -lt 100
    } | Sort-Object {
        $parts = $_ -split ","
        [double]$parts[3]
    }

    # Pick top 3 only, or less if less results
    $topResults = $filtered | Select-Object -First 3

    Display-Results $topResults
}

# --- Main Execution ---

Center-Print "$BOLD$FG_MAGENTA =============== System & Dependency Check =============== $RESET`n"

# Check & install dependencies (choco, winfetch, figlet)
function Ensure-Dependencies {
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Center-Printf "$FG_YELLOW Installing Chocolatey (package manager)...$RESET"
        try {
            Set-ExecutionPolicy Bypass -Scope Process -Force
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        } catch {
            Center-Printf "$FG_RED Chocolatey installation failed, please install manually.$RESET"
            exit 1
        }
        Center-Printf "$FG_GREEN Chocolatey installed successfully!$RESET"
        Start-Sleep 1
    }

    foreach ($pkg in @("winfetch", "figlet")) {
        if (-not (Get-Command $pkg -ErrorAction SilentlyContinue)) {
            Center-Printf "$FG_YELLOW Installing $pkg...$RESET"
            choco install $pkg -y --no-progress | Out-Null
        }
    }
}
Ensure-Dependencies

# Show system info with winfetch
Write-Host ""
if (Get-Command winfetch -ErrorAction SilentlyContinue) {
    Start-Process -NoNewWindow -FilePath "winfetch" -Wait
}

# Banner
if (Get-Command figlet -ErrorAction SilentlyContinue) {
    figlet -w 70 "DNS BENCHMARK" | ForEach-Object { Center-Print $_ }
} else {
    Center-Print "$BOLD$FG_CYAN ======= DNS BENCHMARK ======= $RESET"
}

# DNS Servers List
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

# Run the DNS latency tests and display results
Run-DnsTest -dnsEntries $DNS_SERVERS
