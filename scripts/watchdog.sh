#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PID_FILE="$PROJECT_DIR/.watchdog.pid"
STATUS_FILE="$PROJECT_DIR/.proxy-status"
API="http://127.0.0.1:9090"

CHECK_INTERVAL=60
PROXY="http://127.0.0.1:7890"

# baidu.com 是国内站点，从中国任何网络都能直达
# 全局代理模式下，它也会走代理，如果连 baidu 都不通说明代理彻底坏了
DIRECT_TEST_URL="https://www.baidu.com"
# gstatic 用于测试代理节点是否能访问海外
PROXY_TEST_URL="https://www.gstatic.com/generate_204"

log_info()  { echo "[$(date '+%H:%M:%S')] [WATCHDOG] $*"; }
log_ok()    { echo "[$(date '+%H:%M:%S')] [WATCHDOG-OK] $*"; }
log_warn()  { echo "[$(date '+%H:%M:%S')] [WATCHDOG-WARN] $*"; }
log_err()   { echo "[$(date '+%H:%M:%S')] [WATCHDOG-ERROR] $*" >&2; }

write_status() {
    echo "$1" > "$STATUS_FILE"
}

# 通过代理测试：如果连 baidu 都不通，说明代理完全不可用
check_connectivity() {
    if curl -sx "$PROXY" --connect-timeout 5 --max-time 10 "$DIRECT_TEST_URL" -o /dev/null 2>/dev/null; then
        return 0
    fi
    return 1
}

# 绕过代理直连测试：确认底层网络本身没问题
check_direct() {
    if curl -s --noproxy '*' --connect-timeout 5 --max-time 10 "$DIRECT_TEST_URL" -o /dev/null 2>/dev/null; then
        return 0
    fi
    return 1
}

# 测试代理节点能否访问海外站点
check_proxy_overseas() {
    if curl -sx "$PROXY" --connect-timeout 5 --max-time 10 "$PROXY_TEST_URL" -o /dev/null 2>/dev/null; then
        return 0
    fi
    return 1
}

try_switch_node() {
    local DATA
    DATA=$(curl -s --noproxy '*' "$API/proxies/PROXY" 2>/dev/null || echo "")
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
        curl -s --noproxy '*' -X PUT "$API/proxies/PROXY" \
            -H "Content-Type: application/json" \
            -d "{\"name\": \"$NODE\"}" 2>/dev/null || continue

        sleep 3

        if check_connectivity; then
            log_ok "Switched to working node: $NODE"
            return 0
        fi
    done

    return 1
}

activate_fallback() {
    log_warn "Proxy broken. Activating fallback to DIRECT mode..."

    curl -s --noproxy '*' -X PATCH "$API/configs" \
        -H "Content-Type: application/json" \
        -d '{"mode": "direct"}' 2>/dev/null || true

    write_status "fallback"
    log_warn "Fallback active: all traffic now goes direct (no proxy)"
    log_warn "Run 'bash scripts/watchdog.sh recover' when ready to retry"
}

recover_proxy() {
    log_info "Attempting to recover proxy..."

    curl -s --noproxy '*' -X PATCH "$API/configs" \
        -H "Content-Type: application/json" \
        -d '{"mode": "global"}' 2>/dev/null || true

    sleep 3

    if check_connectivity; then
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
    write_status "healthy"
    log_ok "Watchdog daemon started (check every ${CHECK_INTERVAL}s)"
    log_info "Connectivity test: $DIRECT_TEST_URL (via proxy)"
    log_info "If unreachable -> switch node -> if all fail -> fallback to direct"

    while true; do
        sleep "$CHECK_INTERVAL"

        CURRENT_STATUS=$(cat "$STATUS_FILE" 2>/dev/null || echo "unknown")

        # --- FALLBACK 模式：定期尝试恢复 ---
        if [[ "$CURRENT_STATUS" == "fallback" ]]; then
            log_info "In fallback mode, testing if proxy can recover..."
            # 先切回 global 测试
            curl -s --noproxy '*' -X PATCH "$API/configs" \
                -H "Content-Type: application/json" \
                -d '{"mode": "global"}' 2>/dev/null || true
            sleep 2

            if check_connectivity; then
                write_status "healthy"
                log_ok "Proxy is working again! Recovered from fallback."
            else
                # 恢复失败，切回 direct
                curl -s --noproxy '*' -X PATCH "$API/configs" \
                    -H "Content-Type: application/json" \
                    -d '{"mode": "direct"}' 2>/dev/null || true
            fi
            continue
        fi

        # --- HEALTHY 模式：正常健康检查 ---
        if check_connectivity; then
            continue
        fi

        # 连通性检查失败！baidu.com 都不通了
        log_warn "Connectivity check FAILED (cannot reach $DIRECT_TEST_URL via proxy)"

        # 确认底层网络本身是否正常
        if ! check_direct; then
            log_err "Direct network also unreachable. Network issue, not proxy."
            continue
        fi

        # 直连正常但代理不通 → 代理节点有问题
        log_warn "Direct connection works, proxy is broken. Attempting node switch..."

        if try_switch_node; then
            write_status "healthy"
            log_ok "Switched to a working node"
        else
            activate_fallback
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

    mkdir -p "$PROJECT_DIR/config/logs"
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

    # 实时快速检测
    echo ""
    echo "Quick connectivity test:"
    if check_connectivity; then
        echo "  Proxy -> baidu.com: OK"
    else
        echo "  Proxy -> baidu.com: FAIL"
    fi
    if check_direct; then
        echo "  Direct -> baidu.com: OK"
    else
        echo "  Direct -> baidu.com: FAIL"
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
        echo "  status  - Show current proxy and watchdog status (with live test)"
        echo "  recover - Manually try to recover proxy from fallback mode"
        exit 1
        ;;
esac
