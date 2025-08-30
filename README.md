# 🚀 Fast DNS Finder · Benchmark and Reveal the Best DNS in Seconds

# Usage
DNS Test is a shell script that requires curl or wget; on macOS/Linux it may prompt once for sudo to install Homebrew during the initial neofetch setup before continuing automatically.

## Launch Command macOS and Linux

Stable (recommended)
```bash
curl -fsSL https://raw.githubusercontent.com/F3aarLeSS/DNSTest/main/macOS_Linux.command | bash
```


## Launch Command Windows
```bash
powershell -ExecutionPolicy Bypass -NoProfile -Command "irm https://raw.githubusercontent.com/F3aarLeSS/DNSTest/refs/heads/main/windows.ps1 | iex"
```


Notes
- Use -fsSL so curl fails fast on HTTP errors, stays quiet, and follows redirects when hitting Raw GitHub links.
- Pin to a tag like v1.0.0 for reproducible runs and to avoid changes from main impacting automation.

## What You Get
- System info via neofetch; if missing, the script can interactively install Homebrew and then install neofetch before proceeding.
- Smooth progress bars while pinging primary and secondary IPv4 endpoints for multiple DNS providers.
- Cross‑platform parsing of ping summaries: Linux “rtt min/avg/max …” and macOS “round‑trip min/avg/max …” for accurate averages.
- A final Top 3 with large centered banners showing Provider, IP, and average latency for quick selection.

## Troubleshooting
- If a Raw link shows code instead of running, fetch it with curl/wget and pipe to bash or download then execute; avoid the blob URL.
- If Homebrew install is blocked, run the official installer once and then re‑run the script; shellenv exports PATH for immediate use.
- For fully non‑interactive runs, preinstall Homebrew and neofetch, then use the stable one‑liner above.

## Global Free DNS Providers (Quick View)
Legend: ✅ reliability | 🔒 privacy | 🛡 security | 🎛 filtering | ⚡ speed 

| Provider | Primary | Secondary | Strengths | Notes |
|---|---|---|---|---|
| Cloudflare | 1.1.1.1 | 1.0.0.1 | 🔒 · ⚡ | Family filters: 1.1.1.2 (malware), 1.1.1.3 (malware+adult)  |
| Google Public DNS | 8.8.8.8 | 8.8.4.4 | ✅ · ⚡ | No filtering; performance/security logging may apply  |
| Quad9 | 9.9.9.9 | 149.112.112.112 | 🛡 · ✅ | Non‑profit; blocks malicious domains  |
| OpenDNS (Cisco) | 208.67.222.222 | 208.67.220.220 | 🎛 · ✅ | Account needed for advanced filtering  |
| AdGuard DNS | 94.140.14.14 | 94.140.15.15 | 🎛 · 🔒 | Blocks ads/trackers/adult by default  |
| CleanBrowsing | 185.228.168.9 | 185.228.169.9 | 🎛 · 🛡 | Multiple policy endpoints for families/schools  |
| Verisign | 64.6.64.6 | 64.6.65.6 | ✅ · 🚫 | Stable, no redirection  |
| Yandex.DNS | 77.88.8.8 | 77.88.8.1 | 🎛 · 🛡 | “Safe/Family” profiles; region dependent  |
| Comodo Secure DNS | 8.26.56.26 | 8.20.247.20 | 🛡 · ✅ | Security‑oriented blocking  |
