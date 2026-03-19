#!/usr/bin/env bash
# This script MUST be sourced, not executed:
#   source scripts/set-proxy-env.sh

PROXY_HTTP="http://127.0.0.1:7890"
PROXY_SOCKS="socks5://127.0.0.1:7891"
NO_PROXY_LIST="localhost,127.0.0.1,::1"

# === Layer 1: Current shell session ===
export HTTP_PROXY="$PROXY_HTTP"
export HTTPS_PROXY="$PROXY_HTTP"
export http_proxy="$PROXY_HTTP"
export https_proxy="$PROXY_HTTP"
export ALL_PROXY="$PROXY_SOCKS"
export all_proxy="$PROXY_SOCKS"
export NO_PROXY="$NO_PROXY_LIST"
export no_proxy="$NO_PROXY_LIST"
echo "[OK] Layer 1: Current shell env vars set"

# === Layer 2: /etc/environment (system-wide, all new processes) ===
_PROXY_LINES="HTTP_PROXY=$PROXY_HTTP
HTTPS_PROXY=$PROXY_HTTP
http_proxy=$PROXY_HTTP
https_proxy=$PROXY_HTTP
ALL_PROXY=$PROXY_SOCKS
all_proxy=$PROXY_SOCKS
NO_PROXY=$NO_PROXY_LIST
no_proxy=$NO_PROXY_LIST"

if [ -w /etc/environment ]; then
    grep -v -E '^(HTTP_PROXY|HTTPS_PROXY|http_proxy|https_proxy|ALL_PROXY|all_proxy|NO_PROXY|no_proxy)=' /etc/environment > /tmp/_etc_env_clean 2>/dev/null || true
    cat /tmp/_etc_env_clean > /etc/environment 2>/dev/null || true
    echo "$_PROXY_LINES" >> /etc/environment 2>/dev/null || true
    rm -f /tmp/_etc_env_clean
    echo "[OK] Layer 2: /etc/environment updated"
elif command -v sudo >/dev/null 2>&1; then
    sudo sh -c "grep -v -E '^(HTTP_PROXY|HTTPS_PROXY|http_proxy|https_proxy|ALL_PROXY|all_proxy|NO_PROXY|no_proxy)=' /etc/environment > /tmp/_etc_env_clean 2>/dev/null || true; cat /tmp/_etc_env_clean > /etc/environment 2>/dev/null || true; rm -f /tmp/_etc_env_clean" 2>/dev/null
    echo "$_PROXY_LINES" | sudo tee -a /etc/environment >/dev/null 2>/dev/null && \
        echo "[OK] Layer 2: /etc/environment updated (via sudo)" || \
        echo "[SKIP] Layer 2: /etc/environment (no permission)"
else
    echo "[SKIP] Layer 2: /etc/environment (no write access)"
fi

# === Layer 3: ~/.bashrc / ~/.profile (new shell sessions) ===
_MARKER="# clawProxy-managed proxy settings"
for _RC in "$HOME/.bashrc" "$HOME/.profile"; do
    if [ -f "$_RC" ]; then
        sed -i "/$_MARKER/,/# clawProxy-end/d" "$_RC" 2>/dev/null || true
    fi
    cat >> "$_RC" 2>/dev/null <<RCEOF
$_MARKER
export HTTP_PROXY="$PROXY_HTTP"
export HTTPS_PROXY="$PROXY_HTTP"
export http_proxy="$PROXY_HTTP"
export https_proxy="$PROXY_HTTP"
export ALL_PROXY="$PROXY_SOCKS"
export all_proxy="$PROXY_SOCKS"
export NO_PROXY="$NO_PROXY_LIST"
export no_proxy="$NO_PROXY_LIST"
# clawProxy-end
RCEOF
done
echo "[OK] Layer 3: ~/.bashrc and ~/.profile updated"

# === Layer 4: systemd user environment (for systemd-managed services) ===
if command -v systemctl >/dev/null 2>&1; then
    systemctl --user set-environment \
        HTTP_PROXY="$PROXY_HTTP" \
        HTTPS_PROXY="$PROXY_HTTP" \
        http_proxy="$PROXY_HTTP" \
        https_proxy="$PROXY_HTTP" \
        ALL_PROXY="$PROXY_SOCKS" \
        all_proxy="$PROXY_SOCKS" \
        NO_PROXY="$NO_PROXY_LIST" \
        no_proxy="$NO_PROXY_LIST" 2>/dev/null && \
        echo "[OK] Layer 4: systemd user environment set" || \
        echo "[SKIP] Layer 4: systemd not available"
else
    echo "[SKIP] Layer 4: systemd not found"
fi

echo ""
echo "[OK] Proxy configured at all available levels"
echo "  HTTP_PROXY=$PROXY_HTTP"
echo "  HTTPS_PROXY=$PROXY_HTTP"
echo "  ALL_PROXY=$PROXY_SOCKS"
echo ""
echo "[TIP] For headless browsers, use launch arg: --proxy-server=$PROXY_HTTP"
