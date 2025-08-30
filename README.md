Quick start

Latest tag (recommended for reproducible results):
curl -fsSL https://raw.githubusercontent.com/<user>/DNSTest/v1.0.0/NeoDNS_Top3.command | bash 

Inspect first, then run:
curl -fsSL -o neodns.sh https://raw.githubusercontent.com/<user>/DNSTest/v1.0.0/NeoDNS_Top3.command && bash neodns.sh

Tip: Use -fsSL so curl follows redirects, fails fast on HTTP errors, and stays quiet while still surfacing errors. This is a common best practice for Raw GitHub script runners.

What it does

Shows neofetch (optional); if missing, offers interactive Homebrew install on macOS/Linux, then installs neofetch via brew and proceeds.

Pings resolvers’ primary and secondary IPv4s; extracts average RTT from Linux “rtt min/avg/max …” or macOS “round‑trip min/avg/max …”, ensuring correct averages across platforms.

Sorts and displays the Top 3 endpoints by the lowest average latency as large, centered banners for quick visual selection.

🌍 Global Free DNS Providers
Google Public DNS

8.8.8.8, 8.8.4.4

✅ Very reliable, fast, no content filtering.

⚠️ May log data for performance/security.

Cloudflare DNS

1.1.1.1, 1.0.0.1

✅ Privacy focused (claims not to log IPs), fast worldwide.

⚡ Family filters available: 1.1.1.2, 1.1.1.3.

Quad9 DNS

9.9.9.9, 149.112.112.112

✅ Blocks malicious domains, good for security.

📍 Operated as a non‑profit.

OpenDNS (Cisco)

208.67.222.222, 208.67.220.220

✅ Custom filtering (phishing/adult), very stable.

⚠️ Advanced filtering needs an account.

AdGuard DNS

94.140.14.14, 94.140.15.15

✅ Blocks ads, trackers, adult content.

CleanBrowsing DNS

185.228.168.9, 185.228.169.9

✅ Good for families/schools, multiple filtering modes.

Verisign Public DNS

64.6.64.6, 64.6.65.6

✅ Reliable, stable, no redirection.

Neustar UltraDNS Public

Commonly offered with security/family-safe modes; check current public endpoints on provider docs.

Yandex.DNS (Russia-based)

77.88.8.8, 77.88.8.1

✅ Offers “Safe” (malware/adult blocking) and “Family” (stricter) options; verify regional availability.

Comodo Secure DNS

8.26.56.26, 8.20.247.20

✅ Focused on blocking malicious sites and security.

Notes:

Endpoints and policies can change; verify on providers’ official pages before long‑term use, and prefer pinned versions of this script for reproducible behavior.

FAQ
Does this change system DNS?
No. It only pings resolvers to measure latency and packet loss; switching DNS must be done separately in system or router settings.

What if neofetch/Homebrew cannot be installed?
The script continues without neofetch and still runs the DNS tests.

Can this run without an interactive prompt?
Yes—if Homebrew and neofetch are already installed. Otherwise, the first brew install on macOS/Linux may prompt for sudo.
