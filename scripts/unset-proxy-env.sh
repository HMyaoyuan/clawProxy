#!/usr/bin/env bash
# This script MUST be sourced, not executed:
#   source scripts/unset-proxy-env.sh

# === Layer 1: Current shell session ===
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy
unset ALL_PROXY all_proxy
unset NO_PROXY no_proxy
echo "[OK] Layer 1: Shell env vars cleared"

# === Layer 2: /etc/environment ===
_clean_etc_env() {
    grep -v -E '^(HTTP_PROXY|HTTPS_PROXY|http_proxy|https_proxy|ALL_PROXY|all_proxy|NO_PROXY|no_proxy)=' /etc/environment > /tmp/_etc_env_clean 2>/dev/null || true
    cat /tmp/_etc_env_clean > /etc/environment 2>/dev/null || true
    rm -f /tmp/_etc_env_clean
}
if [ -w /etc/environment ]; then
    _clean_etc_env
    echo "[OK] Layer 2: /etc/environment cleaned"
elif command -v sudo >/dev/null 2>&1; then
    sudo sh -c "grep -v -E '^(HTTP_PROXY|HTTPS_PROXY|http_proxy|https_proxy|ALL_PROXY|all_proxy|NO_PROXY|no_proxy)=' /etc/environment > /tmp/_etc_env_clean 2>/dev/null || true; cat /tmp/_etc_env_clean > /etc/environment 2>/dev/null || true; rm -f /tmp/_etc_env_clean" 2>/dev/null && \
        echo "[OK] Layer 2: /etc/environment cleaned (via sudo)" || \
        echo "[SKIP] Layer 2: /etc/environment (no permission)"
else
    echo "[SKIP] Layer 2: /etc/environment (no write access)"
fi

# === Layer 3: ~/.bashrc / ~/.profile ===
_MARKER="# clawProxy-managed proxy settings"
for _RC in "$HOME/.bashrc" "$HOME/.profile"; do
    if [ -f "$_RC" ]; then
        sed -i "/$_MARKER/,/# clawProxy-end/d" "$_RC" 2>/dev/null || true
    fi
done
echo "[OK] Layer 3: ~/.bashrc and ~/.profile cleaned"

# === Layer 4: systemd user environment ===
if command -v systemctl >/dev/null 2>&1; then
    systemctl --user unset-environment \
        HTTP_PROXY HTTPS_PROXY http_proxy https_proxy \
        ALL_PROXY all_proxy NO_PROXY no_proxy 2>/dev/null && \
        echo "[OK] Layer 4: systemd user environment cleared" || \
        echo "[SKIP] Layer 4: systemd not available"
else
    echo "[SKIP] Layer 4: systemd not found"
fi

echo ""
echo "[OK] Proxy removed from all levels"
