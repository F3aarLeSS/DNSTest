#!/usr/bin/env pwsh
#
# Modern & Clean Windows DNS Benchmark Script using Chocolatey & Winfetch
#

# Strict mode & environment setup
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# ANSI Escape Codes for Styling
$RESET = "`e[0m"
$BOLD = "`e[1m"
$DIM = "`e[2m"
$FG_RED = "`e[31m"
$FG_GREEN = "`e[32m"
$FG_YELLOW = "`e[33m"
$FG_BLUE = "`e[34m"
$FG_MAGENTA = "`e[35m"
$FG_CYAN = "`e[36m"
$FG_WHITE = "`e[37m"
$FG_GRAY = "`e[90m"

# Terminal dimensions & centering helpers
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

# Modern progress spinner with color
function Spinner {
    param([string]$msg, [job]$job)
    $spinnerChars = @("⠋","⠙","⠹","⠸","⠼","⠴","⠦","⠧","⠇","⠏")
    $i = 0
    while ($job.State -eq "Running") {
        $char = $spinnerChars[$i % $spinnerChars.Length]
        Write-Host -NoNewline ("`r" + (" " * $CENTER_OFFSET) + "$FG_CYAN$char$RESET $msg")
        Start-Sleep -Milliseconds 150
        $i++
    }
    Write-Host "`r" + (" " * $CENTER_OFFSET) + (" " * ($msg.Length + 3))
}

function Show-Banner {
    $bannerText = @(
        "██████╗ ███╗   ██╗███████╗",
        "██╔══██╗████╗  ██║██╔════╝",
        "██████╔╝██╔██╗ ██║█████╗  ",
        "██╔═══╝ ██║╚██╗██║██╔══╝  ",
        "██║     ██║ ╚████║███████╗",
        "╚═╝     ╚═╝  ╚═══╝╚══════╝",
        "DNS BENCHMARK"
    )
    foreach ($line in $bannerText) {
        Center-Print "$FG_MAGENTA$BOLD$line$RESET"
    }
    Write-Host ""
}

function Show-InstallationProgress {
    param([string]$task, [ScriptBlock]$action)
    Center-Printf "$FG_YELLOW› %-50s $RESET" $task
    $job = Start-Job -ScriptBlock $action
    Spinner $task $job
    $out = Receive-Job -Job $job -Wait
    Remove-Job -Job $job
    $success = $job.State -eq "Completed"
    if ($success) {
        Center-Printf "$FG_GREEN✔ Completed: %-43s$RESET" $task
    } else {
        Center-Printf "$FG_RED✖ Failed: %-46s$RESET" $task
    }
    Write-Host ""
    return $success
}

function Generate-LatencyBar {
    param([double]$Latency)
    $maxBarLen = 38
    $barChar = "█"
    if ($Latency -lt 30) { $color = $FG_GREEN }
    elseif ($Latency -lt 80) { $color = $FG_YELLOW }
    else { $color = $FG_RED }
    $len = [Math]::Max(4, [Math]::Min($maxBarLen, [Math]::Floor(($maxBarLen * (100 - $Latency)) / 100)))
    return "$color" + ($barChar * $len) + "$RESET"
}

function Display-Results {
    param([string[]]$results)

    Print-BoxTop
    Box-PrintBlank
    Box-Print "$BOLD Provider          | Avg Latency  | Packet Loss | Performance Bar $RESET"
    Print-BoxSeparator

    $rank = 1
    foreach ($result in $results) {
        $fields = $result -split ","
        $provider = $fields[0]
        $ip = $fields[1]
        $loss = [double]$fields[2]
        $latency = [double]$fields[3]

        $status = if ($loss -ge 100) {
            "$FG_RED✖ Unreachable$RESET"
        } else {
            "$FG_GREEN✔ Reachable $RESET"
        }

        $bar = if ($loss -ge 100) { "" } else { Generate-LatencyBar $latency }

        $lossStr = "{0:N1}%" -f $loss
        $latStr = if ($loss -ge 100) { "--" } else { "{0:N1} ms" -f $latency }
        $providerPadded = "{0,-18}" -f $provider

        Box-Print "$providerPadded | $latStr      | $lossStr      | $bar"
        $rank++
    }
    Box-PrintBlank
    Print-BoxBottom
    Write-Host ""

    # Highlight winner
    $winner = $results | Where-Object { ($_ -split ",")[2] -lt 100 } | Sort-Object { [double](($_ -split ",")[3]) } | Select-Object -First 1
    if ($winner) {
        $winParts = $winner -split ","
        $winProvider = $winParts[0]
        $winLatency = [double]$winParts[3]
        Center-Printf "$FG_GREEN$BOLD🏆 Speed Champion: $winProvider with avg latency $winLatency ms! 🏆$RESET"
        Write-Host ""
    }
}

function Run-DnsTest {
    param([string[]]$dnsEntries)

    # Clear previous results
    $tempPaths = @(
        [System.IO.Path]::GetTempFileName(),
        [System.IO.Path]::GetTempFileName(),
        [System.IO.Path]::GetTempFileName()
    )
    $TMP_RESULTS = $tempPaths[0]
    $CLEAN_RESULTS = $tempPaths[1]
    $TOP_3_RESULTS = $tempPaths[2]

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
                    $pingResults = Test-Connection -ComputerName $ipAddr -Count 5 -TimeoutSeconds 1 -ErrorAction Stop
                    $avg = ($pingResults | Measure-Object -Property ResponseTime -Average).Average
                    return @{ Success = $true; Loss = 0; Latency = $avg }
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

    # Pick top 3 only
    $topResults = $filtered | Select-Object -First 3

    Display-Results $topResults
}

# Enhanced Ensure-Dependencies with path update
function Ensure-Dependencies {
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Center-Printf "$FG_YELLOW Installing Chocolatey (package manager)...$RESET"
        try {
            Set-ExecutionPolicy Bypass -Scope Process -Force
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
            
            # Update PATH for current session
            $chocoBin = "C:\ProgramData\chocolatey\bin"
            if (-not $env:PATH.Split(';') -contains $chocoBin) {
                $env:PATH = "$env:PATH;$chocoBin"
                Center-Printf "$FG_GREEN Chocolatey path added to this session's PATH.$RESET`n"
            }
        } catch {
            Center-Printf "$FG_RED Chocolatey installation failed, please install manually.$RESET"
            exit 1
        }
        Center-Printf "$FG_GREEN Chocolatey installed successfully!$RESET`n"
    }

    foreach ($pkg in @("winfetch", "figlet")) {
        if (-not (Get-Command $pkg -ErrorAction SilentlyContinue)) {
            Show-InstallationProgress "Installing $pkg" { choco install $using:pkg -y --no-progress | Out-Null }
        }
    }
}

# Main execution flow
Show-Banner

Center-Printf "$BOLD$FG_MAGENTA System & Dependencies Check $RESET`n"

Ensure-Dependencies

# Display system info
if (Get-Command winfetch -ErrorAction SilentlyContinue) {
    Start-Process -NoNewWindow -FilePath "winfetch" -Wait
}

# DNS Servers
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

Run-DnsTest -dnsEntries $DNS_SERVERS
