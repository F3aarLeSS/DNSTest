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
Legend:

✅ reliability | 🔒 privacy | 🛡 security | 🎛 filtering | ⚡ speed

Provider	Primary	Secondary	Strengths	Notes
Cloudflare	1.1.1.1	1.0.0.1	🔒 privacy - ⚡ speed	Family filters: 1.1.1.2 (malware), 1.1.1.3 (malware+adult)
Google Public DNS	8.8.8.8	8.8.4.4	✅ reliability - ⚡ speed	No content filtering; performance/security data may be logged
Quad9	9.9.9.9	149.112.112.112	🛡 security (malware blocking) - ✅ reliable	Non‑profit operator
OpenDNS (Cisco)	208.67.222.222	208.67.220.220	🎛 custom filtering - ✅ stable	Account required for advanced policies
AdGuard DNS	94.140.14.14	94.140.15.15	🎛 ad/trackers/adult blocking - 🔒 privacy‑minded	Good default protection out of the box
CleanBrowsing	185.228.168.9	185.228.169.9	🎛 family/school filters - 🛡 safe browsing	Multiple policy endpoints (Family/Adult/Security)
Verisign Public DNS	64.6.64.6	64.6.65.6	✅ stable - 🚫 no redirection	Straightforward, dependable resolvers
Neustar UltraDNS Public	—	—	🛡 security - 🎛 family‑safe modes	Check provider docs for current public IPs
Yandex.DNS	77.88.8.8	77.88.8.1	🎛 Safe/Family profiles - 🛡 blocking	Region‑dependent performance/availability
Comodo Secure DNS	8.26.56.26	8.20.247.20	🛡 malicious‑site blocking - ✅ reliable	Security‑centric policy set

Notes:

Endpoints and policies can change; verify on providers’ official pages before long‑term use, and prefer pinned versions of this script for reproducible behavior.

FAQ
Does this change system DNS?
No. It only pings resolvers to measure latency and packet loss; switching DNS must be done separately in system or router settings.

What if neofetch/Homebrew cannot be installed?
The script continues without neofetch and still runs the DNS tests.

Can this run without an interactive prompt?
Yes—if Homebrew and neofetch are already installed. Otherwise, the first brew install on macOS/Linux may prompt for sudo.
