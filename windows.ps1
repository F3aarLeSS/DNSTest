# Modern DNS Benchmark Tool with Enhanced Visual Appeal
# Requires PowerShell 7+ for best color support

function Show-ModernBanner {
    Clear-Host
    Write-Host ""
    Write-Host "`e[38;5;51m    ██████╗ ███╗   ██╗███████╗    ████████╗███████╗███████╗████████╗`e[0m" -ForegroundColor Cyan
    Write-Host "`e[38;5;45m    ██╔══██╗████╗  ██║██╔════╝    ╚══██╔══╝██╔════╝██╔════╝╚══██╔══╝`e[0m" -ForegroundColor Cyan
    Write-Host "`e[38;5;39m    ██║  ██║██╔██╗ ██║███████╗       ██║   █████╗  ███████╗   ██║   `e[0m" -ForegroundColor Cyan
    Write-Host "`e[38;5;33m    ██║  ██║██║╚██╗██║╚════██║       ██║   ██╔══╝  ╚════██║   ██║   `e[0m" -ForegroundColor Cyan
    Write-Host "`e[38;5;27m    ██████╔╝██║ ╚████║███████║       ██║   ███████╗███████║   ██║   `e[0m" -ForegroundColor Cyan
    Write-Host "`e[38;5;21m    ╚═════╝ ╚═╝  ╚═══╝╚══════╝       ╚═╝   ╚══════╝╚══════╝   ╚═╝   `e[0m" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "`e[38;5;75m                    🚀 Modern DNS Benchmark & System Info Tool 🚀`e[0m" -ForegroundColor Cyan
    Write-Host "`e[38;5;69m                           Performance • Speed • Reliability`e[0m" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "`e[38;5;240m" + "─" * 80 + "`e[0m"
    Write-Host ""
}

function Show-SmoothProgress {
    param(
        [string]$Task,
        [int]$Current,
        [int]$Total,
        [string]$Status = "",
        [string]$Color = "Cyan"
    )
    
    $percentage = [math]::Round(($Current / $Total) * 100)
    $completed = [math]::Floor($percentage / 2.5)  # 40 character bar
    $remaining = 40 - $completed
    
    $progressBar = "`e[38;5;46m" + "█" * $completed + "`e[38;5;240m" + "░" * $remaining + "`e[0m"
    
    Write-Host "`r`e[2K`e[38;5;75m┌─ $Task`e[0m" -NoNewline
    Write-Host ""
    Write-Host "`e[38;5;75m│`e[0m [$progressBar] `e[38;5;255m$percentage%`e[0m" -NoNewline
    if ($Status) {
        Write-Host " `e[38;5;249m• $Status`e[0m" -NoNewline
    }
    Write-Host ""
}

function Invoke-ModernWinfetch {
    Write-Host "`e[38;5;117m┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓`e[0m"
    Write-Host "`e[38;5;117m┃`e[0m `e[38;5;255m                           💻 System Information                          `e[0m `e[38;5;117m┃`e[0m"
    Write-Host "`e[38;5;117m┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛`e[0m"
    Write-Host ""
    
    # Smooth loading effect
    $loadingFrames = @("⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏")
    for ($i = 0; $i -lt 15; $i++) {
        $frame = $loadingFrames[$i % $loadingFrames.Length]
        Write-Host "`r`e[38;5;51m    $frame Fetching system information...`e[0m" -NoNewline
        Start-Sleep -Milliseconds 100
    }
    Write-Host "`r`e[2K`e[38;5;46m    ✓ System information loaded`e[0m"
    Write-Host ""
    
    try {
        (Invoke-WebRequest "https://raw.githubusercontent.com/lptstr/winfetch/master/winfetch.ps1" -UseBasicParsing).Content.Remove(0,1) | Invoke-Expression
    } catch {
        # Modern fallback display
        Write-Host "`e[38;5;255m    Computer:`e[0m `e[38;5;117m$env:COMPUTERNAME`e[0m"
        Write-Host "`e[38;5;255m    User:`e[0m     `e[38;5;117m$env:USERNAME`e[0m"
        Write-Host "`e[38;5;255m    OS:`e[0m       `e[38;5;117m$(Get-WmiObject Win32_OperatingSystem | Select-Object -ExpandProperty Caption)`e[0m"
    }
    Write-Host ""
}

