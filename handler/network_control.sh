#!/bin/bash
# Root-owned wrapper — handles Wi-Fi toggle, AP services, Avahi

LOGFILE="{service-path}/_log/handler.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

HOSTAPD_CONF="/etc/emergency_ap/hostapd.conf"
DNSMASQ_CONF="/etc/emergency_ap/dnsmasq.conf"

log() {
    echo "[$TIMESTAMP] [Network-Control] $1" >> "$LOGFILE"
}

case "$1" in
  down)
    log "Bringing normal Wi-Fi down and starting AP."

    # Stop normal Wi-Fi
    systemctl stop wpa_supplicant.service
    systemctl stop dhcpcd.service
    ip link set wlan0 down
    ip addr flush dev wlan0

    # Assign AP static IP
    ip addr add 192.168.50.1/24 dev wlan0
    ip link set wlan0 up

    # Start AP services
    hostapd -B "$HOSTAPD_CONF"
    dnsmasq -C "$DNSMASQ_CONF"

    log "AP mode active."
    ;;

  up)
    log "Stopping AP and restoring normal Wi-Fi."

    # Stop AP services
    pkill hostapd
    pkill dnsmasq

    # Restore normal Wi-Fi
    ip link set wlan0 down
    ip addr flush dev wlan0
    ip link set wlan0 up
    systemctl start dhcpcd.service
    systemctl start wpa_supplicant.service

    # Restart Avahi for mDNS
    systemctl restart avahi-daemon.service

    log "Normal Wi-Fi restored and Avahi restarted."
    ;;

  *)
    echo "Usage: $0 {up|down}" >&2
    exit 1
    ;;
esac