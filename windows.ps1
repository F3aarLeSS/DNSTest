# Modern Windows DNS Benchmark with Inline Winfetch Execution
# Description: Checks/installs and runs winfetch inline, then performs DNS latency tests with sleek modern output.
#
# Usage: Run with PowerShell, ensure execution policy permits script and remote invocation.
#
# Note: winfetch runs inline without saving to disk for a clean, dependency-light experience.

# --- ANSI Color & Style Definitions ---
$esc = "$([char]27)"
$RESET = "$esc[0m"
$BOLD = "$esc[1m"
$DIM = "$esc[2m"
$FG_RED = "$esc[31m"
$FG_GREEN = "$esc[32m"
$FG_YELLOW = "$esc[33m"
$FG_BLUE = "$esc[34m"
$FG_MAGENTA = "$esc[35m"
$FG_CYAN = "$esc[36m"
$FG_WHITE = "$esc[37m"

# --- Terminal and Centering Helpers ---
$TERMINAL_COLS = [Console]::WindowWidth
$BOX_WIDTH = 70
$CENTER_OFFSET = [Math]::Max(0, [Math]::Floor(($TERMINAL_COLS - $BOX_WIDTH) / 2))

function Center-Print {
    param ([string]$Text)
    $pad = [Math]::Max(0, ([Math]::Floor(($TERMINAL_COLS - $Text.Length) / 2)))
    Write-Host (" " * $pad + $Text)
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

# --- Inline Winfetch execution without saving ---
function Invoke-WinfetchInline {
    Center-Print "$BOLD$FG_CYAN Running system information (winfetch inline)...$RESET`n"
    try {
        $rawScript = (Invoke-WebRequest "https://raw.githubusercontent.com/lptstr/winfetch/master/winfetch.ps1" -UseBasicParsing).Content
        $scriptContent = $rawScript.Remove(0,1)  # Remove BOM or initial unwanted char if any
        Invoke-Expression $scriptContent
        Center-Print ""
    }
    catch {
        Center-Print "$BOLD$FG_RED Failed to run winfetch inline: $($_.Exception.Message)$RESET"
        Center-Print ""
    }
}

# --- Load DNS servers list ---
$DNS_SERVERS = @(
    @{ Provider="Cloudflare"; Primary="1.1.1.1"; Secondary="1.0.0.1" },
    @{ Provider="Google"; Primary="8.8.8.8"; Secondary="8.8.4.4" },
    @{ Provider="Quad9"; Primary="9.9.9.9"; Secondary="149.112.112.112" },
    @{ Provider="OpenDNS"; Primary="208.67.222.222"; Secondary="208.67.220.220" },
    @{ Provider="AdGuard"; Primary="94.140.14.14"; Secondary="94.140.15.15" },
    @{ Provider="CleanBrowsing-Security"; Primary="185.228.168.9"; Secondary="185.228.169.9" },
    @{ Provider="Comodo"; Primary="8.26.56.26"; Secondary="8.20.247.20" },
    @{ Provider="Verisign"; Primary="64.6.64.6"; Secondary="64.6.65.6" },
    @{ Provider="OpenNIC"; Primary="94.16.114.254"; Secondary="94.247.43.254" }
)

function Generate-LatencyBar {
    param([double]$Latency)
    $maxLen = 40
    $block = "█"
    if ($Latency -lt 30) { $color = $FG_GREEN }
    elseif ($Latency -lt 80) { $color = $FG_YELLOW }
    else { $color = $FG_RED }
    $barLen = [Math]::Min($maxLen, [Math]::Max(4, [Math]::Floor(($maxLen * (100 - $Latency)) / 100)))
    return "$color$($block * $barLen)$RESET"
}

function Print-SectionHeader {
    param([string]$Text)
    Center-Print "$BOLD$FG_MAGENTA $Text $RESET"
    Center-Print ("=" * $Text.Length)
    Write-Host ""
}

function Test-DnsLatency {
    param($server, $pingCount=5)

    Write-Host ""
    Center-Print "$BOLD$FG_CYAN Testing $($server.Provider) — Primary and Secondary IPs $RESET`n"

    $results = [System.Collections.Generic.List[object]]::new()

    foreach ($ipType in @("Primary", "Secondary")) {
        $ip = $server.$ipType

        $pingResult = Test-Connection -ComputerName $ip -Count $pingCount -ErrorAction SilentlyContinue
        if ($pingResult) {
            $avgLatency = ($pingResult | Measure-Object -Property ResponseTime -Average).Average
            $packetLoss = (1 - ($pingResult.Count / $pingCount)) * 100
            $status = "$FG_GREEN OK $RESET"
        }
        else {
            $avgLatency = 0
            $packetLoss = 100
            $status = "$FG_RED UNREACHABLE $RESET"
        }

        $latencyStr = if ($packetLoss -ge 100) { "--" } else { "{0:N1} ms" -f $avgLatency }
        $lossStr = "{0:N1}%" -f $packetLoss
        $bar = if ($packetLoss -ge 100) { "" } else { Generate-LatencyBar $avgLatency }

        Center-Print ("{0,-10} : {1,-11} | Loss: {2,6} | Avg: {3,-8} {4}" -f $ipType, $status, $lossStr, $latencyStr, $bar)

        $results.Add([pscustomobject]@{
            Provider = $server.Provider
            IP = $ip
            Loss = $packetLoss
            Latency = [math]::Round($avgLatency)
        })
    }
    return $results
}

function Show-Summary {
    param($results)

    # Sort and select top 3 reachable DNS servers by latency
    $top3 = $results | Where-Object { $_.Loss -lt 100 } | Sort-Object Latency | Select-Object -First 3

    Write-Host ""
    Print-SectionHeader "Top 3 DNS Providers — Summary"

    $sep = "+----------------------+-------------------+------------+-------------------------------------------+"
    Write-Host $sep
    Write-Host ("| {0,-20} | {1,-17} | {2,-10} | {3,-41} |" -f "Provider", "IP Address", "Latency", "Details")
    Write-Host $sep

    foreach ($entry in $top3) {
        $tags = switch ($entry.Provider) {
            "Cloudflare" { "Speed, Privacy, Reliable" }
            "Google" { "Speed, Reliable, Global" }
            "Quad9" { "Malware-Protection, Privacy, Reliable" }
            "OpenDNS" { "Stable, Filtering, Security" }
            "AdGuard" { "Filtering, Privacy, Stable" }
            "CleanBrowsing-Security" { "Security, Family-Filtering, Stable" }
            "Comodo" { "Security, Malware-Protection, Stable" }
            "Verisign" { "Stable, Reliable, No-Redirection" }
            "OpenNIC" { "Community, Privacy, Variable-Speed" }
            default { "Reliable" }
        }
        Write-Host ("| {0,-20} | {1,-17} | {2,8} | {3,-41} |" -f $entry.Provider, $entry.IP, ("$($entry.Latency) ms"), $tags)
    }
    Write-Host $sep
    Write-Host ""
    if ($top3) {
        $champion = $top3[0]
        Center-Print "$BOLD$FG_GREEN 🏆 Speed Champion: $($champion.Provider) ($($champion.IP)) with avg latency $($champion.Latency) ms! 🏆 $RESET"
        Write-Host ""
    }
}

# --- Main Program Flow ---
Print-SectionHeader "System Information"

Invoke-WinfetchInline

Print-SectionHeader "DNS Latency Tests"

$aggregateResults = @()
foreach ($dns in $DNS_SERVERS) {
    $aggregateResults += Test-DnsLatency -server $dns
}

Show-Summary -results $aggregateResults
