# MAC Spoofing for Android

## Overview

This script allows changing the MAC address on Android devices using Nethunter. By changing your MAC address, you can access free internet from devices connected to the same network.

## Description

This script modifies your MAC address to mimic the addresses of other devices connected to your Wi-Fi network, providing a means to gain internet access.

## Dependencies

- Xposed Module (MacSposed) to allow script change mac

## Installing & Executing

1. Install the necessary dependencies:
   ```bash
   apt install net-tools
   ```
2. Navigate to the script directory:
   ```bash
   cd /Mac_Spoof
   ```
3. Change file permissions:
   ```bash
   chmod +x *
   ```
4. Execute the script:
   ```bash
   ./Mac_Spoof.sh
   ```

## Help Commands

- **[1]: Get Mac**
  - Scan the local network to retrieve the addresses of all connected devices except those listed in `exclude.txt`.

- **[2]: Set Mac (from mac.txt)**
  - Change your MAC address to an address from `mac.txt`, which contains all the addresses that were retrieved.

- **[3]: Set Mac (from live.txt)**
  - Change your MAC address to one from `live.txt`, which contains addresses that have internet access.

- **[0]: About & Help**
  - Display help information and credits.
  - To exit , press **CTRL + C**.

## Authors

- **Dev. Ahmad Allam**
  - My account: [Telegram](https://t.me/echo_Allam)
  - Don't forget Palestine ❤️
