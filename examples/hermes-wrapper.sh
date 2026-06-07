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

# Add your proxy tool's config directory here
PROXY_DIR="/mnt/d/tools/clash"

exec "$LAUNCHER" \
    --no-proxy "$NO_PROXY" \
    --scan-dir "$PROXY_DIR" \
    -- hermes "$@"