function Test-ModernDNS {
    param([array]$DNSList)
    
    Write-Host ""
    Write-Host "`e[38;5;214m┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓`e[0m"
    Write-Host "`e[38;5;214m┃`e[0m `e[38;5;255m                            🎯 DNS Benchmark                              `e[0m `e[38;5;214m┃`e[0m"
    Write-Host "`e[38;5;214m┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛`e[0m"
    Write-Host ""
    
    $results = @()
    $domains = @("google.com", "github.com", "youtube.com")
    $totalTests = $DNSList.Count
    
    for ($i = 0; $i -lt $totalTests; $i++) {
        $dns = $DNSList[$i]
        $serverName = $dns.Name
        $serverIP = $dns.IP
        
        # Modern server header
        Write-Host "`e[38;5;255m  ┌─ Testing: `e[38;5;117m$serverName`e[38;5;255m ($serverIP)`e[0m"
        
        Show-SmoothProgress -Task "DNS Resolution" -Current ($i + 1) -Total $totalTests -Status $serverName
        
        $totalTime = 0
        $successful = 0
        
        foreach ($domain in $domains) {
            try {
                $time = (Measure-Command { 
                    Resolve-DnsName -Name $domain -Server $serverIP -ErrorAction Stop 
                }).TotalMilliseconds
                $totalTime += $time
                $successful++
                
                # Subtle domain test indicator
                Write-Host "`e[38;5;255m  │ `e[38;5;46m●`e[0m `e[38;5;249m$domain`e[0m `e[38;5;240m($([math]::Round($time, 1))ms)`e[0m"
            } catch {
                Write-Host "`e[38;5;255m  │ `e[38;5;196m●`e[0m `e[38;5;249m$domain`e[0m `e[38;5;240m(failed)`e[0m"
            }
            Start-Sleep -Milliseconds 100
        }
        
        if ($successful -gt 0) {
            $avgTime = $totalTime / $successful
            $successRate = ($successful / $domains.Count) * 100
            
            # Clean result display
            $statusEmoji = if ($successRate -eq 100) { "🟢" } elseif ($successRate -ge 66) { "🟡" } else { "🔴" }
            Write-Host "`e[38;5;255m  └─ Result: $statusEmoji `e[38;5;117m$([math]::Round($avgTime, 1))ms`e[38;5;255m avg • `e[38;5;117m$([math]::Round($successRate, 0))%`e[38;5;255m success`e[0m"
            
            $results += [PSCustomObject]@{
                Name = $serverName
                IP = $serverIP
                AvgTime = $avgTime
                SuccessRate = $successRate
                Status = if ($successRate -eq 100) { "Excellent" } elseif ($successRate -ge 66) { "Good" } else { "Poor" }
                Emoji = $statusEmoji
            }
        } else {
            Write-Host "`e[38;5;255m  └─ Result: 🔴 `e[38;5;196mAll tests failed`e[0m"
            $results += [PSCustomObject]@{
                Name = $serverName
                IP = $serverIP
                AvgTime = 9999
                SuccessRate = 0
                Status = "Failed"
                Emoji = "🔴"
            }
        }
        Write-Host ""
        Start-Sleep -Milliseconds 200
    }
    
    return $results | Sort-Object AvgTime
}

