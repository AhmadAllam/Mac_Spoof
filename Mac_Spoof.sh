#!/bin/bash
clear
#Variables 
INTERFACE="wlan0"
OUTPUT_FILE="mac.txt"

# Check if arp-scan is installed
if ! command -v arp-scan &> /dev/null; then
    echo "Error: arp-scan is not installed. Please install it to proceed."
    exit 1
fi

# Check if the specified interface exists
if ! ip link show "$INTERFACE" &> /dev/null; then
    echo "Error: The interface $INTERFACE does not exist."
    exit 1
fi

#colors
red="\e[31m"
green="\e[32m"
yelo="\e[1;33m"
cyn="\e[36m"
nc="\e[0m"

#function_loop
loopS () {
for (( i=0; i<${#text}; i++ )); do
    echo -n "${text:$i:1}"
    sleep 0.04
done
}

loopF () {
for (( i=0; i<${#text}; i++ )); do
    echo -n "${text:$i:1}"
    sleep 0.02
done
}
#function_my cat
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

#function_banner
banner () {
text="spoof mac address include internet by "
loopF
printf "${nc}@AhmadAllam${nc}"
}


#function_menu
menu () {
echo ""
echo ""
echo -e " [1]:${cyn}Get Mac${nc} "
echo -e " [2]:${cyn}Set Mac${nc} "
echo -e " [0]:${cyn}help ${nc} "
echo -e ""
echo ""

#choice
printf "${yelo}What do you want${nc} : "
read -p "" entry

#function_Get
Get () {
# Run arp-scan and filter the output
arp-scan --interface="$INTERFACE" --localnet | awk '/^[0-9]/ { 
    if ($3 !~ /Ubiquiti/ && 
        $3 !~ /TP-Link/ && 
        $3 !~ /D-Link/ && 
        $3 !~ /Netgear/ && 
        $3 !~ /Cisco/ && 
        $3 !~ /Linksys/ && 
        $3 !~ /Asus/ && 
        $3 !~ /Zyxel/ && 
        $3 !~ /Belkin/ && 
        $3 !~ /ZTE/) 
    { 
        print $2 
    } 
}' | tee "$OUTPUT_FILE"

echo " "
}

#function_Set
Set () {
if [ ! -f "mac.txt" ]; then
    echo "mac.txt does not exist."
    exit 1
fi

while IFS= read -r MAC; do
    ip link set dev $INTERFACE down
    ip link set dev $INTERFACE address "$MAC"
    ip link set dev $INTERFACE up

    sleep 7

    if curl -s --head http://www.google.com | grep "200 OK" > /dev/null; then
        echo "Good $MAC allows internet access."
        break
    else
        echo "Sorry $MAC no internet access."
    fi

    ip link set dev $INTERFACE down
done < "mac.txt"

ip link set dev $INTERFACE up
echo " "
echo "Finished processing all MAC addresses."
echo " "
}

#cases
case $entry in
	  1 | 01)
	  clear
      text="Wait , Scanning for devices on the network"
      echo -e "${green} "
      loopF
      echo -e "${nc} "
      echo " "
      Get
      text="Done ✓ now try Set option to change the mac :) "
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
      Set
      text="Congratulations ✓ interesting with internet:) "
      echo -e "${green} "
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

#function_reset
reset_color() {
	tput sgr0   # reset attributes
	tput op     # reset color
}

#function_goodbye
goodbye () {
echo -e "${red} "
      text="thanks & goodbye."
      loopF
      echo -e "${nc} "
      reset_color
      exit
}
trap goodbye INT

##call functions
mycat
banner
menu