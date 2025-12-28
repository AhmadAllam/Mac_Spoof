# MAC Spoofing for Android

## Overview

This script allows changing the MAC address on Android devices using Nethunter. By changing your MAC address, you can access free internet from devices connected to the same network (by mimicking allowed devices).

## Description

This script modifies your MAC address to mimic the addresses of other devices connected to your Wi-Fi network. It includes features to scan the network for targets, automatically test MAC addresses for internet connectivity, and manually switch between addresses.

## Dependencies

- Macsposed app:an Xposed Module Required to allow the script to change the MAC address.
- Tasker App: Recommended to ensure the Wi-Fi connection stays active continuously.

## Installing & Executing

1.  **Install the necessary dependencies**:
    ```bash
    apt update
    apt install arp-scan curl -y
    ```
    *(Note: Ensure you are running as root)*

2.  **Navigate to the script directory**:
    ```bash
    cd /Mac_Spoof
    ```

3.  **Change file permissions** (to ensure the script is executable):
    ```bash
    chmod +x *
    ```

4.  **Execute the script**:
    ```bash
    ./Mac_Spoof.sh
    ```

## Menu Options & Usage

The script provides an interactive menu with the following options:

### [1] Get Mac from Network
Scans the local Wi-Fi network to discover connected devices.
- **Output**: Saves discovered MAC addresses to `mac.txt`.
- **Exclusion**: Vendors listed in `exclude.txt` (e.g., "TP-Link", "Ubiquiti") are ignored to filter out routers/gateways.

### [2] Auto Check Status (mac.txt)
Automatically iterates through the MAC addresses saved in `mac.txt`.
- **Process**: Sets your MAC, waits for an IP connection, and checks for internet access (using `curl`).
- **Result**:
    - **Online**: If internet is found, the MAC is moved to `live.txt`.
    - **Offline**: If no internet, it is saved back to `mac.txt` (offline list).

### [3] Auto Check Status (live.txt)
Performs the same automatic check as Option [2], but iterates through `live.txt`.
- Useful for re-verifying previously working MAC addresses.

### [4] Manual Check Status (mac.txt)
Allows you to manually step through the MAC addresses in `mac.txt`.
- **Interaction**: Displays each MAC and asks for confirmation.
- **Action**: Press **Enter** to switch to the displayed MAC, or type any character to skip it.

### [5] Manual Check Status (live.txt)
Same as Option [4], but iterates manually through `live.txt`.

### [6] Loop & Switch Manually (switch.txt)
A special mode that loops continuously between the MAC addresses found in the first two lines of `switch.txt`.
- **Usage**: Useful for quickly toggling between two specific known MACs.
- **Interaction**: Press **Enter** to switch to the current MAC in the loop, or type to skip.

### [0] Help / Exit
- Displays help information.
- **Exit**: Press **CTRL + C** to terminate the script at any time.

## Files

- **Mac_Spoof.sh**: The main script.
- **mac.txt**: Storage for MAC addresses found during scanning.
- **live.txt**: Storage for MAC addresses confirmed to have internet access.
- **exclude.txt**: List of keywords (Vendor names) to exclude during the network scan.
- **switch.txt**: Contains specific MAC addresses for the Loop & Switch mode (Option 6).

## Authors

- **Dev. Ahmad Allam**
  - Telegram: [echo_tester](https://t.me/echo_tester)
  - Don't forget Palestine ❤️
