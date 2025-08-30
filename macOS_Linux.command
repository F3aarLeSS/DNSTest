#!/usr/bin/env bash
# macOS_Linux: neofetch (auto‑install via Homebrew if needed), smooth bars, Top‑3 banners + summary table
set -euo pipefail

export LC_ALL=${LC_ALL:-C.UTF-8}
export LANG=${LANG:-C.UTF-8}

esc=$'\033'
RESET="${esc}[0m"; BOLD="${esc}[1m"; DIM="${esc}[2m"
FG_RED="${esc}[31m"; FG_GREEN="${esc}[32m"; FG_YELLOW="${esc}[33m"
FG_BLUE="${esc}[34m"; FG_MAGENTA="${esc}[35m"; FG_CYAN="${esc}[36m"; FG_WHITE="${esc}[37m"

COLUMNS=${COLUMNS:-100}

TMP_RESULTS="$(mktemp)"
cleanup(){ printf "%s" "$RESET"; rm -f "$TMP_RESULTS" /tmp/ping.$$ 2>/dev/null || true; }
trap cleanup EXIT INT TERM

os_id="$(uname -s 2>/dev/null || echo unknown)"

ensure_neofetch() {
  command -v neofetch >/dev/null 2>&1 && return 0
  if ! command -v brew >/dev/null 2>&1; then
    echo "${BOLD}${FG_YELLOW}Homebrew not found — launching interactive installer (sudo may prompt)…${RESET}"
    if [[ "$os_id" == "Darwin" ]]; then
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || { echo "${FG_RED}Homebrew install failed; continuing without neofetch.${RESET}"; return 0; }
      eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || true)"
      eval "$(/usr/local/bin/brew shellenv 2>/dev/null || true)"
    elif [[ "$os_id" == "Linux" ]]; then
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || { echo "${FG_RED}Homebrew install failed (Linux); continuing without neofetch.${RESET}"; return 0; }
      test -d ~/.linuxbrew && eval "$(~/.linuxbrew/bin/brew shellenv)"
      test -d /home/linuxbrew/.linuxbrew && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    else
      echo "${FG_YELLOW}Unsupported OS for Homebrew auto-install (${os_id}); skipping neofetch install.${RESET}"
      return 0
    fi
  else
    eval "$($(command -v brew) shellenv 2>/dev/null)" || true
  fi
  command -v neofetch >/dev/null 2>&1 || { echo "${BOLD}${FG_YELLOW}Installing neofetch with Homebrew…${RESET}"; brew update >/dev/null 2>&1 || true; brew install neofetch >/dev/null 2>&1 || echo "${FG_RED}Failed to install neofetch; continuing without it.${RESET}"; }
}

ensure_neofetch
if command -v neofetch >/dev/null 2>&1; then neofetch; else echo "${BOLD}${FG_GREEN}Neofetch not found; continuing with DNS tests…${RESET}"; fi

echo
echo "${BOLD}${FG_BLUE}DNS Section${RESET}"
echo "-----------"
echo

sleep_60fps(){ sleep 0.0167 2>/dev/null || sleep 0.02; }

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
    printf "${FG_GREEN}%s${RESET}%s] %2d/%-2d" "$(printf "%${filled}s" | tr ' ' '█')" "$(printf "%${empty}s")" "$ticks" "$total"
    sleep_60fps; ((f++))
  done
  printf "\r${FG_GREEN}%-10s${RESET} [%s] %2d/%-2d" "$label" "$(printf "%${width}s" | tr ' ' '█')" "$total" "$total"
}

ping_host(){
  local ip="$1" count="$2" timeout="$3"
  if ping -V >/dev/null 2>&1; then ping -c "$count" -W "$timeout" "$ip"; else ping -c "$count" -t $((timeout+2)) "$ip"; fi
}

parse_avg(){ local out="$1" line; line=$(echo "$out" | grep -E 'rtt min/avg/max|round-trip min/avg/max' | head -n1 || true); [[ -n "$line" ]] && echo "$line" | awk -F'=' '{print $2}' | awk -F'/' '{gsub(/ /,""); print $2}'; }
parse_loss(){ echo "$1" | grep -Eo '[0-9]+(\.[0-9]+)?% packet loss' | head -n1 | sed 's/% packet loss//'; }

