#!/usr/bin/env bash
# NeoDNS Top-3 with interactive Homebrew install (Option B) + neofetch + big banners
set -euo pipefail

# Locale
export LC_ALL=${LC_ALL:-C.UTF-8}
export LANG=${LANG:-C.UTF-8}

# Colors
esc=$'\033'
RESET="${esc}[0m"; BOLD="${esc}[1m"; DIM="${esc}[2m"
FG_RED="${esc}[31m"; FG_GREEN="${esc}[32m"; FG_YELLOW="${esc}[33m"
FG_BLUE="${esc}[34m"; FG_MAGENTA="${esc}[35m"; FG_CYAN="${esc}[36m"

COLUMNS=${COLUMNS:-100}

# Temp
TMP_RESULTS="$(mktemp)"
cleanup(){ printf "%s" "$RESET"; rm -f "$TMP_RESULTS" /tmp/ping.$$ 2>/dev/null || true; }
trap cleanup EXIT INT TERM

# Detect OS (Darwin/Linux)
os_id="$(uname -s 2>/dev/null || echo unknown)"  # Darwin/Linux/etc. [5]

# Ensure neofetch: if missing, interactively install Homebrew (sudo may prompt), then brew install neofetch
ensure_neofetch() {
  if command -v neofetch >/dev/null 2>&1; then return 0; fi

  if ! command -v brew >/dev/null 2>&1; then
    echo "${BOLD}${FG_YELLOW}Homebrew not found — launching interactive installer (sudo may prompt)…${RESET}"
    if [[ "$os_id" == "Darwin" ]]; then
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
        echo "${FG_RED}Homebrew install failed; continuing without neofetch.${RESET}"; return 0; }  # [1]
      # macOS shellenv (Apple Silicon then Intel paths)
      eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || true)"  # [2]
      eval "$(/usr/local/bin/brew shellenv 2>/dev/null || true)"     # [2]
    elif [[ "$os_id" == "Linux" ]]; then
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
        echo "${FG_RED}Homebrew install failed (Linux); continuing without neofetch.${RESET}"; return 0; }  # [2]
      # Linux shellenv (two common prefixes)
      test -d ~/.linuxbrew && eval "$(~/.linuxbrew/bin/brew shellenv)"   # [2]
      test -d /home/linuxbrew/.linuxbrew && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"  # [2]
    else
      echo "${FG_YELLOW}Unsupported OS for Homebrew auto-install (${os_id}); skipping neofetch install.${RESET}"  # [5]
      return 0
    fi
  else
    # If brew exists, export its environment now
    eval "$($(command -v brew) shellenv 2>/dev/null)" || true  # [2]
  fi

  # Install neofetch if still missing
  if ! command -v neofetch >/dev/null 2>&1; then
    echo "${BOLD}${FG_YELLOW}Installing neofetch with Homebrew…${RESET}"
    brew update >/dev/null 2>&1 || true  # [2]
    brew install neofetch >/dev/null 2>&1 || {
      echo "${FG_RED}Failed to install neofetch; continuing without it.${RESET}"; return 0; }  # [2]
  fi
}

# Run neofetch (after ensuring)
ensure_neofetch  # may prompt for sudo once via the official installer [1]
if command -v neofetch >/dev/null 2>&1; then
  neofetch  # [6]
else
  echo "${BOLD}${FG_GREEN}Neofetch not found; continuing with DNS tests…${RESET}"  # [1]
fi

echo
echo "${BOLD}${FG_BLUE}DNS Section${RESET}"
echo "-----------"
echo

# Smooth animation helper (~60 fps, fallback to ~50 fps)
sleep_60fps(){ sleep 0.0167 2>/dev/null || sleep 0.02; }  # [7][8]

# Per-target green progress bar at ~60 fps
bar_green_60fps(){
  local label="$1" total=${2:-3} duration_ms=${3:-1000}
  local width=$(( (COLUMNS>80?80:COLUMNS) - 28 )); (( width<12 )) && width=12
  local frames=$(( duration_ms / 17 )); (( frames < total )) && frames=$total
  local f=0
  while (( f < frames )); do
    local ticks=$(( (f * total) / frames ))
    local filled=$(( (ticks * width) / (total>0?total:1) )); (( filled > width )) && filled=$width
    local empty=$(( width - filled ))
    printf "\r${FG_GREEN}%-10s${RESET} [" "$label"
    printf "${FG_GREEN}%s${RESET}%s] %2d/%-2d" \
      "$(printf "%${filled}s" | tr ' ' '█')" \
      "$(printf "%${empty}s")" \
      "$ticks" "$total"
    sleep_60fps; ((f++))
  done
  printf "\r${FG_GREEN}%-10s${RESET} [%s] %2d/%-2d" "$label" "$(printf "%${width}s" | tr ' ' '█')" "$total" "$total"
}

# Cross‑platform ping (Linux iputils vs macOS/BSD)
ping_host(){
  local ip="$1" count="$2" timeout="$3"
  if ping -V >/dev/null 2>&1; then ping -c "$count" -W "$timeout" "$ip";  # Linux -W seconds [9]
  else ping -c "$count" -t $((timeout+2)) "$ip"; fi                         # macOS/BSD -t used by installer docs [10]
}

# Robust parsers (macOS “round-trip …” and Linux “rtt …”)
parse_avg(){ local out="$1" line
  line=$(echo "$out" | grep -E 'rtt min/avg/max|round-trip min/avg/max' | head -n1 || true)  # [3]
  if [[ -n "$line" ]]; then echo "$line" | awk -F'=' '{print $2}' | awk -F'/' '{gsub(/ /,""); print $2}'; fi  # [3]
}
parse_loss(){ echo "$1" | grep -Eo '[0-9]+(\.[0-9]+)?% packet loss' | head -n1 | sed 's/% packet loss//'; }  # [3]

