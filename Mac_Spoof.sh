#!/bin/bash

clear

INTERFACE="wlan0"
OUTPUT_FILE="mac.txt"
EXCLUDE_FILE="exclude.txt"
LIVE_FILE="live.txt"
DNS1="8.8.8.8"
DNS2="8.8.4.4"
GOOGLE_URL="http://www.google.com"

red="\e[31m"
green="\e[32m"
yelo="\e[1;33m"
cyn="\e[36m"
nc="\e[0m"

CHAR_DELAY=0.02

touch "$OUTPUT_FILE"
touch "$EXCLUDE_FILE"
touch "$LIVE_FILE"

disable_ipv6() {
    sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1
    sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1
    sysctl -w net.ipv6.conf.lo.disable_ipv6=1 >/dev/null 2>&1
}

set_dns() {
    echo "nameserver $DNS1" > /etc/resolv.conf
    echo "nameserver $DNS2" >> /etc/resolv.conf
}

check_requirements() {
    if ! command -v arp-scan &> /dev/null; then
        echo "Error: arp-scan is not installed. Please install it to proceed."
        exit 1
    fi

    if ! ip link show "$INTERFACE" &> /dev/null; then
        echo "Error: The interface $INTERFACE does not exist."
        exit 1
    fi
}

loopF() {
    for (( i=0; i<${#text}; i++ )); do
        echo -n "${text:$i:1}"
        sleep "$CHAR_DELAY"
    done
}

banner() {
    text=" [✓] by AhmadAllam"
    loopF
}

mycat() {
    echo -e "${yelo}"
    cat << "caty"
,_     _
 |\_,-~/
 / _  _ |    ,--.
(  @  @ )   / ,-'
 \  _T_/-._( (
 /         `. \
|         _  \ |
 \ \ ,  /      |
  || |-_\__   /
 ((_/`(____,-'
______________________________________
caty
    echo
    banner
    echo
    echo " [✓] DNS :$DNS1"
    echo " [✓] interface :$INTERFACE"
    echo " [✓] Excluded Devices :$EXCLUDE_FILE"
    echo " [✓] Offline Mac File :$OUTPUT_FILE"
    echo " [✓] Online Mac File  :$LIVE_FILE"
    echo "______________________________________"
    echo -e "${nc}"
}

load_exclude_list() {
    if [ -f "$EXCLUDE_FILE" ] && [ -s "$EXCLUDE_FILE" ]; then
        mapfile -t EXCLUDE_LIST < "$EXCLUDE_FILE"
        EXCLUDE_PATTERN=$(IFS=\|; echo "${EXCLUDE_LIST[*]}" | sed 's/ /\\ /g')
    else
        EXCLUDE_PATTERN=""
    fi
}

Get() {
    load_exclude_list
    trap 'echo -e "${red}Scan interrupted, returning to main menu...${nc}"; menu' INT
    local scan_attempt=1
    while true; do
        clear
        echo -e "${green}Starting scan attempt #$scan_attempt...${nc}"
        printf "${cyn}%s${nc}\n" "------------------------------------------"
        printf "${cyn}%-3s | %-25s | %-15s${nc}\n" "#" "Vendor Name" "IP Address"
        printf "${cyn}%s${nc}\n" "------------------------------------------"
        local count=1
        stdbuf -oL arp-scan --interface="$INTERFACE" --localnet | tee /tmp/arp_output.txt | while read -r line; do
            if [[ $line =~ ^[0-9] ]]; then
                ip=$(echo "$line" | awk '{print $1}')
                vendor=$(echo "$line" | awk '{for (i=3; i<=NF; i++) printf "%s ", $i; print ""}' | sed 's/ *$//')
                if [[ -z "$EXCLUDE_PATTERN" || ! $vendor =~ $EXCLUDE_PATTERN ]]; then
                    printf "${yelo}%-3d | %-25s | %-15s${nc}\n" "$count" "$vendor" "$ip"
                else
                    printf "${yelo}%-3d | %-25s | %-15s${nc}\n" "$count" "excluded" "$ip"
                fi
                ((count++))
            fi
        done
        if [ ${PIPESTATUS[0]} -ne 0 ]; then
            echo -e "${red}arp-scan failed, retrying...${nc}"
        else
            cat /tmp/arp_output.txt | awk -v exclude="$EXCLUDE_PATTERN" '
            BEGIN {IGNORECASE = 1}
            /^[0-9]/ {
                vendor = ""
                for (i=3; i<=NF; i++) vendor = vendor $i " "
                sub(/ *$/, "", vendor)
                if (exclude == "" || vendor !~ exclude) {
                    print $2
                }
            }' | while read -r MAC; do
                if [ ! -s "$LIVE_FILE" ] || ! grep -qi "$MAC" "$LIVE_FILE"; then
                    echo "$MAC" >> "$OUTPUT_FILE"
                fi
            done
            sort -u -o "$OUTPUT_FILE" "$OUTPUT_FILE"
        fi
        rm -f /tmp/arp_output.txt
        echo -e "${green}Scan done. MACs saved to $OUTPUT_FILE.${nc}"
        ((scan_attempt++))
        sleep 30
    done
}

Set() {
    local file="$1"
    if [ ! -f "$file" ]; then
        echo "$file does not exist."
        exit 1
    fi
    trap 'echo -e "${red}returning to main menu...${nc}"; return; menu' INT
    local count=1
    printf "${cyn}%s${nc}\n" "------------------------------------------"
    printf "${cyn}%-30s %-10s${nc}\n" "MAC Address" "Status"
    printf "${cyn}%s${nc}\n" "------------------------------------------"
    while IFS= read -r MAC || [[ -n "$MAC" ]]; do
        if [[ $MAC =~ ^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$ ]]; then
            ip link set dev $INTERFACE down
            ip link set dev $INTERFACE address "$MAC"
            ip link set dev $INTERFACE up
            sleep 2
            printf "${yelo}(%d): %-25s${nc}" "$count" "$MAC"
            dhclient -r $INTERFACE > /dev/null 2>&1
            timeout 10 dhclient $INTERFACE > /dev/null 2>&1
            local ip_success=false
            if ip -4 addr show $INTERFACE | grep -q "inet "; then
                ip_success=true
            else
                timeout 5 dhclient $INTERFACE > /dev/null 2>&1
                if ip -4 addr show $INTERFACE | grep -q "inet "; then
                    ip_success=true
                fi
            fi
            local online=false
            if [ "$ip_success" = true ]; then
                timeout 5 curl -s --head "$GOOGLE_URL" | grep -q "200 OK" && online=true
            fi
            if [ "$online" = true ]; then
                printf "\r${yelo}(%d): %-25s${nc} ${green}%-10s${nc}\n" "$count" "$MAC" "Online"
                if ! grep -qi "$MAC" "$LIVE_FILE"; then
                    echo "$MAC" >> "$LIVE_FILE"
                fi
                if [ "$file" != "$LIVE_FILE" ]; then
                    sed -i "/$MAC/d" "$file"
                fi
            elif [ "$ip_success" = true ]; then
                printf "\r${yelo}(%d): %-25s${nc} ${red}%-10s${nc}\n" "$count" "$MAC" "Offline"
                if ! grep -qi "$MAC" "$OUTPUT_FILE"; then
                    echo "$MAC" >> "$OUTPUT_FILE"
                fi
                if [ "$file" == "$LIVE_FILE" ]; then
                    sed -i "/$MAC/d" "$file"
                fi
            else
                printf "\r${yelo}(%d): %-25s${nc} ${red}%-10s${nc}\n" "$count" "$MAC" "IP Failed"
                if ! grep -qi "$MAC" "$OUTPUT_FILE"; then
                    echo "$MAC" >> "$OUTPUT_FILE"
                fi
                if [ "$file" == "$LIVE_FILE" ]; then
                    sed -i "/$MAC/d" "$file"
                fi
            fi
            ip link set dev $INTERFACE down
            ip addr flush dev $INTERFACE
            ip link set dev $INTERFACE up
            ((count++))
            disable_ipv6
        fi
    done < "$file"
    ip link set dev $INTERFACE up
    sort -u -o "$LIVE_FILE" "$LIVE_FILE"
    sort -u -o "$OUTPUT_FILE" "$OUTPUT_FILE"
}

Set2() {
    local file="$1"
    
    local original_mac_list=()
    while IFS= read -r line; do
        if [[ "$line" =~ ^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$ ]]; then
            original_mac_list+=("$line")
        fi
    done < "$file"

    local mac_status=()
    for ((i=0; i<${#original_mac_list[@]}; i++)); do
        mac_status+=("0") 
    done

    redraw_table() {
        clear
        echo -e "$(tput setaf 11)----------------------------------$(tput sgr0)"
        echo -e "$(tput setaf 11)#   | New MAC           | Action        $(tput sgr0)"
        echo -e "$(tput setaf 11)----------------------------------$(tput sgr0)"
        
        local display_index=1
        for i in "${!original_mac_list[@]}"; do
            local mac_to_display="${original_mac_list[$i]}"
            local status="${mac_status[$i]}"
            local current_mac_color_code=$(tput setaf 3)

            if [ "$i" -eq "$current_processing_index_in_loop" ]; then
                current_mac_color_code=$(tput setaf 4)
            fi

            case "$status" in
                "0")
                    echo -e "${current_mac_color_code}$(printf "%-3d | %-17s | %-15s" "$display_index" "$mac_to_display" "Enter to Get me")$(tput sgr0)"
                    ;;
                "1")
                    echo -e "$(tput setaf 3)$(printf "%-3d | %-17s | %s%s%s" "$display_index" "$mac_to_display" "$(tput setaf 2)" "Done" "$(tput sgr0)")$(tput sgr0)"
                    ;;
                "2")
                    echo -e "$(tput setaf 3)$(printf "%-3d | %-17s | %s%s%s" "$display_index" "$mac_to_display" "$(tput setaf 1)" "Skipped" "$(tput sgr0)")$(tput sgr0)"
                    ;;
            esac
            ((display_index++))
        done
    }

    local current_processing_index_in_loop=0
    for MAC in "${original_mac_list[@]}"; do
        redraw_table
        
        echo ""
        echo ""
        
        read -p "$(tput setaf 11)Change MAC to ${MAC}? (Enter/skip): $(tput sgr0)" confirmation
        
        if [ -z "$confirmation" ]; then
            ip link set dev $INTERFACE down >/dev/null 2>&1
            ip link set dev $INTERFACE address "$MAC" >/dev/null 2>&1
            ip link set dev $INTERFACE up >/dev/null 2>&1
            mac_status[$current_processing_index_in_loop]="1"
        else
            mac_status[$current_processing_index_in_loop]="2"
        fi
        
        ((current_processing_index_in_loop++))
    done
    
    ip link set dev $INTERFACE up >/dev/null 2>&1
    redraw_table
    echo -e "$(tput setaf 2)All MACs processed. Returning to main menu.$(tput sgr0)"
    sleep 2
}

change_mac_submenu() {
    local file="$1"
    local mode="$2"
    trap 'echo -e "${red}returning to main menu...${nc}"; menu' INT
    echo -e "${cyn}"
    echo " [1]: Automatic MAC Change"
    echo " [2]: Manual MAC Change"
    echo -e "${nc}"
    printf "${green} [?] Choose mode: ${nc}"
    read -p "" sub_choice
    case $sub_choice in
        1 | 01)
            Set "$file"
            text="All done ✓."
            echo -e "${green}"
            loopF
            echo -e "${nc}"
            ;;
        2 | 02)
            Set2 "$file"
            text="All done ✓."
            echo -e "${green}"
            loopF
            echo -e "${nc}"
            ;;
        *)
            echo -e "${red}Invalid choice, returning to main menu.${nc}"
            ;;
    esac
}

menu() {
    trap 'goodbye' INT
    echo ""
    echo -e " [1]:${cyn}Get Mac from Network${nc} "
    echo -e " [2]:${cyn}Change mac from mac.txt${nc} "
    echo -e " [3]:${cyn}Change mac from live.txt${nc} "
    echo -e " [0]:${cyn}help ${nc} "
    echo ""
    printf "${green} [?] What do you want${nc} : "
    read -p "" entry
    case $entry in
        1 | 01)
            clear
            text="Wait , Scanning for devices on the network"
            echo -e "${green}"
            loopF
            echo -e "${nc}"
            Get
            text="Done ✓ :)"
            echo -e "${green}"
            loopF
            echo -e "${nc}"
            menu
            ;;
        2 | 02)
            clear
            change_mac_submenu "$OUTPUT_FILE" "mac.txt"
            menu
            ;;
        3 | 03)
            clear
            change_mac_submenu "$LIVE_FILE" "live.txt"
            menu
            ;;
        0 | 00)
            clear
            echo -e "${green}"
            text="               ««««<by_AhmadAllam>»»»»"
            loopF
            echo -e "${nc}"
            echo "       Read GitHub readme file to understand"
            echo "                     goodbye ;)  "
            menu
            ;;
        *)
            clear
            echo -e "${red}"
            text="oops, looks like you don't want anything."
            loopF
            echo -e "${nc}"
            menu
            ;;
    esac
}

reset_color() {
    tput sgr0
    tput op
}

goodbye() {
    echo -e "${red}"
    echo " "
    text=" thanks & goodbye."
    loopF
    echo -e "${nc}"
    reset_color
    exit
}

trap goodbye INT

mycat
set_dns
check_requirements
menu
