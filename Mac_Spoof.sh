#!/bin/bash

clear

# Configuration Variables
INTERFACE="wlan0"
OUTPUT_FILE="mac.txt"
EXCLUDE_FILE="exclude.txt"
LIVE_FILE="live.txt"
DNS1="8.8.8.8"
DNS2="8.8.4.4"
GOOGLE_URL="http://www.google.com"

# Color Variables
red="\e[31m"
green="\e[32m"
yelo="\e[1;33m"
cyn="\e[36m"
nc="\e[0m"

# Timing Variables
CHAR_DELAY=0.02
MAC_CHANGE_DELAY=10

# necessary files
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

mycat() {
    echo -e "${yelo}"
    cat << "caty"
,_     _
 |\\_,-~/
 / _  _ |    ,--.
(  @  @ )   / ,-'
 \  _T_/-._( (
 /         `. \
|         _  \ |
 \ \ ,  /      |
  || |-_\__   /
 ((_/`(____,-'
_____________________
caty
}

banner() {
    text="spoof mac address include internet by "
    loopF
    printf "${nc}@AhmadAllam${nc}"
}

load_exclude_list() {
    if [ -f "$EXCLUDE_FILE" ]; then
        mapfile -t EXCLUDE_LIST < "$EXCLUDE_FILE"
        EXCLUDE_PATTERN=$(IFS=\|; echo "${EXCLUDE_LIST[*]}")
    else
        echo "Exclude file not found. Proceeding without exclusions."
        EXCLUDE_PATTERN=""
    fi
}

Get() {
    load_exclude_list
    arp-scan --interface="$INTERFACE" --localnet | awk -v exclude="$EXCLUDE_PATTERN" '
    BEGIN {IGNORECASE = 1}
    /^[0-9]/ {
        if ($3 !~ exclude) {
            print $2
        }
    }' | while read -r MAC; do
        if ! grep -qi "$MAC" "$LIVE_FILE"; then
            echo "$MAC" >> "$OUTPUT_FILE"
        fi
    done
    sort -u -o "$OUTPUT_FILE" "$OUTPUT_FILE"
}

Set() {
    local file="$1"
    if [ ! -f "$file" ]; then
        echo "$file does not exist."
        exit 1
    fi

    while IFS= read -r MAC; do
        ip link set dev $INTERFACE down
        ip link set dev $INTERFACE address "$MAC"
        ip link set dev $INTERFACE up

        sleep "$MAC_CHANGE_DELAY"
        disable_ipv6
        if curl -s --head "$GOOGLE_URL" | grep "200 OK" > /dev/null; then
            echo -e "${green}Good $MAC allows internet access.${nc}"
            echo "$MAC" >> "$LIVE_FILE"
            sed -i "/$MAC/d" "$file"
        else
            echo "Sorry $MAC no internet access."
        fi

        ip link set dev $INTERFACE down
    done < "$file"

    ip link set dev $INTERFACE up
}

Set2() {
    for MAC in $(cat "$LIVE_FILE"); do
        if [[ $MAC =~ ^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$ ]]; then
            echo -e "${yelo}Press Enter to change to $MAC...${nc}"
            read confirmation
            if [ -z "$confirmation" ]; then
                ip link set dev $INTERFACE down
                ip link set dev $INTERFACE address "$MAC"
                ip link set dev $INTERFACE up
                echo -e "MAC changed to $MAC"
            fi
        fi
    done
    ip link set dev $INTERFACE up
}

menu() {
    echo ""
    echo -e " [1]:${cyn}Get Mac${nc} "
    echo -e " [2]:${cyn}Set Mac (from mac.txt)${nc} "
    echo -e " [3]:${cyn}Set Mac (from live.txt)${nc} "
    echo -e " [0]:${cyn}help ${nc} "
    echo ""

    printf "${yelo}What do you want${nc} : "
    read -p "" entry

    case $entry in
        1 | 01)
            clear
            text="Wait , Scanning for devices on the network"
            echo -e "${green}"
            loopF
            echo -e "${nc}"
            Get
            text="Done ✓ now try Set options to change your mac :)"
            echo -e "${green}"
            loopF
            echo -e "${nc}"
            menu
            ;;
        2 | 02)
            clear
            text="Wait , Connect to your WI-FI If you see (Saved)"
            echo -e "${green}"
            loopF
            echo -e "${nc}"
            Set "$OUTPUT_FILE"
            text="All done ✓."
            echo -e "${green}"
            loopF
            echo -e "${nc}"
            menu
            ;;
        3 | 03)
            clear
            Set2
            echo -e "${green}"
            text="Finished processing MACs from live.txt"
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
    text="thanks & goodbye."
    loopF
    echo -e "${nc}"
    reset_color
    exit
}

trap goodbye INT

# Main Execution
mycat
banner
set_dns
check_requirements
menu