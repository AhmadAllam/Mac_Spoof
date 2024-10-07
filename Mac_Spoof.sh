#!/bin/bash
clear
INTERFACE="wlan0"
OUTPUT_FILE="mac.txt"
EXCLUDE_FILE="exclude.txt"
touch live.txt

disable_ipv6() {
    sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1
    sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1
    sysctl -w net.ipv6.conf.lo.disable_ipv6=1 >/dev/null 2>&1
}

set_dns() {
    echo "nameserver 8.8.8.8" > /etc/resolv.conf
    echo "nameserver 8.8.4.4" >> /etc/resolv.conf
}

if ! command -v arp-scan &> /dev/null; then
    echo "Error: arp-scan is not installed. Please install it to proceed."
    exit 1
fi

if ! ip link show "$INTERFACE" &> /dev/null; then
    echo "Error: The interface $INTERFACE does not exist."
    exit 1
fi

red="\e[31m"
green="\e[32m"
yelo="\e[1;33m"
cyn="\e[36m"
nc="\e[0m"

loopF () {
    for (( i=0; i<${#text}; i++ )); do
        echo -n "${text:$i:1}"
        sleep 0.02
    done
}

mycat () {
    echo -e "${yelo} "
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

banner () {
    text="spoof mac address include internet by "
    loopF
    printf "${nc}@AhmadAllam${nc}"
}

load_exclude_list() {
    if [ -f "$EXCLUDE_FILE" ]; then
        mapfile -t EXCLUDE_LIST < "$EXCLUDE_FILE"
        EXCLUDE_PATTERN=$(IFS=\|; echo "${EXCLUDE_LIST[*]}")
    else
        echo " "
        echo "Exclude file not found. Proceeding without exclusions."
        echo " "
        EXCLUDE_PATTERN=""
    fi
}

Get() {
    load_exclude_list
    arp-scan --interface="$INTERFACE" --localnet | awk -v exclude="$EXCLUDE_PATTERN" '
    BEGIN {IGNORECASE = 1}
    /^[0-9]/ {
        if ($3 !~ exclude)
        { 
            print $2 
        } 
    }' | while read -r MAC; do
        if ! grep -qi "$MAC" live.txt; then
            echo "$MAC" >> "$OUTPUT_FILE"
        fi
    done
    sort -u -o "$OUTPUT_FILE" "$OUTPUT_FILE"
    echo " "
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
        
        sleep 10
        disable_ipv6
        if curl -s --head http://www.google.com | grep "200 OK" > /dev/null; then
            echo -e "${green}Good $MAC allows internet access.${nc}"
            echo "$MAC" >> live.txt
            sed -i "/$MAC/d" "$file"
        else
            echo "Sorry $MAC no internet access."
        fi

        ip link set dev $INTERFACE down
    done < "$file"

    ip link set dev $INTERFACE up
    echo " "
    echo "Finished processing all MAC addresses from $file."
    echo " "
}

Set2() {
    for MAC in $(cat live.txt); do
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
    echo " "
}


menu () {
    echo ""
    echo ""
    echo -e " [1]:${cyn}Get Mac${nc} "
    echo -e " [2]:${cyn}Set Mac (from mac.txt)${nc} "
    echo -e " [3]:${cyn}Set Mac (from live.txt)${nc} "
    echo -e " [0]:${cyn}help ${nc} "
    echo -e ""
    echo ""

    printf "${yelo}What do you want${nc} : "
    read -p "" entry

    case $entry in
      1 | 01)
      clear
      text="Wait , Scanning for devices on the network"
      echo -e "${green} "
      loopF
      echo -e "${nc} "
      echo " "
      Get
      text="Done ✓ now try Set options to change your mac :) "
      echo -e "${green} "
      loopF
      echo -e "${nc} "
      echo " "
      menu
      ;;
      
      2 | 02)
      clear
      text="Wait , Connect to your WI-FI If you see (Saved)"
      echo -e "${green} "
      loopF
      echo -e "${nc} "
      echo " "
      Set "mac.txt"
      text="All done ✓."
      echo -e "${green} "
      loopF
      echo -e "${nc} "
      echo " "
      menu
      ;;
      
      3 | 03)
      clear
      Set2
      echo -e "${green} "
      text="Finished processing MACs from live.txt"
      loopF
      echo -e "${nc} "
      echo " "
      menu
      ;;

      0 | 00)
      clear
      echo -e "${green} "
      text="               ««««<by_AhmadAllam>»»»»"
      loopF
      echo -e "${nc} "
      echo "       Read GitHub readme file to understand  "
      echo "                     goodbye ;)  "
      
      printf "\n \n \n \n"
      menu
      ;;
     
      *)
      clear
      echo -e "${red} "
      text="oops, looks like you don't want anything."
      loopF
      echo -e "${nc} "
      menu
      ;;
    esac
}

reset_color() {
    tput sgr0
    tput op
}

goodbye () {
    echo -e "${red} "
    text="thanks & goodbye."
    loopF
    echo -e "${nc} "
    reset_color
    exit
}
trap goodbye INT

mycat
banner
set_dns
menu