function Show-ModernTop3 {
    param([array]$Results)
    
    $top3 = $Results | Where-Object { $_.SuccessRate -gt 0 } | Select-Object -First 3
    
    Write-Host ""
    Write-Host "`e[38;5;226m┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓`e[0m"
    Write-Host "`e[38;5;226m┃`e[0m `e[38;5;255m                             🏆 Top 3 Winners                              `e[0m `e[38;5;226m┃`e[0m"
    Write-Host "`e[38;5;226m┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛`e[0m"
    Write-Host ""
    
    if ($top3.Count -eq 0) {
        Write-Host "`e[38;5;196m    ❌ No DNS servers responded successfully`e[0m"
        return
    }
    
    $medals = @("🥇", "🥈", "🥉")
    $colors = @("226", "255", "208")  # Gold, Silver, Bronze
    
    for ($i = 0; $i -lt [math]::Min(3, $top3.Count); $i++) {
        $server = $top3[$i]
        $color = $colors[$i]
        $medal = $medals[$i]
        $rank = $i + 1
        
        Write-Host "`e[38;5;$color    $medal Rank #$rank`e[0m"
        Write-Host "`e[38;5;255m    ┌─ `e[38;5;117m$($server.Name)`e[0m"
        Write-Host "`e[38;5;255m    │  📍 IP: `e[38;5;117m$($server.IP)`e[0m"
        Write-Host "`e[38;5;255m    │  ⚡ Speed: `e[38;5;117m$([math]::Round($server.AvgTime, 1))ms`e[0m"
        Write-Host "`e[38;5;255m    │  📊 Success: `e[38;5;117m$([math]::Round($server.SuccessRate, 0))%`e[0m"
        Write-Host "`e[38;5;255m    └─ Status: `e[38;5;117m$($server.Status) $($server.Emoji)`e[0m"
        Write-Host ""
    }
    
    # Clean recommendation
    Write-Host "`e[38;5;46m┌─ 💡 Recommendation`e[0m"
    Write-Host "`e[38;5;46m│`e[0m  Primary DNS: `e[38;5;117m$($top3[0].IP)`e[38;5;255m ($($top3[0].Name))`e[0m"
    if ($top3.Count -gt 1) {
        Write-Host "`e[38;5;46m│`e[0m  Secondary DNS: `e[38;5;117m$($top3[1].IP)`e[38;5;255m ($($top3[1].Name))`e[0m"
    }
    Write-Host "`e[38;5;46m└─`e[0m Configure these in your network settings for optimal performance"
    Write-Host ""
}

function Show-CompletionSummary {
    param([array]$Results)
    
    $successful = ($Results | Where-Object { $_.SuccessRate -gt 0 }).Count
    $fastest = $Results | Where-Object { $_.SuccessRate -gt 0 } | Select-Object -First 1
    
    Write-Host "`e[38;5;240m" + "─" * 80 + "`e[0m"
    Write-Host ""
    Write-Host "`e[38;5;46m    ✅ Benchmark completed successfully!`e[0m"
    Write-Host "`e[38;5;255m    📈 Tested: `e[38;5;117m$($Results.Count)`e[38;5;255m servers • Responding: `e[38;5;117m$successful`e[38;5;255m servers`e[0m"
    if ($fastest) {
        Write-Host "`e[38;5;255m    🚀 Fastest: `e[38;5;117m$($fastest.Name)`e[38;5;255m at `e[38;5;117m$([math]::Round($fastest.AvgTime, 1))ms`e[0m"
    }
    Write-Host "`e[38;5;255m    🕒 Completed: `e[38;5;117m$(Get-Date -Format 'HH:mm:ss')`e[0m"
    Write-Host ""
}

# Main execution function
function Start-ModernDNSBenchmark {
    Show-ModernBanner
    
    # Show system info first
    Invoke-ModernWinfetch
    
    # Modern DNS server list
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
        @{ Name = "CleanBrowsing"; IP = "185.228.168.9" }
    )
    
    # Run the benchmark
    $results = Test-ModernDNS -DNSList $dnsServers
    
    # Show top 3 results
    Show-ModernTop3 -Results $results
    
    # Show completion summary
    Show-CompletionSummary -Results $results
}

# Execute the modern DNS benchmark
Start-ModernDNSBenchmark
