#!/usr/bin/env bash
# =============================================================================
# wsl-proxy-launcher.sh — Auto-detect Windows proxy and launch any command
# =============================================================================
# Scans common Windows proxy tools (Clash, v2rayN, sing-box, Hiddify, etc.)
# for their listen ports, tests which one is active, sets HTTPS_PROXY env
# vars, then launches your command with proxy inherited.
#
# Usage:
#   wsl-proxy-launcher.sh [--no-proxy <hosts>] [--scan-dir <path>] -- <command>
#
# Examples:
#   wsl-proxy-launcher.sh -- hermes
#   wsl-proxy-launcher.sh --no-proxy "api.openai.com" -- curl https://google.com
#   wsl-proxy-launcher.sh --scan-dir /mnt/d/Clash -- python my_script.py
#
# Config via env vars (optional):
#   PROXY_SCAN_DIRS      - colon-separated extra dirs to scan
#   PROXY_NO_PROXY       - comma-separated hosts to bypass proxy
#   PROXY_FALLBACK_PORTS - space-separated fallback ports (default: 7890 1080 10809)
# =============================================================================

set -euo pipefail

# --- Defaults ---
DEFAULT_FALLBACK_PORTS="7890 1080 10809 2080"
DEFAULT_NO_PROXY="localhost,127.0.0.1,::1"

# Built-in scan directories for common Windows proxy tools (WSL /mnt/ paths)
# Users can extend via PROXY_SCAN_DIRS env var
BUILTIN_SCAN_DIRS=(
    # Clash Verge / Clash for Windows
    "/mnt/c/Users/${USER}/.config/clash-verge"
    "/mnt/c/Users/${USER}/AppData/Roaming/clash-verge"
    # v2rayN
    "/mnt/c/Users/${USER}/AppData/Roaming/v2rayN"
    "/mnt/c/tools/v2rayN"
    # sing-box
    "/mnt/c/Users/${USER}/.config/sing-box"
    # Hiddify
    "/mnt/c/Users/${USER}/AppData/Roaming/hiddify"
)

# --- Config file patterns to scan ---
CONFIG_PATTERNS=(
    "config.yaml"
    "config.yml"
    "config.json"
)

# --- Colors ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- Parse args ---
EXTRA_SCAN_DIRS=""
NO_PROXY_HOSTS=""
COMMAND=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --scan-dir)
            EXTRA_SCAN_DIRS="$EXTRA_SCAN_DIRS:$2"
            shift 2
            ;;
        --no-proxy)
            NO_PROXY_HOSTS="$2"
            shift 2
            ;;
        --)
            shift
            COMMAND=("$@")
            break
            ;;
        *)
            COMMAND=("$@")
            break
            ;;
    esac
done

