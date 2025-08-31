# Enhanced DNS Testing Script with Winfetch Integration and Visual Appeal
# Execute this script in PowerShell

function Show-AnimatedBanner {
    $banner = @"
`e[35m
╔══════════════════════════════════════════════════════════════════════╗
║  ██████╗ ███╗   ██╗███████╗    ████████╗███████╗███████╗████████╗    ║
║  ██╔══██╗████╗  ██║██╔════╝    ╚══██╔══╝██╔════╝██╔════╝╚══██╔══╝    ║
║  ██║  ██║██╔██╗ ██║███████╗       ██║   █████╗  ███████╗   ██║       ║
║  ██║  ██║██║╚██╗██║╚════██║       ██║   ██╔══╝  ╚════██║   ██║       ║
║  ██████╔╝██║ ╚████║███████║       ██║   ███████╗███████║   ██║       ║
║  ╚═════╝ ╚═╝  ╚═══╝╚══════╝       ╚═╝   ╚══════╝╚══════╝   ╚═╝       ║
║                                                                      ║
║              🌐 DNS Benchmark Tool with System Info 🌐              ║
╚══════════════════════════════════════════════════════════════════════╝
`e[0m
"@
    Write-Host $banner
}

function Show-LoadingAnimation {
    param([string]$Message, [int]$Duration = 2)
    
    $spinner = @('⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏')
    $counter = 0
    $endTime = (Get-Date).AddSeconds($Duration)
    
    while ((Get-Date) -lt $endTime) {
        $frame = $spinner[$counter % $spinner.Length]
        Write-Host "`r`e[36m$frame $Message`e[0m" -NoNewline
        Start-Sleep -Milliseconds 100
        $counter++
    }
    Write-Host "`r`e[32m✅ $Message - Complete!`e[0m"
}

function Invoke-WinfetchStart {
    Write-Host "`n`e[33m╔═══════════════════════════════════════════════════════════════╗`e[0m"
    Write-Host "`e[33m║                    SYSTEM INFORMATION                        ║`e[0m"
    Write-Host "`e[33m╚═══════════════════════════════════════════════════════════════╝`e[0m"
    
    Show-LoadingAnimation "Loading System Information"
    
    try {
        # Execute winfetch directly without saving to disk
        (Invoke-WebRequest "https://raw.githubusercontent.com/lptstr/winfetch/master/winfetch.ps1" -UseBasicParsing).Content.Remove(0,1) | Invoke-Expression
        Write-Host "`e[32m[SUCCESS] System information loaded successfully!`e[0m"
    } catch {
        Write-Host "`e[31m[ERROR] Failed to load Winfetch. Showing basic system info...`e[0m"
        # Fallback system info
        Write-Host "`e[36mComputer: $env:COMPUTERNAME`e[0m"
        Write-Host "`e[36mUser: $env:USERNAME`e[0m"
        Write-Host "`e[36mOS: $(Get-WmiObject Win32_OperatingSystem | Select-Object -ExpandProperty Caption)`e[0m"
    }
}

function Show-ColoredProgress {
    param(
        [string]$Activity,
        [string]$Status,
        [int]$PercentComplete,
        [string]$Color = "Green"
    )
    
    Write-Progress -Activity $Activity -Status $Status -PercentComplete $PercentComplete
    
    $colorCode = switch ($Color) {
        "Green" { "`e[32m" }
        "Yellow" { "`e[33m" }
        "Red" { "`e[31m" }
        "Blue" { "`e[34m" }
        "Cyan" { "`e[36m" }
        "Magenta" { "`e[35m" }
        default { "`e[37m" }
    }
    
    $progressBar = ""
    $completed = [math]::Floor($PercentComplete / 5)
    $remaining = 20 - $completed
    
    for ($i = 0; $i -lt $completed; $i++) { $progressBar += "█" }
    for ($i = 0; $i -lt $remaining; $i++) { $progressBar += "░" }
    
    Write-Host "`r${colorCode}[$progressBar] $PercentComplete% - $Status`e[0m" -NoNewline
}

function Test-DNSWithBenchmark {
    param([array]$DNSServers)
    
    Write-Host "`n`n`e[33m╔═══════════════════════════════════════════════════════════════╗`e[0m"
    Write-Host "`e[33m║                    DNS BENCHMARK STARTED                     ║`e[0m"
    Write-Host "`e[33m╚═══════════════════════════════════════════════════════════════╝`e[0m"
    
    $totalServers = $DNSServers.Count
    $results = @()
    $testDomains = @("google.com", "youtube.com", "github.com", "microsoft.com")
    
    for ($i = 0; $i -lt $totalServers; $i++) {
        $server = $DNSServers[$i]
        $serverName = $server.Name
        $serverIP = $server.IP
        $percentComplete = [math]::Round(($i / $totalServers) * 100)
        
        Write-Host "`n`e[36m🔍 Testing: $serverName ($serverIP)`e[0m"
        Show-ColoredProgress -Activity "DNS Benchmark Progress" -Status "Testing $serverName" -PercentComplete $percentComplete -Color "Cyan"
        
        $totalResponseTime = 0
        $successfulTests = 0
        $testResults = @()
        
        foreach ($domain in $testDomains) {
            try {
                $responseTime = (Measure-Command { 
                    Resolve-DnsName -Name $domain -Server $serverIP -ErrorAction Stop 
                }).TotalMilliseconds
                
                $totalResponseTime += $responseTime
                $successfulTests++
                $testResults += "✅ $domain ($([math]::Round($responseTime, 1))ms)"
                
            } catch {
                $testResults += "❌ $domain (Failed)"
            }
            
            # Mini progress for each domain test
            $domainProgress = ($testDomains.IndexOf($domain) + 1) / $testDomains.Count * 20
            $currentPercent = $percentComplete + $domainProgress
            Show-ColoredProgress -Activity "Testing domains" -Status "$domain on $serverName" -PercentComplete $currentPercent -Color "Yellow"
            Start-Sleep -Milliseconds 200
        }
        
        if ($successfulTests -gt 0) {
            $avgResponseTime = $totalResponseTime / $successfulTests
            $results += [PSCustomObject]@{
                Name = $serverName
                IP = $serverIP
                AverageResponseTime = $avgResponseTime
                SuccessfulTests = $successfulTests
                TotalTests = $testDomains.Count
                SuccessRate = [math]::Round(($successfulTests / $testDomains.Count) * 100, 1)
                Status = if ($successfulTests -eq $testDomains.Count) { "Excellent" } 
                        elseif ($successfulTests -ge 2) { "Good" } 
                        else { "Poor" }
                Color = if ($successfulTests -eq $testDomains.Count) { "Green" } 
                       elseif ($successfulTests -ge 2) { "Yellow" } 
                       else { "Red" }
                TestDetails = $testResults
            }
            
            Write-Host "`n`e[32m   ✅ Average Response: $([math]::Round($avgResponseTime, 2))ms | Success Rate: $([math]::Round(($successfulTests / $testDomains.Count) * 100, 1))%`e[0m"
        } else {
            $results += [PSCustomObject]@{
                Name = $serverName
                IP = $serverIP
                AverageResponseTime = 9999
                SuccessfulTests = 0
                TotalTests = $testDomains.Count
                SuccessRate = 0
                Status = "Failed"
                Color = "Red"
                TestDetails = $testResults
            }
            Write-Host "`n`e[31m   ❌ All tests failed for $serverName`e[0m"
        }
    }
    
    Write-Progress -Activity "DNS Benchmark Complete" -Status "All tests finished" -PercentComplete 100 -Completed
    Write-Host "`n"
    
    return $results | Sort-Object AverageResponseTime
}

function Show-DetailedResults {
    param([array]$Results)
    
    Write-Host "`e[35m╔══════════════════════════════════════════════════════════════════════╗`e[0m"
    Write-Host "`e[35m║                         DETAILED DNS RESULTS                        ║`e[0m"
    Write-Host "`e[35m╚══════════════════════════════════════════════════════════════════════╝`e[0m"
    
    $rank = 1
    foreach ($result in $Results) {
        $colorCode = switch ($result.Color) {
            "Green" { "`e[32m" }
            "Yellow" { "`e[33m" }
            "Red" { "`e[31m" }
        }
        
        $medal = switch ($rank) {
            1 { "🥇" }
            2 { "🥈" }
            3 { "🥉" }
            default { "  " }
        }
        
        Write-Host "`n${colorCode}$medal #$rank - $($result.Name) ($($result.IP))`e[0m"
        Write-Host "${colorCode}   ⚡ Avg Response: $([math]::Round($result.AverageResponseTime, 2))ms`e[0m"
        Write-Host "${colorCode}   📊 Success Rate: $($result.SuccessRate)% ($($result.SuccessfulTests)/$($result.TotalTests))`e[0m"
        Write-Host "${colorCode}   📈 Status: $($result.Status)`e[0m"
        
        Write-Host "`e[37m   📋 Test Details:`e[0m"
        foreach ($detail in $result.TestDetails) {
            Write-Host "      $detail"
        }
        
        $rank++
    }
}

function Show-Top3DNSServers {
    param([array]$Results)
    
    $top3 = $Results | Where-Object { $_.SuccessfulTests -gt 0 } | Select-Object -First 3
    
    Write-Host "`n`e[33m╔══════════════════════════════════════════════════════════════════════╗`e[0m"
    Write-Host "`e[33m║                         🏆 TOP 3 DNS SERVERS 🏆                     ║`e[0m"
    Write-Host "`e[33m╚══════════════════════════════════════════════════════════════════════╝`e[0m"
    
    if ($top3.Count -eq 0) {
        Write-Host "`e[31m❌ No DNS servers responded successfully!`e[0m"
        return
    }
    
    $podium = @("🥇 GOLD", "🥈 SILVER", "🥉 BRONZE")
    $colors = @("`e[33m", "`e[37m", "`e[31m")  # Gold, Silver, Bronze colors
    
    for ($i = 0; $i -lt [math]::Min(3, $top3.Count); $i++) {
        $server = $top3[$i]
        $color = $colors[$i]
        $position = $podium[$i]
        
        Write-Host "`n$color╔══════════════════════════════════════════════════════╗`e[0m"
        Write-Host "$color║  $position - $($server.Name.PadRight(40)) ║`e[0m"
        Write-Host "$color╠══════════════════════════════════════════════════════╣`e[0m"
        Write-Host "$color║  📍 IP Address: $($server.IP.PadRight(35)) ║`e[0m"
        Write-Host "$color║  ⚡ Response Time: $("$([math]::Round($server.AverageResponseTime, 2))ms".PadRight(30)) ║`e[0m"
        Write-Host "$color║  📊 Success Rate: $("$($server.SuccessRate)%".PadRight(32)) ║`e[0m"
        Write-Host "$color║  🎯 Status: $($server.Status.PadRight(38)) ║`e[0m"
        Write-Host "$color╚══════════════════════════════════════════════════════╝`e[0m"
    }
    
    # Recommendation
    $fastest = $top3[0]
    Write-Host "`n`e[32m╔══════════════════════════════════════════════════════════════════════╗`e[0m"
    Write-Host "`e[32m║                            🎯 RECOMMENDATION                         ║`e[0m"
    Write-Host "`e[32m╠══════════════════════════════════════════════════════════════════════╣`e[0m"
    Write-Host "`e[32m║  For optimal performance, use: $($fastest.Name)                ║`e[0m"
    Write-Host "`e[32m║  Primary DNS: $($fastest.IP.PadRight(48)) ║`e[0m"
    if ($top3.Count -gt 1) {
        Write-Host "`e[32m║  Secondary DNS: $($top3[1].IP.PadRight(46)) ║`e[0m"
    }
    Write-Host "`e[32m╚══════════════════════════════════════════════════════════════════════╝`e[0m"
}

# Main Script Execution
function Start-EnhancedDNSBenchmark {
    Clear-Host
    
    # Show animated banner
    Show-AnimatedBanner
    
    # Show system information with winfetch at start
    Invoke-WinfetchStart
    
    # DNS servers to test with names
    $dnsServers = @(
        @{ Name = "Google Primary"; IP = "8.8.8.8" },
        @{ Name = "Google Secondary"; IP = "8.8.4.4" },
        @{ Name = "Cloudflare Primary"; IP = "1.1.1.1" },
        @{ Name = "Cloudflare Secondary"; IP = "1.0.0.1" },
        @{ Name = "OpenDNS Primary"; IP = "208.67.222.222" },
        @{ Name = "OpenDNS Secondary"; IP = "208.67.220.220" },
        @{ Name = "Quad9 Primary"; IP = "9.9.9.9" },
        @{ Name = "Quad9 Secondary"; IP = "149.112.112.112" },
        @{ Name = "AdGuard DNS"; IP = "94.140.14.14" },
    )
    
    Write-Host "`n`e[36m🚀 Initializing DNS benchmark on $($dnsServers.Count) servers...`e[0m"
    Show-LoadingAnimation "Preparing DNS tests" 1
    
    # Run DNS benchmark
    $benchmarkResults = Test-DNSWithBenchmark -DNSServers $dnsServers
    
    # Show detailed results
    Show-DetailedResults -Results $benchmarkResults
    
    # Show top 3 DNS servers at the end
    Show-Top3DNSServers -Results $benchmarkResults
    
    # Final message
    Write-Host "`n`e[32m╔══════════════════════════════════════════════════════════════════════╗`e[0m"
    Write-Host "`e[32m║                    🎉 BENCHMARK COMPLETED SUCCESSFULLY! 🎉          ║`e[0m"
    Write-Host "`e[32m║                                                                      ║`e[0m"
    Write-Host "`e[32m║  Results saved in memory. Configure your network settings with      ║`e[0m"
    Write-Host "`e[32m║  the recommended DNS servers for optimal internet performance.      ║`e[0m"
    Write-Host "`e[32m╚══════════════════════════════════════════════════════════════════════╝`e[0m"
    
    Write-Host "`n`e[35m📝 Script completed at: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`e[0m"
}

# Execute the enhanced DNS benchmark
Start-EnhancedDNSBenchmark
