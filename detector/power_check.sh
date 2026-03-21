#!/bin/bash
LOG_FILE="{service-path}/_log/handler.log"
STATE_FILE="{service-path}/detector/state"
AP_SERVICE="emergency-handler.service"
CONFIRM_RETRIES=3                                           # how many confirmation retries after first failure
CONFIRM_DELAY=10                                            # seconds between confirmation pings
OUTAGE_LIMIT=5                                              # number of timer cycles before trying to return to normal
ROUTER_IP="$(ip route show default | awk '{ print $3 }')"   # Router gateway

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [Detector]  $1" >> "$LOG_FILE"
}

check_router() {
    ping -c1 -W2 "$ROUTER_IP" >/dev/null 2>&1
    return $?
}

confirm_outage() {
    for ((i=1; i<=CONFIRM_RETRIES; i++)); do
        sleep "$CONFIRM_DELAY"
        if check_router; then
            return 1
        fi
    done
    return 0
}

get_state() {
    if [ -f "$STATE_FILE" ]; then
        cat "$STATE_FILE"
    else
        echo "normal 0"
    fi
}

set_state() {
    echo "$1" > "$STATE_FILE"
}

main() {
    # Read previous state and counter
    local prev_state
    local counter
    read prev_state counter < <(get_state)

    # Ensure defaults
    [ -z "$prev_state" ] && prev_state="normal"
    [ -z "$counter" ] && counter=0

    local new_state="$prev_state"
    local new_counter="$counter"

    if [ "$prev_state" = "normal" ]; then
        # Ping. if ok, nothing. if not, check outage

        if check_router; then
            new_state="normal"
            new_counter=0
        else
            log "Initial ping failed. Verifying outage..."
            if confirm_outage; then # contains loop with retries
                log "Confirmed outage — starting AP mode."
                sudo systemctl start "$AP_SERVICE"
                new_state="outage"
                new_counter=0
            else
                log "Outage not confirmed — no action taken."
            fi
        fi
    else #outage
        # Increment counter. if counter reaches limit, go back to normal
        new_counter=$((counter + 1))
        log "Outage tick $new_counter/$OUTAGE_LIMIT"

        if [ "$new_counter" -ge "$OUTAGE_LIMIT" ]; then
            log "Outage duration expired — stopping AP mode and testing router again."
            sudo systemctl stop "$AP_SERVICE"
            new_state="normal"
            new_counter=0
        fi
    fi

    # Update state file if changed
    if [ "$new_state" != "$prev_state" ] || [ "$new_counter" != "$counter" ]; then
        set_state "$new_state $new_counter"
    fi
}

main
