# Windows DNS & System Info Script (Modernized)
# Description: Checks/installs winfetch, then runs DNS latency test with clear colorful output.
#
# Note: Does not modify base logic, only enhances visuals and structure.

# --- ANSI Color / Style Definitions ---
$esc = "$([char]27)"
$RESET = "$esc[0m"
$BOLD = "$esc[1m"
$DIM = "$esc[2m"
$FG_RED = "$esc[31m"
$FG_GREEN = "$esc[32m"
$FG_YELLOW = "$esc[33m"
$FG_BLUE = "$esc[34m"
$FG_CYAN = "$esc[36m"

# --- Utility: Center Printer ---
function Center-Print {
    param([string]$Text)
    $cols = [Console]::WindowWidth
    $pad = [Math]::Max(0, ([Math]::Floor(($cols - $Text.Length) / 2)))
    Write-Host (" " * $pad + $Text)
}

function Print-Banner {
    $bannerLines = @(
        "██████╗ ███╗   ██╗███████╗",
        "██╔══██╗████╗  ██║██╔════╝",
        "██████╔╝██╔██╗ ██║█████╗  ",
        "██╔═══╝ ██║╚██╗██║██╔══╝  ",
        "██║     ██║ ╚████║███████╗",
        "╚═╝     ╚═╝  ╚═══╝╚══════╝",
        "      DNS BENCHMARK       "
    )
    Write-Host ""
    foreach ($line in $bannerLines) {
        Center-Print "$BOLD$FG_MAGENTA$line$RESET"
    }
    Write-Host ""
}

# --- Ensures Winfetch is installed ---
function Ensure-Winfetch {
    if (Get-Command winfetch -ErrorAction SilentlyContinue) {
        Center-Print "$BOLD$FG_GREEN winfetch is already available.$RESET"
        return
    }

    Center-Print "$BOLD$FG_YELLOW Winfetch not found — attempting to install...$RESET"

    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Center-Print "$BOLD$FG_YELLOW Chocolatey not found — installing Chocolatey first...$RESET"
        try {
            Set-ExecutionPolicy Bypass -Scope Process -Force
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
            # Refresh PATH in current session
            $chocoPath = "C:\ProgramData\chocolatey\bin"
            if (-not $env:PATH.Split(';') -contains $chocoPath) {
                $env:PATH += ";$chocoPath"
                Center-Print "$BOLD$FG_GREEN Added Chocolatey to current PATH.$RESET"
            }
        } catch {
            Center-Print "$BOLD$FG_RED Failed to install Chocolatey: $($_.Exception.Message)$RESET"
            Write-Host ""
        }
    }

    if (Get-Command choco -ErrorAction SilentlyContinue) {
        try {
            choco install winfetch -y --force | Out-Null
            if (Get-Command winfetch -ErrorAction SilentlyContinue) {
                Center-Print "$BOLD$FG_GREEN winfetch installed successfully via Chocolatey.$RESET"
                return
            }
        } catch {
            Center-Print "$BOLD$FG_YELLOW Failed installing winfetch via Chocolatey: $($_.Exception.Message)$RESET"
        }
    }

    Center-Print "$BOLD$FG_YELLOW Attempting to download winfetch script directly...$RESET"
    $winfetchUrl = "https://github.com/kiedtl/winfetch/releases/latest/download/winfetch.ps1"
    $localPath = Join-Path $env:TEMP "winfetch.ps1"

    try {
        Invoke-RestMethod -Uri $winfetchUrl -OutFile $localPath
        Set-Alias -Name winfetch -Value $localPath -Scope Global -Force
        if (Get-Command winfetch -ErrorAction SilentlyContinue) {
            Center-Print "$BOLD$FG_GREEN winfetch script downloaded successfully.$RESET"
            return
        }
    } catch {
        Center-Print "$BOLD$FG_RED Failed to download winfetch directly: $($_.Exception.Message)$RESET"
    }

    Center-Print "$BOLD$FG_RED Could not make winfetch available. DNS test will continue without it.$RESET"
}