if [ ${#COMMAND[@]} -eq 0 ]; then
    echo -e "${RED}Error: No command specified.${NC}"
    echo "Usage: $0 [options] -- <command> [args...]"
    exit 1
fi

# --- Merge config ---
FALLBACK_PORTS="${PROXY_FALLBACK_PORTS:-$DEFAULT_FALLBACK_PORTS}"
NO_PROXY_HOSTS="${NO_PROXY_HOSTS:-${PROXY_NO_PROXY:-$DEFAULT_NO_PROXY}}"

ALL_SCAN_DIRS=("${BUILTIN_SCAN_DIRS[@]}")
if [ -n "${PROXY_SCAN_DIRS:-}" ]; then
    IFS=':' read -ra EXTRA <<< "$PROXY_SCAN_DIRS"
    ALL_SCAN_DIRS+=("${EXTRA[@]}")
fi
if [ -n "$EXTRA_SCAN_DIRS" ]; then
    IFS=':' read -ra EXTRA2 <<< "$EXTRA_SCAN_DIRS"
    ALL_SCAN_DIRS+=("${EXTRA2[@]}")
fi

# =============================================================================
# Port extraction from config files
# =============================================================================

extract_port() {
    local config="$1"
    local port=""
    [ -r "$config" ] || return 0

    # Pattern 1: yaml "mixed-port: N" or json "listen_port": N / "port": N
    port=$(grep -oE '("listen_port"|mixed-port|"port")\s*[:=]\s*[0-9]+' "$config" 2>/dev/null \
        | grep -oE '[0-9]+' | head -1 | tr -d '\r')

    # Pattern 2: "listen": "IP:PORT" (hysteria, juicity, naiveproxy)
    if [ -z "$port" ]; then
        port=$(grep -oE '"listen"\s*:\s*"[^"]*:[0-9]+"' "$config" 2>/dev/null \
            | grep -oE ':[0-9]+"' | tr -d ':"' | head -1 | tr -d '\r')
    fi

    # Pattern 3: "socks-port" in Clash or "port" as top-level field
    if [ -z "$port" ]; then
        port=$(grep -oE '"socks-port"|"http-port"|"mixed-port")\s*:\s*[0-9]+' "$config" 2>/dev/null \
            | grep -oE '[0-9]+' | head -1 | tr -d '\r')
    fi

    [ -n "$port" ] && [ "$port" -gt 0 ] 2>/dev/null && echo "$port"
}

# =============================================================================
# Scan all directories for proxy configs
# =============================================================================

scan_all_ports() {
    local ports=""
    local seen_dirs=""

    for dir in "${ALL_SCAN_DIRS[@]}"; do
        # Skip duplicates and non-existent dirs
        [[ " $seen_dirs " =~ " $dir " ]] && continue
        seen_dirs="$seen_dirs $dir"
        [ -d "$dir" ] || continue

        for pattern in "${CONFIG_PATTERNS[@]}"; do
            local config="$dir/$pattern"
            local port
            port=$(extract_port "$config")
            if [ -n "$port" ]; then
                ports="$ports $port"
            fi
        done
    done

    # Priority: 7890 (Clash mixed) > others, unique, stable order
    echo "$ports" | tr ' ' '\n' | sort -u | sort -rn | tr '\n' ' '
}

# =============================================================================
# Proxy testing
# =============================================================================

test_proxy() {
    local port="$1"
    # Try Google first (most reliable), fallback to GitHub
    curl -s --connect-timeout 5 --proxy "http://127.0.0.1:$port" \
        --head "https://www.google.com" >/dev/null 2>&1 || \
    curl -s --connect-timeout 5 --proxy "http://127.0.0.1:$port" \
        --head "https://github.com" >/dev/null 2>&1
}

# =============================================================================
# Main
# =============================================================================

echo -e "${CYAN}[wsl-proxy-launcher]${NC} Scanning for Windows proxy..."

CONFIG_PORTS=$(scan_all_ports)
echo -e "${CYAN}[wsl-proxy-launcher]${NC} Ports from configs: ${CONFIG_PORTS:-none}"

# Build candidate list: 7890 first (Clash default), then config ports, then fallbacks
ALL_PORTS="7890 $CONFIG_PORTS $FALLBACK_PORTS"

PORT=""
for candidate in $ALL_PORTS; do
    if test_proxy "$candidate"; then
        PORT="$candidate"
        break
    fi
done

if [ -n "$PORT" ]; then
    export https_proxy="http://127.0.0.1:$PORT"
    export http_proxy="http://127.0.0.1:$PORT"
    export HTTP_PROXY="http://127.0.0.1:$PORT"
    export HTTPS_PROXY="http://127.0.0.1:$PORT"
    export no_proxy="$NO_PROXY_HOSTS"
    export NO_PROXY="$NO_PROXY_HOSTS"

    echo -e "${GREEN}[wsl-proxy-launcher]${NC} Proxy: http://127.0.0.1:$PORT"
    echo -e "${GREEN}[wsl-proxy-launcher]${NC} No-proxy: $NO_PROXY_HOSTS"
else
    echo -e "${YELLOW}[wsl-proxy-launcher]${NC} No proxy detected, running without"
fi

echo -e "${GREEN}[wsl-proxy-launcher]${NC} Launching: ${COMMAND[*]}"
exec "${COMMAND[@]}"
