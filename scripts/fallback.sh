#!/usr/bin/env bash
# EMERGENCY FALLBACK - Immediately restore direct connection
# This script MUST be sourced: source scripts/fallback.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "[FALLBACK] Activating emergency direct connection..."

# 1. Switch mihomo to direct mode (if API is reachable)
curl -s --noproxy '*' -X PATCH "http://127.0.0.1:9090/configs" \
    -H "Content-Type: application/json" \
    -d '{"mode": "direct"}' 2>/dev/null && \
    echo "[FALLBACK] Switched mihomo to direct mode" || true

# 2. Clear shell env vars
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy
unset ALL_PROXY all_proxy
unset NO_PROXY no_proxy
echo "[FALLBACK] Shell env vars cleared"

# 3. Clean /etc/environment
if [ -w /etc/environment ]; then
    grep -v -E '^(HTTP_PROXY|HTTPS_PROXY|http_proxy|https_proxy|ALL_PROXY|all_proxy|NO_PROXY|no_proxy)=' /etc/environment > /tmp/_etc_env_clean 2>/dev/null || true
    cat /tmp/_etc_env_clean > /etc/environment 2>/dev/null || true
    rm -f /tmp/_etc_env_clean
    echo "[FALLBACK] /etc/environment cleaned"
elif command -v sudo >/dev/null 2>&1; then
    sudo sh -c "grep -v -E '^(HTTP_PROXY|HTTPS_PROXY|http_proxy|https_proxy|ALL_PROXY|all_proxy|NO_PROXY|no_proxy)=' /etc/environment > /tmp/_etc_env_clean 2>/dev/null || true; cat /tmp/_etc_env_clean > /etc/environment 2>/dev/null || true; rm -f /tmp/_etc_env_clean" 2>/dev/null || true
fi

# 4. Clean ~/.bashrc and ~/.profile
_MARKER="# clawProxy-managed proxy settings"
for _RC in "$HOME/.bashrc" "$HOME/.profile"; do
    [ -f "$_RC" ] && sed -i "/$_MARKER/,/# clawProxy-end/d" "$_RC" 2>/dev/null || true
done
echo "[FALLBACK] Shell config files cleaned"

# 5. Clean systemd env
if command -v systemctl >/dev/null 2>&1; then
    systemctl --user unset-environment \
        HTTP_PROXY HTTPS_PROXY http_proxy https_proxy \
        ALL_PROXY all_proxy NO_PROXY no_proxy 2>/dev/null || true
fi

# 6. Remove git proxy
git config --global --unset http.proxy 2>/dev/null || true
git config --global --unset https.proxy 2>/dev/null || true

# 7. Update status file
echo "fallback" > "$PROJECT_DIR/.proxy-status" 2>/dev/null || true

echo ""
echo "[FALLBACK] Direct connection restored at ALL levels."
echo "[FALLBACK] To re-enable proxy later:"
echo "  bash scripts/watchdog.sh recover"
echo "  source scripts/set-proxy-env.sh"
