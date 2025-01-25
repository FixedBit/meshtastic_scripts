# Waveshare LoRa HAT and Meshtastic Setup Scripts

This project contains a collection of scripts designed to streamline the setup and configuration of the Waveshare LoRaWAN/GNSS HAT and Meshtastic on Raspberry Pi devices.

## Features
- Automated setup for the Waveshare LoRaWAN/GNSS HAT with SPI and I2C configuration.
- Easy installation and update of Meshtastic CLI and Meshtasticd service.
- Backup and restore of Meshtastic configurations.
- Support for multiple architectures: `amd64`, `arm64`, `armhf`.
- Example configuration file for customizing your setup.
- `ncmesh_connect.sh` to easily set up and configure Meshtastic devices for the NC Mesh network.

---

## Table of Contents
1. [Requirements](#requirements)
2. [Setup Instructions](#setup-instructions)
   - [Raspberry Pi LoRa HAT Configuration](#raspberry-pi-lora-hat-configuration)
   - [Meshtastic Setup](#meshtastic-setup)
   - [NC Mesh Device Configuration](#nc-mesh-device-configuration)
3. [Example Configuration](#example-configuration)
4. [Credits](#credits)

---

## Requirements
### Hardware
- Raspberry Pi (any model supported by Meshtastic and Waveshare LoRa HAT).
- Waveshare SX1262 XXXM LoRaWAN/GNSS HAT ([Product Page](https://www.waveshare.com/wiki/SX1262_XXXM_LoRaWAN/GNSS_HAT)).

### Software
- Raspberry Pi OS or another Debian-based Linux distribution.
- `bash` shell for running scripts.

---

## Setup Instructions

### Raspberry Pi LoRa HAT Configuration
To configure the LoRa HAT, run the following one-liner command:
```bash
curl -sL https://raw.githubusercontent.com/FixedBit/meshtastic_scripts/refs/heads/main/lora_hat_setup.sh -o /tmp/lora_hat_setup.sh; sudo bash /tmp/lora_hat_setup.sh; rm /tmp/lora_hat_setup.sh
```
- This script will enable SPI and I2C, configure the necessary device overlays, and ensure your Raspberry Pi is ready for the LoRaWAN/GNSS HAT.
- The script will prompt for a reboot to apply changes.

---

### Meshtastic Setup
To install or update Meshtastic CLI and Meshtasticd, run the following command:
```bash
curl -sL https://raw.githubusercontent.com/FixedBit/meshtastic_scripts/refs/heads/main/meshtastic_setup.sh -o /tmp/meshtastic_setup.sh; sudo bash /tmp/meshtastic_setup.sh; rm /tmp/meshtastic_setup.sh
```
- The script will:
  - Check and install required dependencies.
  - Set up a Python virtual environment for the Meshtastic CLI.
  - Install or update the `meshtasticd` service.
  - Back up existing Meshtastic configurations.
  - Start and optionally enable the Meshtasticd service.

---

### NC Mesh Device Configuration
To configure a device for the NC Mesh network, run the following command:
```bash
curl -sL https://raw.githubusercontent.com/FixedBit/meshtastic_scripts/refs/heads/main/ncmesh_connect.sh -o /tmp/ncmesh_connect.sh; sudo bash /tmp/ncmesh_connect.sh; rm /tmp/ncmesh_connect.sh
```
- This script will:
  - Prompt for the device owner name and short name.
  - Allow selection of the device mode (Client, Router, etc.).
  - Configure LoRa, GPS, MQTT, and channel settings specific to the NC Mesh network.

---

## Example Configuration
This is an example configuration file for the Waveshare LoRaWAN/GNSS HAT that I am using on my Pi.

1. Download the example configuration:
   ```bash
   curl -sL https://raw.githubusercontent.com/FixedBit/meshtastic_scripts/refs/heads/main/example_config/config.yaml | sudo tee /etc/meshtasticd/config.yaml > /dev/null
   ```

2. Edit the file to suit your setup:
   ```bash
   sudo nano /etc/meshtasticd/config.yaml
   ```

3. Restart the Meshtasticd service:
   ```bash
   sudo systemctl restart meshtasticd
   ```

NOTE: To check on what the service is doing, you can verify with this command to follow the service output:
```bash
journalctl -u meshtasticd -b
```

---

## Credits
- **Author**: Jason Hawks  
  - Website: [FixedBit Technologies](https://fixedbit.com)  
  - Discord: `fixedbit`

- **Shoutout**: North Carolina Meshtastic Community  
  - Website: [NCMesh](https://ncmesh.net)  
  - Discord: [Join Here](https://discord.gg/xUzRAjHZk8)

---

Happy Meshing! 🌐