#!/usr/bin/env bash
# =============================================================================
# Hermes Agent proxy wrapper using wsl-proxy-launcher
# =============================================================================
# Copy this to ~/.hermes/bin/hermes-launcher.sh or use directly.
#
# DeepSeek/China APIs → direct (fast)
# Agnes/OpenAI/others  → via Windows proxy (unblocked)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAUNCHER="$SCRIPT_DIR/../wsl-proxy-launcher.sh"

# Hosts accessible from China without proxy
NO_PROXY="localhost,127.0.0.1,::1,api.deepseek.com,api.moonshot.cn,dashscope.aliyuncs.com"

# ChromeGo location (adjust to your setup)
CHROMEGO_DIR="/mnt/d/tools/ChromeGo/ChromeGo"

exec "$LAUNCHER" \
    --no-proxy "$NO_PROXY" \
    --scan-dir "$CHROMEGO_DIR" \
    -- hermes "$@"