info_line(){ printf "${BOLD}%-14s${RESET} %s\n" "$1" "$2"; }

PING_COUNT=5
PING_TIMEOUT=5
BAR_DURATION_MS=1000

DNS_SERVERS=(
  "Cloudflare,1.1.1.1,1.0.0.1"
  "Google,8.8.8.8,8.8.4.4"
  "Quad9,9.9.9.9,149.112.112.112"
  "OpenDNS,208.67.222.222,208.67.220.220"
  "AdGuard,94.140.14.14,94.140.15.15"
  "CleanBrowsing-Security,185.228.168.9,185.228.169.9"
  "Comodo,8.26.56.26,8.20.247.20"
  "Verisign,64.6.64.6,64.6.65.6"
  "OpenNIC,94.16.114.254,94.247.43.254"
)

echo "${BOLD}${FG_CYAN}Mode:${RESET} ${PING_COUNT} probes per host"
echo "${BOLD}${FG_CYAN}Timeout:${RESET} ${PING_TIMEOUT}s per probe"
echo "${BOLD}${FG_CYAN}Targets:${RESET} ${#DNS_SERVERS[@]} providers (primary + secondary)"
echo
echo "${BOLD}${FG_BLUE}Testing DNS (smooth ~60 fps bars)…${RESET}"
echo

for entry in "${DNS_SERVERS[@]}"; do
  IFS=',' read -r provider ip1 ip2 <<<"$entry"
  echo "${BOLD}${FG_CYAN}${provider}${RESET}"

  { ping_host "$ip1" "$PING_COUNT" "$PING_TIMEOUT" >/tmp/ping.$$ 2>&1 || true; } &
  ppid=$!; bar_green_60fps "Primary" "$PING_COUNT" "$BAR_DURATION_MS" & bpid=$!
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

  { ping_host "$ip2" "$PING_COUNT" "$PING_TIMEOUT" >/tmp/ping.$$ 2>&1 || true; } &
  ppid=$!; bar_green_60fps "Secondary" "$PING_COUNT" "$BAR_DURATION_MS" & bpid=$!
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

CLEAN="$(mktemp)"
awk -F',' 'NF==4 && $4 ~ /^[0-9]+(\.[0-9]+)?$/ && $3+0 < 100 {print $0}' "$TMP_RESULTS" > "$CLEAN"
TOP3="$(mktemp)"
sort -t',' -k4,4n "$CLEAN" | head -n 3 > "$TOP3"

center(){ local txt="$1" w=${COLUMNS:-80}; local len=${#txt}; local pad=$(( (w-len)/2 )); ((pad<0)) && pad=0; printf "%*s%s\n" "$pad" "" "$txt"; }

provider_tags(){
  case "$1" in
    Cloudflare)              echo "Speed, Privacy, Reliable";;
    Google)                  echo "Speed, Reliable, Global";;
    Quad9)                   echo "Malware-Protection, Privacy, Reliable";;
    OpenDNS)                 echo "Stable, Filtering, Security";;
    AdGuard)                 echo "Filtering, Privacy, Stable";;
    CleanBrowsing-Security)  echo "Security, Family-Filtering, Stable";;
    Comodo)                  echo "Security, Malware-Protection, Stable";;
    Verisign)                echo "Stable, Reliable, No-Redirection";;
    OpenNIC)                 echo "Community, Privacy, Variable-Speed";;
    *)                       echo "Reliable";;
  esac
}

printf "%s\n" "${BOLD}${FG_BLUE}Top 3 DNS — Summary Table${RESET}"
sep="+----------------+------------------+----------+-------------------------------------------+"
echo "$sep"
printf "| %-14s | %-16s | %-8s | %-41s |\n" "Provider" "IP" "Latency" "Details"
echo "$sep"
while IFS=',' read -r PNAME PIP PLOSS PLAT; do
  TAGS="$(provider_tags "$PNAME")"
  printf "| %-14s | %-16s | %7sms | %-41s |\n" "$PNAME" "$PIP" "$PLAT" "$TAGS"
done < "$TOP3"
echo "$sep"
echo

rm -f "$TOP3" "$CLEAN"
