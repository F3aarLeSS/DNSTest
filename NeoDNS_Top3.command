#!/usr/bin/env bash
set -euo pipefail

# Locale / UTF-8
export LC_ALL=${LC_ALL:-C.UTF-8}
export LANG=${LANG:-C.UTF-8}

# ANSI colors
esc=$'\033'
RESET="${esc}[0m"; BOLD="${esc}[1m"; DIM="${esc}[2m"
FG_RED="${esc}[31m"; FG_GREEN="${esc}[32m"; FG_YELLOW="${esc}[33m"
FG_BLUE="${esc}[34m"; FG_MAGENTA="${esc}[35m"; FG_CYAN="${esc}[36m"; FG_WHITE="${esc}[37m"

COLUMNS=${COLUMNS:-100}

# Temp and cleanup
TMP_RESULTS="$(mktemp)"
cleanup(){ printf "%s" "$RESET"; rm -f "$TMP_RESULTS" /tmp/ping.$$ 2>/dev/null || true; }
trap cleanup EXIT INT TERM

# 1) Run neofetch first (if present)
if command -v neofetch >/dev/null 2>&1; then
  neofetch
else
  echo "${BOLD}${FG_GREEN}Neofetch not found; continuing with DNS tests...${RESET}"
fi

echo
echo "${BOLD}${FG_BLUE}DNS Section${RESET}"
echo "-----------"
echo

# Sleep helpers for smooth animation (target ~60 fps)
sleep_60fps(){ sleep 0.0167 2>/dev/null || sleep 0.02; }

# Per-target green loading bar at ~60 fps (duration-based)
bar_green_60fps(){
  # label, total_ticks, duration_ms
  local label="$1" total=${2:-3} duration_ms=${3:-1000}
  local width=$(( (COLUMNS>80?80:COLUMNS) - 28 )); (( width<12 )) && width=12
  local frames=$(( duration_ms / 17 )); (( frames < total )) && frames=$total
  local f=0
  while (( f < frames )); do
    local ticks=$(( (f * total) / frames ))
    local filled=$(( (ticks * width) / (total>0?total:1) ))
    (( filled > width )) && filled=$width
    local e=$(( width - filled ))
    local fbar; fbar=$(printf "%${filled}s" | tr ' ' '█')
    local ebar; ebar=$(printf "%${e}s" ' ')
    printf "\r${FG_GREEN}%-10s${RESET} [${FG_GREEN}%s${RESET}%s] %2d/%-2d" "$label" "$fbar" "$ebar" "$ticks" "$total"
    sleep_60fps; ((f++))
  done
  local full; full=$(printf "%${width}s" | tr ' ' '█')
  printf "\r${FG_GREEN}%-10s${RESET} [${FG_GREEN}%s${RESET}] %2d/%-2d" "$label" "$full" "$total" "$total"
}

# Cross-platform ping wrapper
ping_host(){
  local ip="$1" count="$2" timeout="$3"
  if ping -V >/dev/null 2>&1; then ping -c "$count" -W "$timeout" "$ip";   # Linux iputils -W seconds
  else ping -c "$count" -t $((timeout+2)) "$ip"; fi                          # macOS/BSD use -t as TTL/timeout
}

# Robust ping parsers for avg and loss
parse_avg(){ local out="$1" line
  line=$(echo "$out" | grep -E 'rtt min/avg/max|round-trip min/avg/max' | head -n1 || true)
  if [[ -n "$line" ]]; then echo "$line" | awk -F'=' '{print $2}' | awk -F'/' '{gsub(/ /,""); print $2}'; fi
}
parse_loss(){ echo "$1" | grep -Eo '[0-9]+(\.[0-9]+)?% packet loss' | head -n1 | sed 's/% packet loss//'; }

# Info line (neofetch-like)
info_line(){ printf "${BOLD}%-14s${RESET} %s\n" "$1" "$2"; }

# Settings
PING_COUNT=5
PING_TIMEOUT=5        # keep 5s probe timeout as set earlier
BAR_DURATION_MS=1000  # per bar animation time

# Providers
DNS_SERVERS=(
  "Cloudflare,1.1.1.1,1.0.0.1"
  "Google,8.8.8.8,8.8.4.4"
  "Quad9,9.9.9.9,149.112.112.112"
  "OpenDNS,208.67.222.222,208.67.220.220"
  "AdGuard,94.140.14.14,94.140.15.15"
  "CleanBrowsing-Security,185.228.168.9,185.228.169.9"
  "Comodo,8.26.56.26,8.20.247.20"
  "Verisign,64.6.64.6,64.6.65.6"
  "AlternateDNS,76.76.19.19,76.223.122.150"
  "OpenNIC,94.16.114.254,94.247.43.254"
)

echo "${BOLD}${FG_CYAN}Mode:${RESET} ${PING_COUNT} probes per host"
echo "${BOLD}${FG_CYAN}Timeout:${RESET} ${PING_TIMEOUT}s per probe"
echo "${BOLD}${FG_CYAN}Targets:${RESET} ${#DNS_SERVERS[@]} providers (primary + secondary)"
echo
echo "${BOLD}${FG_BLUE}Testing DNS (green bars at ~60 fps)…${RESET}"
echo

# Loop
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

# Find the best endpoint (min latency) and print huge banner
CLEAN="$(mktemp)"
awk -F',' 'NF==4 && $4 ~ /^[0-9]+(\.[0-9]+)?$/ && $3+0 < 100 {print $0}' "$TMP_RESULTS" > "$CLEAN"

BEST=$(awk -F',' 'NR==1 || ($4+0)<min {min=$4+0; line=$0} END{print line}' "$CLEAN")
BEST_NAME=$(echo "$BEST" | awk -F',' '{print $1}')
BEST_IP=$(echo "$BEST"   | awk -F',' '{print $2}')
BEST_LAT=$(echo "$BEST"  | awk -F',' '{print $4}')

# --- Big centered banner for the best DNS ---
TEXT_TITLE="Here Is Your Best DNS"
TEXT_LINE="${BEST_NAME}   ${BEST_IP}   ${BEST_LAT}ms"

echo
# Print title centered using figlet/toilet if available; otherwise manual center
if command -v toilet >/dev/null 2>&1; then
  # Title (medium) centered
  printf "%s\n" "$TEXT_TITLE" | toilet -f slant -w "$COLUMNS" -c 2>/dev/null || printf "%s\n" "$TEXT_TITLE"
  # Big banner line centered; '-w COLUMNS' sets width and '-c' centers output
  printf "%s\n" "$TEXT_LINE" | toilet -f big -w "$COLUMNS" -c --filter border:metal 2>/dev/null || printf "%s\n" "$TEXT_LINE"
elif command -v figlet >/dev/null 2>&1; then
  # Title (medium) centered
  figlet -w "$COLUMNS" -c "$TEXT_TITLE" 2>/dev/null || printf "%s\n" "$TEXT_TITLE"
  # Big line centered; big/slant/banners are large glyph fonts approximating 35–40 "visual size"
  figlet -w "$COLUMNS" -c -f big "$TEXT_LINE" 2>/dev/null || figlet -w "$COLUMNS" -c "$TEXT_LINE"
else
  # Manual center fallback
  center() { local txt="$1" w=${COLUMNS:-80}; local len=${#txt}; local pad=$(( (w-len)/2 )); ((pad<0)) && pad=0; printf "%*s%s\n" "$pad" "" "$txt"; }
  center "$TEXT_TITLE"
  echo
  center "$TEXT_LINE"
fi
echo

rm -f "$CLEAN"
