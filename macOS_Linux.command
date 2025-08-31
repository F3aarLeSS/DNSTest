#!/usr/bin/env bash
#
# macOS_Linux.command
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
FG_WHITE="${esc}[37m"; FG_GRAY="${esc}[90m"; FG_BROWN="${esc}[38;5;130m"
FG_ORANGE="${esc}[38;5;214m"; FG_BRIGHT_WHITE="${esc}[97m"

# --- Global Variables & Cleanup ---
TERMINAL_COLS=$(tput cols)
COLUMNS=${COLUMNS:-$TERMINAL_COLS}
BOX_WIDTH=96

# Calculate centering offset
CENTER_OFFSET=$(( (TERMINAL_COLS - BOX_WIDTH) / 2 ))
[[ $CENTER_OFFSET -lt 0 ]] && CENTER_OFFSET=0

# Create secure temporary files for results
TMP_RESULTS="$(mktemp)"
CLEAN_RESULTS="$(mktemp)"
TOP_3_RESULTS="$(mktemp)"

cleanup(){
    printf "%s" "$RESET"
    rm -f "$TMP_RESULTS" "$CLEAN_RESULTS" "$TOP_3_RESULTS" /tmp/ping.$$ 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# --- Centering Helper Function ---
center_print() {
    local content="$1"
    printf "%*s%s\n" "$CENTER_OFFSET" "" "$content"
}

center_printf() {
    local format_str="$1"; shift
    local content; content=$(printf "$format_str" "$@")
    center_print "$content"
}

# --- Installation Banner Functions ---
show_installation_banner() {
    local title="$1"
    local subtitle="${2:-}"
    
    printf "\n"
    center_printf "%s%s╔══════════════════════════════════════════════════════════════════════════════╗" "$BOLD" "$FG_CYAN"
    center_printf "%s%s║                                                                              ║" "$BOLD" "$FG_CYAN"
    center_printf "%s%s║                            🚀 DNS BENCHMARK SETUP 🚀                         ║" "$BOLD" "$FG_CYAN"
    center_printf "%s%s║                                                                              ║" "$BOLD" "$FG_CYAN"
    center_printf "%s%s╠══════════════════════════════════════════════════════════════════════════════╣" "$BOLD" "$FG_CYAN"
    center_printf "%s%s║                                                                              ║" "$BOLD" "$FG_CYAN"
    center_printf "%s%s║  %-74s  ║%s" "$BOLD" "$FG_CYAN" "$title" "$RESET"
    if [[ -n "$subtitle" ]]; then
        center_printf "%s%s║  %-74s  ║%s" "$BOLD" "$FG_CYAN" "$subtitle" "$RESET"
    fi
    center_printf "%s%s║                                                                              ║" "$BOLD" "$FG_CYAN"
    center_printf "%s%s╚══════════════════════════════════════════════════════════════════════════════╝%s" "$BOLD" "$FG_CYAN" "$RESET"
    printf "\n"
}

simple_spinner() {
    local message="$1"
    local pid="$2"
    local spinner_chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local i=0
    
    while kill -0 "$pid" 2>/dev/null; do
        local spinner_char=${spinner_chars:i%${#spinner_chars}:1}
        printf "\r%*s${FG_YELLOW}%s${RESET} %s..." "$CENTER_OFFSET" "" "$spinner_char" "$message"
        sleep 0.2
        ((i++))
    done
    
    wait "$pid"
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        printf "\r%*s${FG_GREEN}✔${RESET} %s... ${FG_GREEN}Complete!${RESET}\n" "$CENTER_OFFSET" "" "$message"
    else
        printf "\r%*s${FG_RED}✖${RESET} %s... ${FG_RED}Failed!${RESET}\n" "$CENTER_OFFSET" "" "$message"
    fi
    
    return $exit_code
}

# --- Core Logic ---
ensure_dependencies() {
    # Check if Homebrew is installed
    if ! command -v brew >/dev/null 2>&1; then
        show_installation_banner "Installing Homebrew Package Manager" "This may take a few minutes and require your password..."
        
        center_printf "${FG_YELLOW}🍺 Starting Homebrew installation...${RESET}"
        center_printf "${FG_BLUE}   You may be prompted for your password by the installer.${RESET}"
        printf "\n"
        
        # Install Homebrew with live output (user interaction needed)
        if ! /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
            printf "\n"
            center_printf "${FG_RED}❌ Homebrew installation failed. Continuing with basic visuals.${RESET}"
            sleep 2
            return 0
        fi
        
        printf "\n"
        center_printf "${FG_GREEN}🎉 Homebrew installation completed successfully!${RESET}"
        sleep 1
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
    
    # Verify Homebrew is now available
    if ! command -v brew >/dev/null 2>&1; then
        printf "\n"
        center_printf "${FG_RED}❌ Homebrew installation failed. Continuing with basic visuals.${RESET}"
        sleep 2
        return 0
    fi
    
    # Check for missing packages
    local missing_packages=()
    for pkg in neofetch figlet lolcat; do
        if ! command -v "$pkg" >/dev/null 2>&1; then
            missing_packages+=("$pkg")
        fi
    done
    
    # Install missing packages if any
    if (( ${#missing_packages[@]} > 0 )); then
        show_installation_banner "Installing Required Dependencies" "Installing: ${missing_packages[*]}"
        
        center_printf "${FG_YELLOW}📦 Installing dependencies for enhanced visuals...${RESET}"
        printf "\n"
        
        # Update Homebrew first
        center_printf "${FG_BLUE}🔄 Updating Homebrew...${RESET}"
        {
            brew update >/dev/null 2>&1
        } &
        if simple_spinner "Updating package lists" $!; then
            printf "\n"
        else
            center_printf "${FG_YELLOW}⚠️  Update failed, continuing anyway...${RESET}"
            printf "\n"
        fi
        
        # Install each package
        local failed_packages=()
        for pkg in "${missing_packages[@]}"; do
            center_printf "${FG_BLUE}📦 Installing ${BOLD}$pkg${RESET}${FG_BLUE}...${RESET}"
            {
                brew install "$pkg" >/dev/null 2>&1
            } &
            
            if simple_spinner "Installing $pkg" $!; then
                printf "\n"
            else
                failed_packages+=("$pkg")
                printf "\n"
            fi
        done
        
        # Report results
        local successful_count=$((${#missing_packages[@]} - ${#failed_packages[@]}))
        if (( successful_count > 0 )); then
            center_printf "${FG_GREEN}🎉 Successfully installed $successful_count package(s)!${RESET}"
        fi
        
        if (( ${#failed_packages[@]} > 0 )); then
            center_printf "${FG_YELLOW}⚠️  Some packages failed to install: ${failed_packages[*]}${RESET}"
            center_printf "${FG_YELLOW}   Continuing with reduced visuals...${RESET}"
        else
            center_printf "${FG_CYAN}🌟 Enhanced visuals are now available!${RESET}"
        fi
        
        sleep 2
    fi
}

# --- Visual Helper Functions ---
print_header() {
    local title=" $1 "
    local color="${2:-$FG_BLUE}"
    local pad_len=$(( (BOX_WIDTH - ${#title}) / 2 ))
    (( pad_len < 0 )) && pad_len=0
    local padding; padding=$(printf "%${pad_len}s" | tr ' ' '─')
    printf "\n"
    center_printf "%s%s%s%s%s%s%s" "${BOLD}${color}" "$padding" "$title" "$padding" "$( (( (${#title} + pad_len * 2) < BOX_WIDTH )) && printf "─" )" "$RESET"
    printf "\n"
}

print_double_line_header() {
    local title=" $1 "
    local color="${2:-$FG_BLUE}"
    local clean_title; clean_title=$(echo -e "$title" | sed 's/\x1b\[[0-9;]*m//g')
    local title_len=${#clean_title}
    
    printf "\n"
    center_printf "%s%s╔%s╗" "${BOLD}${color}" "$(printf '═%.0s' $(seq 1 $title_len))"
    center_printf "%s%s║%s║" "${BOLD}${color}" "$title"
    center_printf "%s%s╚%s╝%s" "${BOLD}${color}" "$(printf '═%.0s' $(seq 1 $title_len))" "$RESET"
    printf "\n"
}

# --- Box Drawing Functions ---
box_print() {
    local content="$1"
    local clean_content; clean_content=$(echo -e "$content" | sed 's/\x1b\[[0-9;]*m//g')
    local content_len=${#clean_content}
    local padding=$((BOX_WIDTH - 4 - content_len))
    ((padding < 0)) && padding=0
    center_printf "│ %s%*s │" "$content" "$padding" ""
}

box_printf() {
    local format_str="$1"; shift
    local content; content=$(printf "$format_str" "$@")
    box_print "$content"
}

print_box_top() { 
    center_printf "╭%s╮" "$(printf '─%.0s' $(seq 1 $((BOX_WIDTH-2))))"
}

print_box_separator() { 
    center_printf "├%s┤" "$(printf '─%.0s' $(seq 1 $((BOX_WIDTH-2))))"
}

print_box_bottom() { 
    center_printf "╰%s╯" "$(printf '─%.0s' $(seq 1 $((BOX_WIDTH-2))))"
}

box_print_blank() { 
    center_printf "│%*s│" "$((BOX_WIDTH-2))" ""
}

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
    box_print "${left_pad}${BOLD}${FG_YELLOW}${provider_name}${RESET}${right_pad}"
}

generate_latency_bar() {
    local latency_ms="$1"
    ! [[ "$latency_ms" =~ ^[0-9]+(\.[0-9]+)?$ ]] && printf "" && return
    
    local lat_int=${latency_ms%.*}
    local bar_char="■"
    local bar_color
    
    if (( lat_int < 30 )); then 
        bar_color="$FG_GREEN"
    elif (( lat_int < 80 )); then 
        bar_color="$FG_YELLOW"
    else 
        bar_color="$FG_RED"
    fi
    
    # Simple bar - just a few characters based on latency
    local bar_len=1
    if (( lat_int > 50 )); then bar_len=2; fi
    if (( lat_int > 100 )); then bar_len=3; fi
    
    local bar; bar=$(printf "%${bar_len}s" | tr ' ' "$bar_char")
    printf " %s%s%s" "$bar_color" "$bar" "$RESET"
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
        
        printf "\r%*s│   ${FG_CYAN}%s${RESET} %-10s [%s%s] %3d/%-3d" \
            "$CENTER_OFFSET" "" "$spinner_char" "$label" \
            "${FG_GREEN}$(printf "%${filled}s" | tr ' ' "$progress_char")${RESET}" \
            "$(printf "%${empty}s" | tr ' ' "$remaining_char")" \
            "$steps_done" "$total_steps"
        sleep $sleep_interval
    done
    
    printf "\r%*s│   ${FG_GREEN}✔${RESET} %-10s [%s] %3d/%-3d\n" \
        "$CENTER_OFFSET" "" "$label" "$(printf "%${width}s" | tr ' ' "$progress_char")" \
        "$total_steps" "$total_steps"
}

# --- Progress Bar Style Display Function ---
display_progress_bars() {
    if [[ ! -s "$TOP_3_RESULTS" ]]; then
        center_printf "  ${FG_RED}No reachable DNS servers were found during the test.${RESET}"
        return
    fi
    
    # Progress bar visualization
    printf "\n"
    center_printf "${FG_CYAN}${BOLD}📊 DNS PERFORMANCE COMPARISON 📊${RESET}"
    printf "\n"
    center_printf "${FG_BRIGHT_WHITE}Longer bars = Better performance (lower latency)${RESET}"
    printf "\n\n"
    
    # Find max latency for scaling
    local max_lat latencies=()
    while IFS=',' read -r _ _ _ lat; do
        latencies+=("$lat")
    done < "$TOP_3_RESULTS"
    
    # Calculate max latency
    max_lat=$(printf '%s\n' "${latencies[@]}" | sort -n | tail -1)
    max_lat_int=${max_lat%.*}
    
    local rank=1
    while IFS=',' read -r PNAME PIP PLOSS PLAT; do
        local medal color
        case $rank in
            1) medal="🥇" color="$FG_YELLOW" ;;
            2) medal="🥈" color="$FG_WHITE" ;;
            3) medal="🥉" color="$FG_BROWN" ;;
        esac
        
        # Calculate bar length (inverse - shorter latency = longer bar)
        local lat_int=${PLAT%.*}
        local bar_len=$(( 50 - (lat_int * 35 / max_lat_int) ))
        [[ $bar_len -lt 10 ]] && bar_len=10
        [[ $bar_len -gt 45 ]] && bar_len=45
        
        local bar; bar=$(printf "%${bar_len}s" | tr ' ' '█')
        
        # Performance rating based on latency
        local rating
        if (( lat_int < 25 )); then 
            rating="${FG_GREEN}${BOLD}BLAZING FAST${RESET}"
        elif (( lat_int < 40 )); then 
            rating="${FG_YELLOW}${BOLD}VERY FAST${RESET}"
        elif (( lat_int < 60 )); then 
            rating="${FG_ORANGE}${BOLD}FAST${RESET}"
        else 
            rating="${FG_RED}${BOLD}GOOD${RESET}"
        fi
        
        center_printf "%s ${BOLD}%-12s${RESET} %s%s%s ${FG_GREEN}%6sms${RESET} %s" \
            "$medal" "$PNAME" "$color" "$bar" "$RESET" "$PLAT" "$rating"
        
        # Add IP address info underneath with better visibility
        center_printf "    ${FG_CYAN}%s${RESET} - ${FG_WHITE}%s${RESET}" "$PIP" "$(provider_tags "$PNAME")"
        printf "\n"
        
        ((rank++))
    done < "$TOP_3_RESULTS"
    
    # Winner celebration
    local winner_line first_name first_ip first_lat
    winner_line=$(head -n 1 "$TOP_3_RESULTS")
    if [[ -n "$winner_line" ]]; then
        IFS=',' read -r first_name first_ip _ first_lat <<<"$winner_line"
        command -v tput >/dev/null 2>&1 && tput flash
        center_printf "⚡ ${FG_YELLOW}${BOLD}SPEED CHAMPION: %s leads with %sms response time!${RESET} ⚡" "$first_name" "$first_lat"
        center_printf "${FG_GREEN}🏆 Optimal DNS performance achieved! 🏆${RESET}"
        printf "\a"
    fi
    
    printf "\n"
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

# Show system info (neofetch already centers itself)
printf "\n"
if command -v neofetch >/dev/null 2>&1; then
    neofetch
fi

# Display custom banner for the benchmark
if command -v figlet >/dev/null 2>&1 && command -v lolcat >/dev/null 2>&1; then
    figlet -c -w "${TERMINAL_COLS}" -f slant "DNS BENCHMARK" | lolcat
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
        box_printf "    %-9s ${FG_GREEN}✔ OK${RESET}   avg=%-7sms loss=%-3s%% %s ${FG_WHITE}(%s)${RESET}" \
            "Primary" "$avg1" "${loss1:-0}" "$(generate_latency_bar "$avg1")" "$ip1"
        echo "$provider,$ip1,${loss1:-0},$avg1" >> "$TMP_RESULTS"
    else
        box_printf "    %-9s ${FG_RED}✖ UNREACHABLE${RESET}   loss=%-3s%% ${FG_WHITE}(%s)${RESET}" \
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
        box_printf "    %-9s ${FG_GREEN}✔ OK${RESET}   avg=%-7sms loss=%-3s%% %s ${FG_WHITE}(%s)${RESET}" \
            "Secondary" "$avg2" "${loss2:-0}" "$(generate_latency_bar "$avg2")" "$ip2"
        echo "$provider,$ip2,${loss2:-0},$avg2" >> "$TMP_RESULTS"
    else
        box_printf "    %-9s ${FG_RED}✖ UNREACHABLE${RESET}   loss=%-3s%% ${FG_WHITE}(%s)${RESET}" \
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
    figlet -c -w "${TERMINAL_COLS}" -f slant "TOP 3 RESULTS" | lolcat
else
    print_double_line_header "🏆 TOP 3 RESULTS 🏆" "$FG_GREEN"
fi

# Display the progress bar results
display_progress_bars

printf "\n"
