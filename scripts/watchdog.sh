#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PID_FILE="$PROJECT_DIR/.watchdog.pid"
STATUS_FILE="$PROJECT_DIR/.proxy-status"
API="http://127.0.0.1:9090"

CHECK_INTERVAL=30
FAIL_THRESHOLD=3
TEST_URL="https://www.gstatic.com/generate_204"
PROXY="http://127.0.0.1:7890"

log_info()  { echo "[WATCHDOG] $*"; }
log_ok()    { echo "[WATCHDOG-OK] $*"; }
log_warn()  { echo "[WATCHDOG-WARN] $*"; }
log_err()   { echo "[WATCHDOG-ERROR] $*" >&2; }

write_status() {
    echo "$1" > "$STATUS_FILE"
}

check_proxy() {
    if curl -sx "$PROXY" --connect-timeout 5 --max-time 10 "$TEST_URL" -o /dev/null 2>/dev/null; then
        return 0
    fi
    return 1
}

try_switch_node() {
    local DATA
    DATA=$(curl -s "$API/proxies/PROXY" 2>/dev/null || echo "")
    if [[ -z "$DATA" ]]; then
        return 1
    fi

    local CURRENT
    CURRENT=$(echo "$DATA" | grep -o '"now":"[^"]*"' | head -1 | cut -d'"' -f4)
    local NODES
    NODES=$(echo "$DATA" | grep -o '"all":\[[^]]*\]' | tr ',' '\n' | grep -o '"[^"]*"' | tr -d '"')

    for NODE in $NODES; do
        [[ "$NODE" == "$CURRENT" ]] && continue
        [[ "$NODE" == "DIRECT" ]] && continue

        log_info "Trying node: $NODE"
        curl -s -X PUT "$API/proxies/PROXY" \
            -H "Content-Type: application/json" \
            -d "{\"name\": \"$NODE\"}" 2>/dev/null || continue

        sleep 3

        if check_proxy; then
            log_ok "Switched to working node: $NODE"
            return 0
        fi
    done

    return 1
}

activate_fallback() {
    log_warn "All nodes failed. Activating fallback to DIRECT mode..."

    curl -s -X PATCH "$API/configs" \
        -H "Content-Type: application/json" \
        -d '{"mode": "direct"}' 2>/dev/null || true

    write_status "fallback"
    log_warn "Fallback active: all traffic now goes direct (no proxy)"
    log_warn "Run 'bash scripts/watchdog.sh recover' to retry proxy when ready"
}

recover_proxy() {
    log_info "Attempting to recover proxy..."

    curl -s -X PATCH "$API/configs" \
        -H "Content-Type: application/json" \
        -d '{"mode": "global"}' 2>/dev/null || true

    sleep 3

    if check_proxy; then
        write_status "healthy"
        log_ok "Proxy recovered successfully"
        return 0
    fi

    if try_switch_node; then
        write_status "healthy"
        log_ok "Proxy recovered with a different node"
        return 0
    fi

    log_err "Recovery failed. Proxy still unavailable."
    activate_fallback
    return 1
}

run_daemon() {
    local FAIL_COUNT=0

    write_status "healthy"
    log_ok "Watchdog daemon started (check every ${CHECK_INTERVAL}s, failover after ${FAIL_THRESHOLD} failures)"

    while true; do
        sleep "$CHECK_INTERVAL"

        CURRENT_STATUS=$(cat "$STATUS_FILE" 2>/dev/null || echo "unknown")

        if [[ "$CURRENT_STATUS" == "fallback" ]]; then
            if check_proxy; then
                log_ok "Proxy is reachable again, recovering..."
                curl -s -X PATCH "$API/configs" \
                    -H "Content-Type: application/json" \
                    -d '{"mode": "global"}' 2>/dev/null || true
                write_status "healthy"
                FAIL_COUNT=0
            fi
            continue
        fi

        if check_proxy; then
            if [[ $FAIL_COUNT -gt 0 ]]; then
                log_ok "Proxy recovered (was failing for $FAIL_COUNT checks)"
            fi
            FAIL_COUNT=0
            write_status "healthy"
            continue
        fi

        FAIL_COUNT=$((FAIL_COUNT + 1))
        log_warn "Proxy check failed ($FAIL_COUNT/$FAIL_THRESHOLD)"

        if [[ $FAIL_COUNT -ge $FAIL_THRESHOLD ]]; then
            log_warn "Threshold reached, attempting node switch..."

            if try_switch_node; then
                FAIL_COUNT=0
                write_status "healthy"
            else
                activate_fallback
                FAIL_COUNT=0
            fi
        fi
    done
}

start_daemon() {
    if [[ -f "$PID_FILE" ]]; then
        local OLD_PID
        OLD_PID=$(cat "$PID_FILE")
        if kill -0 "$OLD_PID" 2>/dev/null; then
            log_info "Watchdog already running (PID: $OLD_PID)"
            return 0
        fi
        rm -f "$PID_FILE"
    fi

    nohup bash "$0" daemon > "$PROJECT_DIR/config/logs/watchdog.log" 2>&1 &
    local NEW_PID=$!
    echo "$NEW_PID" > "$PID_FILE"

    sleep 1
    if kill -0 "$NEW_PID" 2>/dev/null; then
        log_ok "Watchdog started (PID: $NEW_PID)"
    else
        log_err "Watchdog failed to start"
        exit 1
    fi
}

stop_daemon() {
    if [[ ! -f "$PID_FILE" ]]; then
        log_info "Watchdog is not running"
        return 0
    fi

    local PID
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
        kill "$PID" 2>/dev/null || true
        sleep 1
        kill -0 "$PID" 2>/dev/null && kill -9 "$PID" 2>/dev/null || true
        log_ok "Watchdog stopped (PID: $PID)"
    else
        log_info "Watchdog process not found"
    fi
    rm -f "$PID_FILE"
}

show_status() {
    local STATUS
    STATUS=$(cat "$STATUS_FILE" 2>/dev/null || echo "unknown")

    echo "Proxy status: $STATUS"

    if [[ -f "$PID_FILE" ]]; then
        local PID
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            echo "Watchdog: running (PID: $PID)"
        else
            echo "Watchdog: dead (stale PID file)"
        fi
    else
        echo "Watchdog: not running"
    fi
}

case "${1:-}" in
    start)
        start_daemon
        ;;
    stop)
        stop_daemon
        ;;
    status)
        show_status
        ;;
    recover)
        recover_proxy
        ;;
    daemon)
        run_daemon
        ;;
    *)
        echo "Usage: bash scripts/watchdog.sh <start|stop|status|recover>"
        echo ""
        echo "Commands:"
        echo "  start   - Start the watchdog daemon in background"
        echo "  stop    - Stop the watchdog daemon"
        echo "  status  - Show current proxy and watchdog status"
        echo "  recover - Manually try to recover proxy from fallback mode"
        exit 1
        ;;
esac