# --- Runs Winfetch (if available) and DNS latency test ---
function Start-Benchmark {
    # Show system info
    if (Get-Command winfetch -ErrorAction SilentlyContinue) {
        Write-Host ""
        Center-Print "$BOLD$FG_CYAN ==== System Information ====$RESET"
        Write-Host ""
        winfetch
        Write-Host ""
    } else {
        Center-Print "$BOLD$FG_YELLOW winfetch not available; skipping system info.$RESET"
    }

    # DNS Test setup
    $pingCount = 5
    $dnsServers = @(
        @{ Provider = "Cloudflare"; Primary = "1.1.1.1"; Secondary = "1.0.0.1" }
        @{ Provider = "Google"; Primary = "8.8.8.8"; Secondary = "8.8.4.4" }
        @{ Provider = "Quad9"; Primary = "9.9.9.9"; Secondary = "149.112.112.112" }
        @{ Provider = "OpenDNS"; Primary = "208.67.222.222"; Secondary = "208.67.220.220" }
        @{ Provider = "AdGuard"; Primary = "94.140.14.14"; Secondary = "94.140.15.15" }
        @{ Provider = "CleanBrowsing"; ProviderDisplay = "CleanBrowsing-Security"; Primary = "185.228.168.9"; Secondary = "185.228.169.9" }
        @{ Provider = "Comodo"; Primary = "8.26.56.26"; Secondary = "8.20.247.20" }
        @{ Provider = "Verisign"; Primary = "64.6.64.6"; Secondary = "64.6.65.6" }
        @{ Provider = "OpenNIC"; Primary = "94.16.114.254"; Secondary = "94.247.43.254" }
    )

    Center-Print "$BOLD$FG_CYAN ==== DNS Latency Test ====$RESET"
    Write-Host ""
    Center-Print "$BOLD Mode:$RESET $pingCount probes per server"
    Center-Print "$BOLD Targets:$RESET $($dnsServers.Count) providers (primary + secondary)"
    Write-Host ""

    $allResults = [System.Collections.Generic.List[object]]::new()

    foreach ($server in $dnsServers) {
        $providerName = if ($null -ne $server.ProviderDisplay) { $server.ProviderDisplay } else { $server.Provider }
        Center-Print "$BOLD$FG_BLUE $providerName $RESET"

        # Primary
        $primaryPings = Test-Connection -ComputerName $server.Primary -Count $pingCount -ErrorAction SilentlyContinue
        if ($primaryPings) {
            $avgPrimary = ($primaryPings | Measure-Object -Property ResponseTime -Average).Average
            $lossPrimary = (1 - ($primaryPings.Count / $pingCount)) * 100
            Center-Print ("  Primary    : $FG_GREEN OK $RESET | Loss: {0:N1}% | Avg: {1} ms | IP: $server.Primary" -f $lossPrimary, [math]::Round($avgPrimary))
            $allResults.Add([pscustomobject]@{ Provider = $providerName; IP = $server.Primary; Loss = $lossPrimary; Latency = [math]::Round($avgPrimary) })
        } else {
            Center-Print ("  Primary    : $FG_RED UNREACHABLE $RESET | Loss: 100% | IP: $server.Primary")
        }

        # Secondary
        $secondaryPings = Test-Connection -ComputerName $server.Secondary -Count $pingCount -ErrorAction SilentlyContinue
        if ($secondaryPings) {
            $avgSecondary = ($secondaryPings | Measure-Object -Property ResponseTime -Average).Average
            $lossSecondary = (1 - ($secondaryPings.Count / $pingCount)) * 100
            Center-Print ("  Secondary  : $FG_GREEN OK $RESET | Loss: {0:N1}% | Avg: {1} ms | IP: $server.Secondary" -f $lossSecondary, [math]::Round($avgSecondary))
            $allResults.Add([pscustomobject]@{ Provider = $providerName; IP = $server.Secondary; Loss = $lossSecondary; Latency = [math]::Round($avgSecondary) })
        } else {
            Center-Print ("  Secondary  : $FG_RED UNREACHABLE $RESET | Loss: 100% | IP: $server.Secondary")
        }

        Write-Host ""
    }

    # Provider tag helper
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

    # Summary Table
    $top3 = $allResults | Where-Object { $_.Loss -lt 100 } | Sort-Object -Property Latency | Select-Object -First 3

    $separator = "+----------------------+-------------------+------------+-------------------------------------------+"
    Center-Print "$BOLD$FG_MAGENTA DNS Providers - Top 3 Summary $RESET"
    Write-Host $separator
    Write-Host ("| {0,-20} | {1,-17} | {2,-10} | {3,-41} |" -f "Provider", "IP Address", "Latency", "Details")
    Write-Host $separator
    foreach ($entry in $top3) {
        $tags = Get-ProviderTags -Provider $entry.Provider
        $latencyStr = "$($entry.Latency) ms"
        Write-Host ("| {0,-20} | {1,-17} | {2,8} | {3,-41} |" -f $entry.Provider, $entry.IP, $latencyStr, $tags)
    }
    Write-Host $separator
    Write-Host ""
}

# --- Main Script Execution ---
Ensure-Winfetch
Start-Benchmark
