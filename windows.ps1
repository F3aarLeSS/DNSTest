# Windows DNS & System Info Script
# Description: Checks for/installs Scoop -> Checks for/installs winfetch -> Runs DNS latency test.
#
# To Run from PowerShell:
#   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
#   irm https://gist.githubusercontent.com/your-username/your-gist-id/raw/dns-benchmark.ps1 | iex
#
# Or, to run with a single command without changing policy permanently:
#   powershell -ExecutionPolicy Bypass -NoProfile -Command "iex ((New-Object System.Net.WebClient).DownloadString('https://gist.githubusercontent.com/your-username/your-gist-id/raw/dns-benchmark.ps1'))"

# --- Script Configuration ---
$pingCount = 5
$pingTimeoutSeconds = 5 # Note: This is a conceptual timeout; Test-Connection waits for all replies.

# --- ANSI Color Definitions ---
$esc = "$([char]27)"
$RESET = "$esc[0m"
$BOLD = "$esc[1m"
$DIM = "$esc[2m"
$FG_RED = "$esc[31m"
$FG_GREEN = "$esc[32m"
$FG_YELLOW = "$esc[33m"
$FG_BLUE = "$esc[34m"
$FG_CYAN = "$esc[36m"

# --- Function to Ensure Scoop and Wfetch are available ---
function Ensure-ScoopAndWinfetch {
    # Check if Scoop is installed
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-Host "$($BOLD)$($FG_YELLOW)Scoop package manager not found. Attempting to install...$($RESET)"
        # Set execution policy to allow installation script to run
        try {
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
            # Download and run the Scoop installer
            Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://get.scoop.sh')
            Write-Host "$($BOLD)$($FG_GREEN)Scoop installed successfully.$($RESET)"
        }
        catch {
            Write-Host "$($BOLD)$($FG_RED)Failed to install Scoop. Please install it manually from https://scoop.sh$($RESET)"
            Write-Host "DNS test will continue without winfetch."
            return
        }
    }

    # Check if winfetch is installed
    if (-not (Get-Command winfetch -ErrorAction SilentlyContinue)) {
        Write-Host "$($BOLD)$($FG_YELLOW)winfetch not found. Installing via Scoop...$($RESET)"
        try {
            scoop install winfetch
        }
        catch {
            Write-Host "$($BOLD)$($FG_RED)Failed to install winfetch. Continuing without it.$($RESET)"
        }
    }
}

# --- Main Script Execution ---

# 1. Setup Environment and Install Tools
Ensure-ScoopAndWinfetch

# 2. Display System Info with Wfetch
if (Get-Command winfetch -ErrorAction SilentlyContinue) {
    winfetch
}
else {
    Write-Host "$($BOLD)$($FG_GREEN)winfetch not found; continuing with DNS tests...$($RESET)"
}

Write-Host ""
Write-Host "$($BOLD)$($FG_BLUE)DNS Section$($RESET)"
Write-Host "-----------"
Write-Host ""

# --- DNS Benchmark Section ---

$dnsServers = @(
    [pscustomobject]@{ Provider = "Cloudflare"; Primary = "1.1.1.1"; Secondary = "1.0.0.1" }
    [pscustomobject]@{ Provider = "Google"; Primary = "8.8.8.8"; Secondary = "8.8.4.4" }
    [pscustomobject]@{ Provider = "Quad9"; Primary = "9.9.9.9"; Secondary = "149.112.112.112" }
    [pscustomobject]@{ Provider = "OpenDNS"; Primary = "208.67.222.222"; Secondary = "208.67.220.220" }
    [pscustomobject]@{ Provider = "AdGuard"; Primary = "94.140.14.14"; Secondary = "94.140.15.15" }
    [pscustomobject]@{ Provider = "CleanBrowsing"; ProviderDisplay="CleanBrowsing-Security"; Primary = "185.228.168.9"; Secondary = "185.228.169.9" }
    [pscustomobject]@{ Provider = "Comodo"; Primary = "8.26.56.26"; Secondary = "8.20.247.20" }
    [pscustomobject]@{ Provider = "Verisign"; Primary = "64.6.64.6"; Secondary = "64.6.65.6" }
    [pscustomobject]@{ Provider = "OpenNIC"; Primary = "94.16.114.254"; Secondary = "94.247.43.254" }
)

