# Windows DNS & System Info Script
# Description: Checks for winfetch. If missing, it tries to install it using Chocolatey or by direct download,
#              then it runs the DNS latency test.
#
# To Run (from Command Prompt or PowerShell):
#   powershell -ExecutionPolicy Bypass -NoProfile -Command "irm https://raw.githubusercontent.com/F3aarLeSS/DNSTest/refs/heads/main/windows.ps1 | iex"

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

# --- Function to ensure Winfetch is available ---
function Ensure-Winfetch {
    # 1. Check if winfetch command already exists
    if (Get-Command winfetch -ErrorAction SilentlyContinue) {
        Write-Host "$($BOLD)$($FG_GREEN)winfetch is already available.$($RESET)"
        return
    }

    # 2. Attempt to install via Chocolatey (preferred method)
    Write-Host "$($BOLD)$($FG_YELLOW)Winfetch not found. Attempting to install using Chocolatey...$($RESET)"
    
    # Check for Chocolatey and install if missing
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "$($BOLD)$($FG_YELLOW)Chocolatey not found. Attempting to install Chocolatey first...$($RESET)"
        try {
            Set-ExecutionPolicy Bypass -Scope Process -Force;
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072;
            Invoke-RestMethod -Uri 'https://community.chocolatey.org/install.ps1' -UseBasicParsing | Invoke-Expression
            # Refresh environment variables to find the new command
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
        }
        catch {
            Write-Host "$($BOLD)$($FG_RED)Failed to install Chocolatey. $($_.Exception.Message)$($RESET)"
            # Fallback will be attempted next
        }
    }

    # Install Winfetch with Chocolatey if available
    if (Get-Command choco -ErrorAction SilentlyContinue) {
         try {
            choco install winfetch -y --force
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            if (Get-Command winfetch -ErrorAction SilentlyContinue) {
                Write-Host "$($BOLD)$($FG_GREEN)winfetch installed successfully via Chocolatey.$($RESET)"
                return
            }
        }
        catch {
             Write-Host "$($BOLD)$($FG_YELLOW)Chocolatey installation of winfetch failed. $($_.Exception.Message)$($RESET)"
        }
    }

    # 3. Fallback: Direct download from GitHub
    Write-Host "$($BOLD)$($FG_YELLOW)Chocolatey failed or not found. Attempting direct download of winfetch script...$($RESET)"
    $winfetchUrl = "https://github.com/kiedtl/winfetch/releases/latest/download/winfetch.ps1"
    $localPath = Join-Path $env:TEMP "winfetch.ps1"
    try {
        Invoke-RestMethod -Uri $winfetchUrl -OutFile $localPath
        # Make the downloaded script available as the 'winfetch' command for this session
        Set-Alias -Name winfetch -Value $localPath -Scope Global -Force
        if (Get-Command winfetch -ErrorAction SilentlyContinue) {
             Write-Host "$($BOLD)$($FG_GREEN)winfetch downloaded successfully.$($RESET)"
             return
        }
    }
    catch {
        Write-Host "$($BOLD)$($FG_RED)Failed to download winfetch directly.$($RESET)"
        Write-Host "$($BOLD)$($FG_RED)Error details: $($_.Exception.Message)$($RESET)"
    }
    
    Write-Host "$($BOLD)$($FG_RED)Could not make winfetch available. DNS test will continue without it.$($RESET)"
}


# --- Function to Run Winfetch and DNS Benchmark ---
function Start-Benchmark {
    # 1. Display System Info with Winfetch
    if (Get-Command winfetch -ErrorAction SilentlyContinue) {
        winfetch
    }
    else {
        Write-Host "$($BOLD)$($FG_GREEN)winfetch could not be installed; continuing with DNS tests...$($RESET)"
    }

    Write-Host ""
    Write-Host "$($BOLD)$($FG_BLUE)DNS Section$($RESET)"
    Write-Host "-----------"
    Write-Host ""

    # 2. DNS Benchmark Section
    $pingCount = 5
    $pingTimeoutSeconds = 5

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
            $allResults.Add([pscustomobject]@{ Provider = $server.Provider; IP = $server.Primary; Loss = $loss1; Latency = [math]::Round($avgLatency1) })
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
            $allResults.Add([pscustomobject]@{ Provider = $server.Provider; IP = $server.Secondary; Loss = $loss2; Latency = [math]::Round($avgLatency2) })
        }
        else {
            Write-Host ("{0,-14} {1}" -f "Secondary", "$($FG_RED)UNREACHABLE$($RESET)   loss=100%   $($DIM)($($server.Secondary))$($RESET)")
        }
        Write-Host ""
    }

    # 3. Summary Table
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
}

# --- Main Script Execution ---
Ensure-Winfetch
Start-Benchmark

