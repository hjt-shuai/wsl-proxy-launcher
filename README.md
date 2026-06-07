# wsl-proxy-launcher

**Auto-detect Windows proxy from WSL2 and launch any command with it.**

Scans common Windows proxy tools (Clash, v2rayN, ChromeGo, sing-box, Hiddify, etc.)
for their listen ports, tests which one is active, sets `https_proxy` environment
variables, then launches your command. No manual port configuration needed.

## Why?

WSL2 can access Windows `127.0.0.1` via localhost forwarding, but tools running
in WSL don't know which proxy port to use. You switch between Clash (7890),
sing-box (1080), or Xray (10809)? This script figures it out automatically.

## Quick Start

```bash
# One-command install
curl -fsSL https://raw.githubusercontent.com/<user>/wsl-proxy-launcher/main/setup.sh | bash

# Or clone and install
git clone https://github.com/<user>/wsl-proxy-launcher.git
cd wsl-proxy-launcher && bash setup.sh
```

## Usage

```bash
# Wrap any command — proxy is auto-detected and inherited
wsl-proxy hermes
wsl-proxy curl https://www.google.com
wsl-proxy python my_script.py

# Specify hosts to bypass proxy (comma-separated)
wsl-proxy --no-proxy "api.deepseek.com,api.moonshot.cn" -- hermes

# Add extra directories to scan
wsl-proxy --scan-dir /mnt/d/MyProxy -- hermes
```

## How It Works

```
┌──────────────────────────────────────────────────────┐
│ 1. Scan Windows proxy configs via /mnt/ mounts       │
│    ChromeGo/  Clash Verge/  v2rayN/  sing-box/ ...   │
│    ↓                                                 │
│ 2. Extract ports from config files                   │
│    mixed-port: 7890  "port": 1080  listen IP:PORT    │
│    ↓                                                 │
│ 3. Probe each candidate port                         │
│    curl --head google.com --proxy 127.0.0.1:PORT     │
│    ↓                                                 │
│ 4. Export proxy env vars + launch your command       │
│    https_proxy + no_proxy → exec command             │
└──────────────────────────────────────────────────────┘
```

- **No Allow LAN needed** — uses WSL2's built-in localhost forwarding
- **No manual port entry** — scans 7+ config formats
- **Works with any CLI tool** — not tied to a specific app

## Supported Proxy Tools

| Tool | Config Path | Default Port |
|------|-------------|-------------|
| Clash Meta / Clash Verge | `*.yaml` | 7890 |
| ChromeGo | `clash.meta/`, `Xray/`, `hysteria/`, ... | 7890, 1080 |
| v2rayN | `config.json` | 1080, 10809 |
| sing-box | `config.json` | 1080 |
| Hiddify | `config.json` | 1080 |
| hysteria / hysteria2 | `config.json` | 1080 |
| Xray | `config.json` | 1080 |
| naiveproxy / juicity | `config.json` | 1080 |

## Configuration

Environment variables (all optional):

```bash
# Extra directories to scan (colon-separated)
export PROXY_SCAN_DIRS="/mnt/d/my-proxy:/mnt/c/another"

# Hosts to bypass proxy (comma-separated)
export PROXY_NO_PROXY="api.deepseek.com,api.openai.com"

# Fallback ports if config scanning finds nothing
export PROXY_FALLBACK_PORTS="7890 1080 10809 2080"
```

## Real-World Example: Hermes Agent

The `examples/` directory contains a Hermes wrapper that uses `no_proxy` to
bypass China-accessible APIs while routing everything else through the proxy:

```bash
# examples/hermes-wrapper.sh
wsl-proxy-launcher.sh \
    --no-proxy "api.deepseek.com,api.moonshot.cn" \
    --scan-dir "/mnt/d/tools/ChromeGo/ChromeGo" \
    -- hermes "$@"
```

DeepSeek → direct (fast) · Agnes/OpenAI → via proxy (unblocked)

## Requirements

- WSL2 (Windows 10/11)
- A Windows proxy tool running on `127.0.0.1`
- `curl` (pre-installed on most WSL distributions)

## Comparison

| | Manual `.bashrc` | WSL2 `autoProxy` | **This tool** |
|---|---|---|---|
| Port auto-detect | ❌ | ✅ | ✅ |
| Works without Allow LAN | ✅ | ❌ | ✅ |
| Multi-tool support | ❌ | ❌ | ✅ |
| `no_proxy` exclusions | Manual | Manual | Built-in |
| Works on Win10 | ✅ | ❌ (Win11 only) | ✅ |

## License

MIT
