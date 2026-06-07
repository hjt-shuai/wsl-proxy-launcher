#!/usr/bin/env bash
# =============================================================================
# setup.sh — One-command install for wsl-proxy-launcher
# =============================================================================
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/hjt-shuai/wsl-proxy-launcher/main/setup.sh | bash
# Or locally:
#   bash setup.sh [--install-dir ~/.local/bin]
# =============================================================================

set -euo pipefail

INSTALL_DIR="${HOME}/.local/bin"
SCRIPT_NAME="wsl-proxy-launcher.sh"
GREEN='\033[0;32m'
CYAN='\033[0;36m'
NC='\033[0m'

while [[ $# -gt 0 ]]; do
    case "$1" in
        --install-dir) INSTALL_DIR="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

mkdir -p "$INSTALL_DIR"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp "$SCRIPT_DIR/$SCRIPT_NAME" "$INSTALL_DIR/$SCRIPT_NAME"
chmod +x "$INSTALL_DIR/$SCRIPT_NAME"

echo -e "${GREEN}[setup]${NC} Installed to $INSTALL_DIR/$SCRIPT_NAME"

# Add alias suggestion
if [ -f "${HOME}/.bashrc" ]; then
    if ! grep -q "$SCRIPT_NAME" "${HOME}/.bashrc" 2>/dev/null; then
        echo "" >> "${HOME}/.bashrc"
        echo "# wsl-proxy-launcher - auto-detects Windows proxy" >> "${HOME}/.bashrc"
        echo "# Usage: wsl-proxy your-command" >> "${HOME}/.bashrc"
        echo "alias wsl-proxy='$INSTALL_DIR/$SCRIPT_NAME --'" >> "${HOME}/.bashrc"
        echo -e "${GREEN}[setup]${NC} Added 'wsl-proxy' alias to ~/.bashrc"
        echo -e "${CYAN}[setup]${NC} Run: source ~/.bashrc"
    fi
fi

# Quick test
echo ""
echo -e "${CYAN}[setup]${NC} Testing proxy detection..."
"$INSTALL_DIR/$SCRIPT_NAME" -- echo "Test OK" 2>&1 || true

echo ""
echo -e "${GREEN}[setup]${NC} Done! Usage examples:"
echo "  wsl-proxy hermes"
echo "  wsl-proxy --no-proxy api.github.com -- curl https://google.com"
echo "  wsl-proxy --scan-dir /mnt/d/my-proxy -- python script.py"
echo ""
echo "  Config via env vars (optional):"
echo "    PROXY_SCAN_DIRS      - extra directories to scan"
echo "    PROXY_NO_PROXY       - hosts to bypass proxy"
echo "    PROXY_FALLBACK_PORTS - fallback ports to probe"
