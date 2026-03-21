#!/bin/bash
LOGFILE="{service-path}/_log/handler.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

# Linked components
WEB_SERVICE="emergency-web.service"
NET_CONTROL="{service-path}/handler/network_control.sh"

log() {
  echo "[$TIMESTAMP] [Emergency-AP] $1" >> "$LOGFILE"
}

case "$1" in
  start)
    log "START requested — entering emergency (AP) mode."

    # Bring down normal Wi-Fi and start AP
    sudo $NET_CONTROL down

    # Start web interface
    sudo systemctl start "$WEB_SERVICE"
    log "Emergency AP mode active (Component 3 started)."
    ;;

  stop)
    log "STOP requested — restoring normal network mode."

    # Stop web interface
    sudo systemctl stop "$WEB_SERVICE"

    # Restore normal Wi-Fi, stop AP, restart Avahi
    sudo $NET_CONTROL up

    log "Normal network restored (Component 3 stopped)."
    ;;

  *)
    echo "Usage: $0 {start|stop}" >&2
    exit 1
    ;;
esac
