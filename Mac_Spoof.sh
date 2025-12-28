#!/bin/bash

clear

INTERFACE="wlan0"
OUTPUT_FILE="mac.txt"
EXCLUDE_FILE="exclude.txt"
LIVE_FILE="live.txt"
SWITCH_FILE="switch.txt"
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
touch "$SWITCH_FILE"

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
    
    if ! command -v curl &> /dev/null; then
        echo "Error: curl is not installed. Please install it to proceed."
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
    echo " [✓] Live Mac File  :$LIVE_FILE"
    echo " [✓] Switch Mac File  :$SWITCH_FILE"
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
                
                # Truncate vendor name to 25 characters if it's longer
                if [ ${#vendor} -gt 25 ]; then
                    vendor="${vendor:0:22}..."
                fi

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
    
    printf "${cyn}%s${nc}\n" "----------------------------------------------------"
    printf "${cyn}%-18s | %-15s | %-10s${nc}\n" "MAC" "IP" "Status"
    printf "${cyn}%s${nc}\n" "----------------------------------------------------"
    
    while IFS= read -r MAC || [[ -n "$MAC" ]]; do
        if [[ $MAC =~ ^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$ ]]; then
            
            local current_ip="N/A"
            local status_text="Offline"
            local status_color="${red}"
            local temp_mac="$MAC"
            
            printf "\r${yelo}%-18s${nc} | %-15s | %-10s" "$temp_mac" "Checking..." ""
            ip link set dev "$INTERFACE" down >/dev/null 2>&1
            ip link set dev "$INTERFACE" address "$MAC" >/dev/null 2>&1
            ip link set dev "$INTERFACE" up >/dev/null 2>&1
            
            sleep 5

            local ip_wait_time=0
            while [ $ip_wait_time -lt 10 ]; do
                current_ip=$(ip a show "$INTERFACE" | grep "inet " | awk '{print $2}' | cut -d'/' -f1)
                if [ -n "$current_ip" ]; then
                    printf "\r${yelo}%-18s${nc} | ${yelo}%-15s${nc} | %-10s" "$temp_mac" "$current_ip" "Checking..."
                    break
                fi
                sleep 1
                ((ip_wait_time++))
            done

            local online=false
            if [ "$current_ip" != "N/A" ]; then
                
                local curl_wait_time=0
                while [ $curl_wait_time -lt 5 ]; do
                    if curl -s --head --connect-timeout 5 "$GOOGLE_URL" | grep -q "200 OK"; then
                        online=true
                        break
                    fi
                    sleep 1
                    ((curl_wait_time++))
                done
            fi

            if [ "$online" = true ]; then
                status_color="${green}"
                status_text="Online"
                if ! grep -qi "$MAC" "$LIVE_FILE"; then
                    echo "$MAC" >> "$LIVE_FILE"
                fi
                if [ "$file" != "$LIVE_FILE" ]; then 
                    sed -i "/$MAC/d" "$file"
                fi
            else
                status_color="${red}"
                status_text="Offline"
                if ! grep -qi "$MAC" "$OUTPUT_FILE"; then
                    echo "$MAC" >> "$OUTPUT_FILE"
                fi
                if [ "$file" == "$LIVE_FILE" ]; then 
                    sed -i "/$MAC/d" "$file"
                fi
            fi
            
            printf "\r${yelo}%-18s${nc} | ${yelo}%-15s${nc} | ${status_color}%-10s${nc}\n" "$temp_mac" "$current_ip" "$status_text"
        fi
    done < "$file"
    
    ip link set dev "$INTERFACE" up >/dev/null 2>&1
    
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

    clear
    echo -e "$(tput setaf 11)----------------------------------$(tput sgr0)"
    echo -e "$(tput setaf 11)#   | New MAC           | Action        $(tput sgr0)"
    echo -e "$(tput setaf 11)----------------------------------$(tput sgr0)"
    
    local display_index=1
    for MAC in "${original_mac_list[@]}"; do
        printf "$(tput setaf 3)%-3d | %-17s | $(tput sgr0)" "$display_index" "$MAC"
        
        read -p "$(tput setaf 11)Enter to Get me: $(tput sgr0)" confirmation
        
        tput cuu1
        tput el
        
        if [ -z "$confirmation" ]; then
            ip link set dev $INTERFACE down >/dev/null 2>&1
            ip link set dev $INTERFACE address "$MAC" >/dev/null 2>&1
            ip link set dev $INTERFACE up >/dev/null 2>&1
            echo -e "$(tput setaf 3)$(printf "%-3d | %-17s | %s" "$display_index" "$MAC" "$(tput setaf 2)Done")$(tput sgr0)"
        else
            echo -e "$(tput setaf 3)$(printf "%-3d | %-17s | %s" "$display_index" "$MAC" "$(tput setaf 1)Skipped")$(tput sgr0)"
        fi
        
        ((display_index++))
    done
    
    ip link set dev $INTERFACE up >/dev/null 2>&1
    echo -e "$(tput setaf 2)All MACs processed. Returning to main menu.$(tput sgr0)"
    sleep 2
}

Set_Switch_Loop() {
    local file="$1"
    
    if [ ! -f "$file" ]; then
        echo -e "${red}Error: The file $file does not exist. Please create it.${nc}"
        sleep 2
        return
    fi
    
    local original_mac_list=()
    while IFS= read -r line; do
        if [[ "$line" =~ ^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$ ]]; then
            original_mac_list+=("$line")
        fi
    done < <(head -n 2 "$file")

    if [ ${#original_mac_list[@]} -eq 0 ]; then
        echo -e "${red}Error: No valid MAC addresses found in the first two lines of $file. Please check the file content.${nc}"
        sleep 2
        return
    fi

    while true; do
        clear
        echo -e "$(tput setaf 11)----------------------------------$(tput sgr0)"
        echo -e "$(tput setaf 11)#   | New MAC           | Action        $(tput sgr0)"
        echo -e "$(tput setaf 11)----------------------------------$(tput sgr0)"

        local display_index=1
        for MAC in "${original_mac_list[@]}"; do
            printf "$(tput setaf 3)%-3d | %-17s | $(tput sgr0)" "$display_index" "$MAC"
            
            read -p "$(tput setaf 11)Enter to Get me: $(tput sgr0)" confirmation
            
            tput cuu1
            tput el
            
            if [ -z "$confirmation" ]; then
                ip link set dev $INTERFACE down >/dev/null 2>&1
                ip link set dev $INTERFACE address "$MAC" >/dev/null 2>&1
                ip link set dev $INTERFACE up >/dev/null 2>&1
                echo -e "$(tput setaf 3)$(printf "%-3d | %-17s | %s" "$display_index" "$MAC" "$(tput setaf 2)Done")$(tput sgr0)"
            else
                echo -e "$(tput setaf 3)$(printf "%-3d | %-17s | %s" "$display_index" "$MAC" "$(tput setaf 1)Skipped")$(tput sgr0)"
            fi
            
            ((display_index++))
        done
        ip link set dev $INTERFACE up >/dev/null 2>&1
        sleep 1
    done
}

menu() {
    trap 'goodbye' INT
    echo ""
    echo -e " [1]:${cyn}Get all Mac from Network${nc} "
    echo -e " [2]:${cyn}Auto Check Status (mac.txt)${nc} "
    echo -e " [3]:${cyn}Auto Check Status (live.txt)${nc} "
    echo -e " [4]:${cyn}Manual Check Status (mac.txt)${nc} "
    echo -e " [5]:${cyn}Manual Check Status (live.txt)${nc} "
    echo -e " [6]:${cyn}Loop & Switch Manually (switch.txt)${nc} "
    echo -e " [0]:${cyn}help ${nc} "
    echo ""
    printf "${green} [?] What do you want${nc} : "
    read -p "" entry
    case $entry in
        1 | 01)
            clear
            text="Wait, Scanning for devices on the network"
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
            Set "$OUTPUT_FILE"
            text="All done ✓."
            echo -e "${green}"
            loopF
            echo -e "${nc}"
            menu
            ;;
        3 | 03)
            clear
            Set "$LIVE_FILE"
            text="All done ✓."
            echo -e "${green}"
            loopF
            echo -e "${nc}"
            menu
            ;;
        4 | 04)
            clear
            Set2 "$OUTPUT_FILE"
            text="All done ✓."
            echo -e "${green}"
            loopF
            echo -e "${nc}"
            menu
            ;;
        5 | 05)
            clear
            Set2 "$LIVE_FILE"
            text="All done ✓."
            echo -e "${green}"
            loopF
            echo -e "${nc}"
            menu
            ;;
        6 | 06)
            clear
            Set_Switch_Loop "$SWITCH_FILE"
            text="Swiching loop ended."
            echo -e "${green}"
            loopF
            echo -e "${nc}"
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
            text="Oops, looks like you don't want anything."
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
    text=" Thanks & goodbye."
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
