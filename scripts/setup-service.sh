#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
MIHOMO_BIN="$HOME/.local/bin/mihomo"
CONFIG_DIR="$PROJECT_DIR/config"

log_info() { echo "[INFO] $*"; }
log_ok()   { echo "[OK] $*"; }
log_err()  { echo "[ERROR] $*" >&2; }

if ! command -v systemctl >/dev/null 2>&1; then
    log_err "systemd not available. Falling back to nohup mode."
    log_info "Run 'bash scripts/start.sh' and 'bash scripts/watchdog.sh start' instead."
    exit 1
fi

if [[ ! -x "$MIHOMO_BIN" ]]; then
    log_err "mihomo not found. Run 'bash scripts/install.sh' first."
    exit 1
fi

SERVICE_DIR="$HOME/.config/systemd/user"
mkdir -p "$SERVICE_DIR"
mkdir -p "$CONFIG_DIR/logs"

# mihomo service
cat > "$SERVICE_DIR/claw-proxy.service" <<EOF
[Unit]
Description=clawProxy - mihomo proxy service
After=network.target

[Service]
Type=simple
ExecStart=$MIHOMO_BIN -d $CONFIG_DIR
Restart=always
RestartSec=3
StandardOutput=append:$CONFIG_DIR/logs/mihomo.log
StandardError=append:$CONFIG_DIR/logs/mihomo.log

[Install]
WantedBy=default.target
EOF
log_ok "Created claw-proxy.service"

# watchdog service
cat > "$SERVICE_DIR/claw-watchdog.service" <<EOF
[Unit]
Description=clawProxy - watchdog health monitor
After=claw-proxy.service
Requires=claw-proxy.service

[Service]
Type=simple
ExecStart=/usr/bin/env bash $SCRIPT_DIR/watchdog.sh daemon
Restart=always
RestartSec=10
StandardOutput=append:$CONFIG_DIR/logs/watchdog.log
StandardError=append:$CONFIG_DIR/logs/watchdog.log

[Install]
WantedBy=default.target
EOF
log_ok "Created claw-watchdog.service"

systemctl --user daemon-reload

# enable lingering so user services start at boot without login
if command -v loginctl >/dev/null 2>&1; then
    loginctl enable-linger "$(whoami)" 2>/dev/null && \
        log_ok "Enabled linger (services survive logout/reboot)" || \
        log_info "Could not enable linger (may need root)"
fi

systemctl --user enable claw-proxy.service 2>/dev/null
systemctl --user enable claw-watchdog.service 2>/dev/null

systemctl --user restart claw-proxy.service
sleep 2
systemctl --user restart claw-watchdog.service

if systemctl --user is-active --quiet claw-proxy.service; then
    MIHOMO_PID=$(systemctl --user show claw-proxy.service -p MainPID --value)
    log_ok "mihomo running via systemd (PID: $MIHOMO_PID)"
else
    log_err "mihomo failed to start. Check: journalctl --user -u claw-proxy.service"
    exit 1
fi

if systemctl --user is-active --quiet claw-watchdog.service; then
    log_ok "watchdog running via systemd"
else
    log_err "watchdog failed to start. Check: journalctl --user -u claw-watchdog.service"
fi

echo ""
log_ok "Systemd services configured. Both services will:"
log_info "  - Auto-restart on crash (mihomo: 3s, watchdog: 10s)"
log_info "  - Auto-start on system boot"
echo ""
log_info "Useful commands:"
log_info "  systemctl --user status claw-proxy        # check mihomo status"
log_info "  systemctl --user status claw-watchdog     # check watchdog status"
log_info "  systemctl --user restart claw-proxy       # restart mihomo"
log_info "  journalctl --user -u claw-proxy -f        # tail mihomo logs"