Write-Host "$($BOLD)$($FG_CYAN)Mode:$($RESET) $($pingCount) probes per host"
Write-Host "$($BOLD)$($FG_CYAN)Timeout:$($RESET) $($pingTimeoutSeconds)s per probe (conceptual)"
Write-Host "$($BOLD)$($FG_CYAN)Targets:$($RESET) $($dnsServers.Count) providers (primary + secondary)"
Write-Host ""
Write-Host "$($BOLD)$($FG_BLUE)Testing DNS (Please Wait)...$($RESET)"
Write-Host ""

$allResults = [System.Collections.Generic.List[object]]::new()

foreach ($server in $dnsServers) {
    $providerName = if ($server.ProviderDisplay) { $server.ProviderDisplay } else { $server.Provider }
    Write-Host "$($BOLD)$($FG_CYAN)$providerName$($RESET)"

    # Test Primary IP
    $pingResult1 = Test-Connection -ComputerName $server.Primary -Count $pingCount -ErrorAction SilentlyContinue
    if ($pingResult1) {
        $avgLatency1 = ($pingResult1 | Measure-Object -Property ResponseTime -Average).Average
        $loss1 = (1 - ($pingResult1.Count / $pingCount)) * 100
        Write-Host ("{0,-14} {1}" -f "Primary", "$($FG_GREEN)OK$($RESET)   loss=$($loss1)%   avg=$([math]::Round($avgLatency1))ms   $($DIM)($($server.Primary))$($RESET)")
        $allResults.Add([pscustomobject]@{
            Provider = $server.Provider
            IP       = $server.Primary
            Loss     = $loss1
            Latency  = [math]::Round($avgLatency1)
        })
    }
    else {
        Write-Host ("{0,-14} {1}" -f "Primary", "$($FG_RED)UNREACHABLE$($RESET)   loss=100%   $($DIM)($($server.Primary))$($RESET)")
    }

    # Test Secondary IP
    $pingResult2 = Test-Connection -ComputerName $server.Secondary -Count $pingCount -ErrorAction SilentlyContinue
    if ($pingResult2) {
        $avgLatency2 = ($pingResult2 | Measure-Object -Property ResponseTime -Average).Average
        $loss2 = (1 - ($pingResult2.Count / $pingCount)) * 100
        Write-Host ("{0,-14} {1}" -f "Secondary", "$($FG_GREEN)OK$($RESET)   loss=$($loss2)%   avg=$([math]::Round($avgLatency2))ms   $($DIM)($($server.Secondary))$($RESET)")
        $allResults.Add([pscustomobject]@{
            Provider = $server.Provider
            IP       = $server.Secondary
            Loss     = $loss2
            Latency  = [math]::Round($avgLatency2)
        })
    }
    else {
        Write-Host ("{0,-14} {1}" -f "Secondary", "$($FG_RED)UNREACHABLE$($RESET)   loss=100%   $($DIM)($($server.Secondary))$($RESET)")
    }
    Write-Host ""
}

# --- Summary Table ---
function Get-ProviderTags {
    param ($Provider)
    switch ($Provider) {
        "Cloudflare" { "Speed, Privacy, Reliable" }
        "Google" { "Speed, Reliable, Global" }
        "Quad9" { "Malware-Protection, Privacy, Reliable" }
        "OpenDNS" { "Stable, Filtering, Security" }
        "AdGuard" { "Filtering, Privacy, Stable" }
        "CleanBrowsing" { "Security, Family-Filtering, Stable" }
        "Comodo" { "Security, Malware-Protection, Stable" }
        "Verisign" { "Stable, Reliable, No-Redirection" }
        "OpenNIC" { "Community, Privacy, Variable-Speed" }
        default { "Reliable" }
    }
}

$top3 = $allResults | Where-Object { $_.Loss -lt 100 } | Sort-Object -Property Latency | Select-Object -First 3

Write-Host "$($BOLD)$($FG_BLUE)Top 3 DNS — Summary Table$($RESET)"
$sep = "+----------------+------------------+----------+-------------------------------------------+"
Write-Host $sep
Write-Host ("| {0,-14} | {1,-16} | {2,-8} | {3,-41} |" -f "Provider", "IP", "Latency", "Details")
Write-Host $sep
foreach ($entry in $top3) {
    $tags = Get-ProviderTags -Provider $entry.Provider
    $latencyStr = "$($entry.Latency)ms"
    Write-Host ("| {0,-14} | {1,-16} | {2,7} | {3,-41} |" -f $entry.Provider, $entry.IP, $latencyStr, $tags)
}
Write-Host $sep
Write-Host ""