# Info line
info_line(){ printf "${BOLD}%-14s${RESET} %s\n" "$1" "$2"; }

# Settings (tune as preferred)
PING_COUNT=5
PING_TIMEOUT=5
BAR_DURATION_MS=1000

# Providers (primary, secondary)
DNS_SERVERS=(
  "Cloudflare,1.1.1.1,1.0.0.1"
  "Google,8.8.8.8,8.8.4.4"
  "Quad9,9.9.9.9,149.112.112.112"
  "OpenDNS,208.67.222.222,208.67.220.220"
)

echo "${BOLD}${FG_CYAN}Mode:${RESET} ${PING_COUNT} probes per host"
echo "${BOLD}${FG_CYAN}Timeout:${RESET} ${PING_TIMEOUT}s per probe"
echo "${BOLD}${FG_CYAN}Targets:${RESET} ${#DNS_SERVERS[@]} providers (primary + secondary)"
echo
echo "${BOLD}${FG_BLUE}Testing DNS (smooth ~60 fps bars)…${RESET}"
echo

# Main loop: ping both endpoints and collect results
for entry in "${DNS_SERVERS[@]}"; do
  IFS=',' read -r provider ip1 ip2 <<<"$entry"
  echo "${BOLD}${FG_CYAN}${provider}${RESET}"

  # Primary
  { ping_host "$ip1" "$PING_COUNT" "$PING_TIMEOUT" >/tmp/ping.$$ 2>&1 || true; } &
  ppid=$!
  bar_green_60fps "Primary" "$PING_COUNT" "$BAR_DURATION_MS" &
  bpid=$!
  wait "$ppid"; wait "$bpid" 2>/dev/null || true
  printf "\r\033[K"
  out1=$(cat /tmp/ping.$$ 2>/dev/null || true); rm -f /tmp/ping.$$
  loss1=$(parse_loss "$out1"); avg1=$(parse_avg "$out1")
  if [[ -n "${avg1:-}" && "${loss1:-100}" != "100" ]]; then
    info_line "Primary" "${FG_GREEN}OK${RESET}  loss=${loss1:-0}%  avg=${avg1}ms  ${DIM}(${ip1})${RESET}"
    echo "$provider,$ip1,${loss1:-0},$avg1" >> "$TMP_RESULTS"
  else
    info_line "Primary" "${FG_RED}UNREACHABLE${RESET}  loss=${loss1:-100}%  ${DIM}(${ip1})${RESET}"
  fi

  # Secondary
  { ping_host "$ip2" "$PING_COUNT" "$PING_TIMEOUT" >/tmp/ping.$$ 2>&1 || true; } &
  ppid=$!
  bar_green_60fps "Secondary" "$PING_COUNT" "$BAR_DURATION_MS" &
  bpid=$!
  wait "$ppid"; wait "$bpid" 2>/dev/null || true
  printf "\r\033[K"
  out2=$(cat /tmp/ping.$$ 2>/dev/null || true); rm -f /tmp/ping.$$
  loss2=$(parse_loss "$out2"); avg2=$(parse_avg "$out2")
  if [[ -n "${avg2:-}" && "${loss2:-100}" != "100" ]]; then
    info_line "Secondary" "${FG_GREEN}OK${RESET}  loss=${loss2:-0}%  avg=${avg2}ms  ${DIM}(${ip2})${RESET}"
    echo "$provider,$ip2,${loss2:-0},$avg2" >> "$TMP_RESULTS"
  else
    info_line "Secondary" "${FG_RED}UNREACHABLE${RESET}  loss=${loss2:-100}%  ${DIM}(${ip2})${RESET}"
  fi
  echo
done

# Compute Top 3 by lowest latency and print giant, centered banners
CLEAN="$(mktemp)"
awk -F',' 'NF==4 && $4 ~ /^[0-9]+(\.[0-9]+)?$/ && $3+0 < 100 {print $0}' "$TMP_RESULTS" > "$CLEAN"  # [11]

TOP3="$(mktemp)"
sort -t',' -k4,4n "$CLEAN" | head -n 3 > "$TOP3"  # numeric sort by latency, take 3 [12]

# Center helper for fallback
center(){ local txt="$1" w=${COLUMNS:-80}; local len=${#txt}; local pad=$(( (w-len)/2 )); ((pad<0)) && pad=0; printf "%*s%s\n" "$pad" "" "$txt"; }

rank=1
while IFS=',' read -r PNAME PIP PLOSS PLAT; do
  TITLE="Here Is Your Best DNS  #$rank"
  LINE="${PNAME}   ${PIP}   ${PLAT}ms"
  echo
  if command -v toilet >/dev/null 2>&1; then
    printf "%s\n" "$TITLE" | toilet -f slant -w "$COLUMNS" -c 2>/dev/null || center "$TITLE"  # [13]
    printf "%s\n" "$LINE"  | toilet -f big   -w "$COLUMNS" -c --filter border:metal 2>/dev/null || center "$LINE"  # [14]
  elif command -v figlet >/dev/null 2>&1; then
    figlet -w "$COLUMNS" -c "$TITLE" 2>/dev/null || center "$TITLE"  # [15]
    figlet -w "$COLUMNS" -c -f big "$LINE" 2>/dev/null || figlet -w "$COLUMNS" -c "$LINE"  # [15]
  else
    center "$TITLE"
    echo
    center "$LINE"
  fi
  rank=$((rank+1))
done < "$TOP3"
echo

rm -f "$TOP3" "$CLEAN"
