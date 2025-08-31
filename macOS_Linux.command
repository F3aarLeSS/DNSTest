#!/usr/bin/env bash
#
# dns_benchmark.command
#
# A script to install Homebrew & dependencies (if missing), then run a latency
# test against popular DNS servers and display a summary of the top 3.

# --- Strict Mode & Environment Setup ---
set -euo pipefail
export LC_ALL=${LC_ALL:-C.UTF-8}
export LANG=${LANG:-C.UTF-8}

# --- ANSI Escape Codes for Styling ---
esc=$'\033'
RESET="${esc}[0m"; BOLD="${esc}[1m"; DIM="${esc}[2m"
FG_RED="${esc}[31m"; FG_GREEN="${esc}[32m"; FG_YELLOW="${esc}[33m"
FG_BLUE="${esc}[34m"; FG_MAGENTA="${esc}[35m"; FG_CYAN="${esc}[36m"

# --- Global Variables & Cleanup ---
COLUMNS=${COLUMNS:-100}
BOX_WIDTH=96

# Create secure temporary files for results
TMP_RESULTS="$(mktemp)"
CLEAN_RESULTS="$(mktemp)"
TOP_3_RESULTS="$(mktemp)"

cleanup(){
    printf "%s" "$RESET"
    rm -f "$TMP_RESULTS" "$CLEAN_RESULTS" "$TOP_3_RESULTS" /tmp/ping.$$ 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# --- Visual Helper Functions ---
print_header() {
    local title=" $1 "
    local color="${2:-$FG_BLUE}"
    local pad_len=$(( (COLUMNS - ${#title}) / 2 ))
    (( pad_len < 0 )) && pad_len=0
    local padding; padding=$(printf "%${pad_len}s" | tr ' ' '─')
    printf "\n%s%s%s%s%s%s\n\n" "${BOLD}${color}" "$padding" "$title" "$padding" "$( (( (${#title} + pad_len * 2) < COLUMNS )) && printf "─" )" "$RESET"
}

print_double_line_header() {
    local title=" $1 "
    local color="${2:-$FG_BLUE}"
    local clean_title; clean_title=$(echo -e "$title" | sed 's/\x1b\[[0-9;]*m//g')
    local title_len=${#clean_title}
    local box_width=$(( title_len + 2 ))
    local pad_len=$(( (COLUMNS - box_width) / 2 ))
    (( pad_len < 0 )) && pad_len=0
    local padding; padding=$(printf "%${pad_len}s")
    printf "\n%s%s╔%s╗" "$padding" "${BOLD}${color}" "$(printf '═%.0s' $(seq 1 $title_len))"
    printf "\n%s%s║%s║" "$padding" "${BOLD}${color}" "$title"
    printf "\n%s%s╚%s╝%s\n\n" "$padding" "${BOLD}${color}" "$(printf '═%.0s' $(seq 1 $title_len))" "$RESET"
}

# --- Box Drawing Functions ---
box_print() {
    local content="$1"
    local clean_content; clean_content=$(echo -e "$content" | sed 's/\x1b\[[0-9;]*m//g')
    local content_len=${#clean_content}
    local padding=$((BOX_WIDTH - 4 - content_len))
    ((padding < 0)) && padding=0
    printf "│ %s%*s │\n" "$content" "$padding" ""
}

box_printf() {
    local format_str="$1"; shift
    local content; content=$(printf "$format_str" "$@")
    box_print "$content"
}

print_box_top() { printf "╭%s╮\n" "$(printf '─%.0s' $(seq 1 $((BOX_WIDTH-2))))"; }
print_box_separator() { printf "├%s┤\n" "$(printf '─%.0s' $(seq 1 $((BOX_WIDTH-2))))"; }
print_box_bottom() { printf "╰%s╯\n" "$(printf '─%.0s' $(seq 1 $((BOX_WIDTH-2))))"; }
box_print_blank() { printf "│%*s│\n" "$((BOX_WIDTH-2))" ""; }

box_print_provider_header() {
    local provider_name=" $1 "
    local total_width=$((BOX_WIDTH - 4))
    local name_len=${#provider_name}
    local pad_len=$(( (total_width - name_len) / 2 ))
    (( pad_len < 0 )) && pad_len=0
    local left_pad; left_pad=$(printf "%${pad_len}s" | tr ' ' '╌')
    local right_pad="$left_pad"
    if (( (name_len + pad_len * 2) < total_width )); then 
        right_pad="${right_pad}╌"
    fi
    box_print "${DIM}${left_pad}${RESET}${BOLD}${FG_YELLOW}${provider_name}${RESET}${DIM}${right_pad}${RESET}"
}

generate_latency_bar() {
    local latency_ms="$1"
    ! [[ "$latency_ms" =~ ^[0-9]+(\.[0-9]+)?$ ]] && printf "%-18s" "" && return
    
    local lat_int=${latency_ms%.*}
    local bar_char="■"
    local max_bar_width=18
    local bar_color
    
    if (( lat_int < 30 )); then 
        bar_color="$FG_GREEN"
    elif (( lat_int < 80 )); then 
        bar_color="$FG_YELLOW"
    else 
        bar_color="$FG_RED"
    fi
    
    local bar_len=$(( (lat_int * max_bar_width) / 200 ))
    (( bar_len > max_bar_width )) && bar_len=$max_bar_width
    (( bar_len < 1 )) && bar_len=1
    
    local bar; bar=$(printf "%${bar_len}s" | tr ' ' "$bar_char")
    printf "%s%-*s%s" "$bar_color" "$max_bar_width" "$bar" "$RESET"
}

animated_bar(){
    local label="$1"
    local total_steps=${2:-3}
    local duration_ms=${3:-1000}
    
    local width=$(( (BOX_WIDTH > 80 ? 80 : BOX_WIDTH) - 32 ))
    (( width < 12 )) && width=12
    
    local sleep_interval=0.03
    local num_frames=$(( duration_ms * 1000 / 30 / 1000 ))
    local progress_char="▰"
    local remaining_char="-"
    local spinner_chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    
    for (( f=0; f<=num_frames; f++ )); do
        local steps_done=$(( (f * total_steps) / num_frames ))
        local filled=$(( (f * width) / num_frames ))
        (( filled > width )) && filled=$width
        local empty=$(( width - filled ))
        local spinner_char=${spinner_chars:f%${#spinner_chars}:1}
        
        printf "\r│   ${FG_CYAN}%s${RESET} %-10s [%s%s] %3d/%-3d" \
            "$spinner_char" "$label" \
            "${FG_GREEN}$(printf "%${filled}s" | tr ' ' "$progress_char")${RESET}" \
            "$(printf "%${empty}s" | tr ' ' "$remaining_char")" \
            "$steps_done" "$total_steps"
        sleep $sleep_interval
    done
    
    printf "\r│   ${FG_GREEN}✔${RESET} %-10s [%s] %3d/%-3d\n" \
        "$label" "$(printf "%${width}s" | tr ' ' "$progress_char")" \
        "$total_steps" "$total_steps"
}

# --- Core Logic ---
ensure_dependencies() {
    if ! command -v brew >/dev/null 2>&1; then
        echo "${BOLD}${FG_YELLOW}Homebrew not found. Starting official installer...${RESET}"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    
    # Add Homebrew to PATH
    if [[ -x "/opt/homebrew/bin/brew" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x "/usr/local/bin/brew" ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    elif [[ -d "$HOME/.linuxbrew" ]]; then
        eval "$($HOME/.linuxbrew/bin/brew shellenv)"
    elif [[ -d "/home/linuxbrew/.linuxbrew" ]]; then
        eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    fi
    
    if ! command -v brew >/dev/null 2>&1; then
        echo "${FG_RED}Homebrew installation failed. Continuing with reduced visuals.${RESET}"
        return 0
    fi
    
    local missing_packages=()
    for pkg in neofetch figlet lolcat; do
        ! command -v "$pkg" >/dev/null 2>&1 && missing_packages+=("$pkg")
    done
    
    if (( ${#missing_packages[@]} > 0 )); then
        echo "${BOLD}${FG_YELLOW}Installing missing dependencies (${missing_packages[*]}) via Homebrew...${RESET}"
        brew update >/dev/null 2>&1 || true
        if ! brew install "${missing_packages[@]}" >/dev/null 2>&1; then
            echo "${FG_RED}Failed to install dependencies. Continuing with reduced visuals.${RESET}"
        fi
    fi
}

ping_host(){
    local ip="$1" 
    local count="$2" 
    local timeout_ms="$3"
    
    if ping -V >/dev/null 2>&1; then
        # GNU ping (Linux)
        local timeout_s
        timeout_s=$(awk -v ms="$timeout_ms" 'BEGIN { print ms / 1000 }')
        ping -c "$count" -W "$timeout_s" "$ip"
    else
        # BSD ping (macOS)
        ping -c "$count" -W "$timeout_ms" "$ip"
    fi
}

# --- Parser Functions ---
parse_avg(){ 
    echo "$1" | awk -F'=' '/rtt|round-trip/ { gsub(/ /,"", $2); split($2, a, "/"); print a[2]; exit }'
}

parse_loss(){ 
    echo "$1" | grep -Eo '[0-9]+(\.[0-9]+)?% packet loss' | head -n1 | sed 's/% packet loss//'
}

# --- DNS Provider Data ---
DNS_SERVERS=( 
    "Cloudflare,1.1.1.1,1.0.0.1" 
    "Google,8.8.8.8,8.8.4.4" 
    "Quad9,9.9.9.9,149.112.112.112" 
    "OpenDNS,208.67.222.222,208.67.220.220" 
    "AdGuard,94.140.14.14,94.140.15.15" 
    "CleanBrowsing,185.228.168.9,185.228.169.9" 
    "Comodo,8.26.56.26,8.20.247.20" 
    "Verisign,64.6.64.6,64.6.65.6" 
)

provider_tags(){ 
    case "$1" in 
        Cloudflare) echo "Speed, Privacy, Modern";;
        Google) echo "Speed, Reliable, Global";;
        Quad9) echo "Security, Malware-Protection, Privacy";;
        OpenDNS) echo "Stable, Filtering, Security";;
        AdGuard) echo "Ad-Filtering, Privacy, Stable";;
        CleanBrowsing) echo "Family-Filtering, Security, Stable";;
        Comodo) echo "Security, Malware-Protection, Stable";;
        Verisign) echo "Stable, Reliable, No-Redirection";;
        *) echo "General Purpose";;
    esac
}

# --- Main Execution ---
print_header "System & Dependencies Check" "$FG_MAGENTA"
ensure_dependencies

# Display system info
if command -v neofetch >/dev/null 2>&1; then
    neofetch
fi

# Display custom banner for the benchmark
if command -v figlet >/dev/null 2>&1 && command -v lolcat >/dev/null 2>&1; then
    figlet -c -w "${COLUMNS:-96}" -f slant "DNS BENCHMARK" | lolcat
else
    print_double_line_header "🚀 DNS BENCHMARK 🚀" "$FG_CYAN"
fi

# START THE BOX for the benchmark
print_box_top

PING_COUNT=5
PING_TIMEOUT_MS=500
BAR_DURATION_MS=$((PING_COUNT * PING_TIMEOUT_MS + 500))

box_print_blank
box_print "${BOLD}Mode:${RESET}       ${PING_COUNT} probes per host"
box_print "${BOLD}Timeout:${RESET}    ${PING_TIMEOUT_MS}ms per probe"
box_print "${BOLD}Targets:${RESET}    ${#DNS_SERVERS[@]} providers (primary + secondary)"
box_print_blank

for entry in "${DNS_SERVERS[@]}"; do
    IFS=',' read -r provider ip1 ip2 <<<"$entry"
    print_box_separator
    
    box_print_provider_header "$provider"
    box_print_blank
    
    # Test Primary IP
    { ping_host "$ip1" "$PING_COUNT" "$PING_TIMEOUT_MS" >/tmp/ping.$$ 2>&1 || true; } &
    ppid=$!
    animated_bar "Primary" "$PING_COUNT" "$BAR_DURATION_MS" & 
    bpid=$!
    wait "$ppid"
    wait "$bpid" 2>/dev/null || true
    
    out1=$(cat /tmp/ping.$$ 2>/dev/null || true)
    rm -f /tmp/ping.$$
    loss1=$(parse_loss "$out1")
    avg1=$(parse_avg "$out1")
    
    if [[ -n "${avg1:-}" && "${loss1:-100}" != "100" ]]; then
        box_printf "    %-9s ${FG_GREEN}✔ OK${RESET}   avg=%-7sms loss=%-3s%% %s ${DIM}(%s)${RESET}" \
            "Primary" "$avg1" "${loss1:-0}" "$(generate_latency_bar "$avg1")" "$ip1"
        echo "$provider,$ip1,${loss1:-0},$avg1" >> "$TMP_RESULTS"
    else
        box_printf "    %-9s ${FG_RED}✖ UNREACHABLE${RESET}   loss=%-3s%% ${DIM}(%s)${RESET}" \
            "Primary" "${loss1:-100}" "$ip1"
    fi
    
    # Test Secondary IP
    { ping_host "$ip2" "$PING_COUNT" "$PING_TIMEOUT_MS" >/tmp/ping.$$ 2>&1 || true; } &
    ppid=$!
    animated_bar "Secondary" "$PING_COUNT" "$BAR_DURATION_MS" & 
    bpid=$!
    wait "$ppid"
    wait "$bpid" 2>/dev/null || true
    
    out2=$(cat /tmp/ping.$$ 2>/dev/null || true)
    rm -f /tmp/ping.$$
    loss2=$(parse_loss "$out2")
    avg2=$(parse_avg "$out2")
    
    if [[ -n "${avg2:-}" && "${loss2:-100}" != "100" ]]; then
        box_printf "    %-9s ${FG_GREEN}✔ OK${RESET}   avg=%-7sms loss=%-3s%% %s ${DIM}(%s)${RESET}" \
            "Secondary" "$avg2" "${loss2:-0}" "$(generate_latency_bar "$avg2")" "$ip2"
        echo "$provider,$ip2,${loss2:-0},$avg2" >> "$TMP_RESULTS"
    else
        box_printf "    %-9s ${FG_RED}✖ UNREACHABLE${RESET}   loss=%-3s%% ${DIM}(%s)${RESET}" \
            "Secondary" "${loss2:-100}" "$ip2"
    fi
    box_print_blank
done

print_box_bottom

# --- Process and Display Final Summary ---
awk -F',' 'NF==4 && $4 ~ /^[0-9]+(\.[0-9]+)?$/ && $3+0 < 100 {print $0}' "$TMP_RESULTS" > "$CLEAN_RESULTS"
sort -t',' -k4,4n "$CLEAN_RESULTS" | head -n 3 > "$TOP_3_RESULTS"

# Display styled header for the results
if command -v figlet >/dev/null 2>&1 && command -v lolcat >/dev/null 2>&1; then
    figlet -c -w "${COLUMNS:-96}" -f slant "TOP 3 RESULTS" | lolcat
else
    print_double_line_header "🏆 TOP 3 RESULTS 🏆" "$FG_GREEN"
fi

if [[ ! -s "$TOP_3_RESULTS" ]]; then
    printf "  ${FG_RED}No reachable DNS servers were found during the test.${RESET}\n"
else
    # Table structure
    T_TOP="╔═══════════════════╦═════════════════════╦══════════════════════════╦══════════════════════════════════════════╗"
    T_HEADER_SEP="╠═══════════════════╬═════════════════════╬══════════════════════════╬══════════════════════════════════════════╣"
    T_ROW_SEP="╟───────────────────╫─────────────────────╫──────────────────────────╫──────────────────────────────────────────╢"
    T_BOT="╚═══════════════════╩═════════════════════╩══════════════════════════╩══════════════════════════════════════════╝"
    
    # Print table header
    echo "$T_TOP"
    printf "║ ${BOLD}%-19s${RESET} ║ ${BOLD}%-19s${RESET} ║ ${BOLD}%-26s${RESET} ║ ${BOLD}%-42s${RESET} ║\n" \
        "🏆 Provider" "IP Address" "Latency (ms & Bar)" "Features"
    echo "$T_HEADER_SEP"
    
    rank=1
    total_rows=$(wc -l < "$TOP_3_RESULTS")
    while IFS=',' read -r PNAME PIP PLOSS PLAT; do
        TAGS="$(provider_tags "$PNAME")"
        LAT_BAR="$(generate_latency_bar "$PLAT")"
        
        # Color the latency text based on value
        lat_int=${PLAT%.*}
        lat_color=""
        if (( lat_int < 30 )); then 
            lat_color="$FG_GREEN"
        elif (( lat_int < 80 )); then 
            lat_color="$FG_YELLOW"
        else 
            lat_color="$FG_RED"
        fi
        
        LAT_TEXT_PADDED=$(printf "%7s" "${PLAT}ms")
        LAT_TEXT_COLORED=$(printf "%s%s%s" "$lat_color" "$LAT_TEXT_PADDED" "$RESET")
        LAT_FORMATTED=$(printf "%s %s" "$LAT_TEXT_COLORED" "$LAT_BAR")
        
        # Determine the prefix for the provider name
        PNAME_PREFIX=""
        if (( rank == 1 )); then
            PNAME_PREFIX="🏆 "
        else
            PNAME_PREFIX="  "
        fi
        
        printf "║ %s%-17s ║ %-19s ║ %s ║ ${FG_YELLOW}%-42s${RESET} ║\n" \
            "$PNAME_PREFIX" "$PNAME" "$PIP" "$LAT_FORMATTED" "$TAGS"
        
        # Print row separator if it's not the last row
        (( rank < total_rows )) && echo "$T_ROW_SEP"
        
        ((rank++))
    done < "$TOP_3_RESULTS"
    echo "$T_BOT"
    
    # Display winner
    winner_line=$(head -n 1 "$TOP_3_RESULTS")
    if [[ -n "$winner_line" ]]; then
        IFS=',' read -r W_PNAME W_PIP W_PLOSS W_PLAT <<<"$winner_line"
        command -v tput >/dev/null 2>&1 && tput flash
        print_double_line_header "🏆 Winner: ${W_PNAME} (${W_PIP}) at ${W_PLAT}ms 🏆" "$FG_GREEN"
        printf "\a"
    fi
fi

echo
