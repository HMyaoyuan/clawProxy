#!/usr/bin/env bash
# EMERGENCY FALLBACK - Immediately restore direct connection
# This script MUST be sourced: source scripts/fallback.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "[FALLBACK] Activating emergency direct connection..."

# 1. Switch mihomo to direct mode (if API is reachable)
curl -s -X PATCH "http://127.0.0.1:9090/configs" \
    -H "Content-Type: application/json" \
    -d '{"mode": "direct"}' 2>/dev/null && \
    echo "[FALLBACK] Switched mihomo to direct mode" || true

# 2. Clear all proxy environment variables
unset HTTP_PROXY HTTPS_PROXY http_proxy https_proxy
unset ALL_PROXY all_proxy
unset NO_PROXY no_proxy
echo "[FALLBACK] Proxy environment variables cleared"

# 3. Remove git proxy config
git config --global --unset http.proxy 2>/dev/null || true
git config --global --unset https.proxy 2>/dev/null || true
echo "[FALLBACK] Git proxy config removed"

# 4. Update status file
echo "fallback" > "$PROJECT_DIR/.proxy-status" 2>/dev/null || true

echo ""
echo "[FALLBACK] Direct connection restored. You can now communicate normally."
echo "[FALLBACK] To re-enable proxy later, run:"
echo "  bash scripts/watchdog.sh recover"
echo "  source scripts/set-proxy-env.sh"
