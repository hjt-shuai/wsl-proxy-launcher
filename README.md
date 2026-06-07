# wsl-proxy-launcher

**Auto-detect Windows proxy from WSL2 and launch any command with it.**

You run a proxy tool on Windows (Clash, v2rayN, ChromeGo, sing-box...). You want
commands in WSL2 to automatically use that proxy. This script scans your proxy
config files, finds the active port, sets `https_proxy`, and launches your
command — all with zero manual configuration.

## Why?

The problem every WSL2 user in China hits:

```
WSL2 can ping Windows 127.0.0.1   ✅  (localhost forwarding)
But tools don't know WHICH port   ❌  (Clash=7890? sing-box=1080? Xray=10809?)
```

You switch between proxy tools. Ports change. Config files move. This script
handles all of that automatically.

## Quick Start

```bash
# Option 1: One-command install
curl -fsSL https://raw.githubusercontent.com/hjt-shuai/wsl-proxy-launcher/main/setup.sh | bash

# Option 2: Clone and install
git clone https://github.com/hjt-shuai/wsl-proxy-launcher.git
cd wsl-proxy-launcher && bash setup.sh
```

After install, restart your shell or run `source ~/.bashrc`. You now have a
`wsl-proxy` command.

## Usage

### Basic

```bash
# Wrap any command — proxy is auto-detected
wsl-proxy curl https://www.google.com
wsl-proxy python my_script.py
wsl-proxy npm install
wsl-proxy hermes
```

### Exclude hosts from proxy (`no_proxy`)

Some APIs are accessible from China without a proxy. Exclude them so they go
direct (faster):

```bash
wsl-proxy --no-proxy "api.deepseek.com,api.moonshot.cn" -- hermes
```

### Add custom scan directories

If your proxy tool is in a non-standard location:

```bash
wsl-proxy --scan-dir /mnt/d/MyProxy --scan-dir /mnt/e/Another -- curl google.com
```

### Persistent configuration

Add to `~/.bashrc` for defaults that apply to all `wsl-proxy` calls:

```bash
export PROXY_NO_PROXY="api.deepseek.com,api.moonshot.cn"
export PROXY_SCAN_DIRS="/mnt/d/tools/ChromeGo/ChromeGo"
```

### Per-tool aliases

Set up aliases for different AI agents with different `no_proxy` needs:

```bash
# ~/.bashrc
alias hermes='wsl-proxy --no-proxy "api.deepseek.com,api.moonshot.cn" -- hermes'
alias claude='wsl-proxy claude'
alias codex='wsl-proxy codex'
```

## How It Works

```
┌─────────────────────────────────────────────────────────┐
│ 1. SCAN — Read proxy configs from Windows via /mnt/     │
│    ChromeGo/  Clash Verge/  v2rayN/  sing-box/  ...     │
│    Extracts ports from YAML and JSON config files        │
│    ↓                                                    │
│ 2. PROBE — Test each candidate port                     │
│    curl --head google.com --proxy 127.0.0.1:PORT        │
│    First port that responds = active proxy               │
│    ↓                                                    │
│ 3. SET — Export environment variables                   │
│    https_proxy=http://127.0.0.1:$PORT                   │
│    no_proxy=<your excluded hosts>                       │
│    ↓                                                    │
│ 4. LAUNCH — exec your command                           │
│    Proxy env vars inherited by the child process         │
└─────────────────────────────────────────────────────────┘
```

Key design decisions:
- **No `Allow LAN` needed** — Uses WSL2's built-in localhost forwarding to reach
  Windows `127.0.0.1`. Works even when your proxy only listens on `127.0.0.1`.
- **Port probing, not guessing** — Extracting from config files gives candidates,
  but actual `curl` probing determines which is really active.
- **`no_proxy` built-in** — Unlike manually setting `https_proxy` in `.bashrc`,
  this lets you route different hosts differently. DeepSeek goes direct (fast),
  OpenAI goes through proxy (unblocked).

## Supported Proxy Tools

Scans these Windows proxy tools automatically:

| Tool | Config Location | Default Port(s) |
|------|----------------|-----------------|
| Clash Meta / Clash Verge | `~/.config/clash-verge/`, `AppData/` | 7890 |
| ChromeGo | `D:/tools/ChromeGo/` or `C:/tools/ChromeGo/` | 7890, 1080 |
| v2rayN | `AppData/Roaming/v2rayN/` | 1080, 10809 |
| sing-box | `~/.config/sing-box/` | 1080 |
| hysteria / hysteria2 | Part of ChromeGo or standalone | 1080 |
| Xray | Part of ChromeGo or standalone | 1080 |
| Hiddify | `AppData/Roaming/hiddify/` | 1080 |
| naiveproxy / juicity | Part of ChromeGo | 1080 |

Don't see your tool? Add it with `--scan-dir` or `PROXY_SCAN_DIRS`.

## Supported Config Formats

The script understands port declarations in multiple formats:

```yaml
# Clash YAML
mixed-port: 7890
```

```json
// sing-box / Xray JSON
"listen_port": 1080
"port": 1080

// hysteria / naiveproxy / juicity JSON
"listen": "127.0.0.1:1080"
```

**Handles Windows CRLF line endings** — config files on `/mnt/` mounts have
`\r\n`, which would break port extraction. The script strips them.

## Requirements

- **WSL2** (Windows 10 2004+ or Windows 11)
- **curl** (pre-installed on Ubuntu, Debian, etc.)
- **bash** (default WSL shell)
- A Windows proxy tool running on `127.0.0.1`

No `sudo`, no `pip install`, no dependencies beyond what ships with WSL.

## Real-World Examples

### Hermes Agent with mixed models

```bash
#!/usr/bin/env bash
# ~/.hermes/bin/hermes-launcher.sh
exec wsl-proxy-launcher.sh \
    --no-proxy "api.deepseek.com,api.moonshot.cn,dashscope.aliyuncs.com" \
    --scan-dir "/mnt/d/tools/ChromeGo/ChromeGo" \
    -- hermes "$@"
```

- `deepseek-chat` → direct (China, no GFW)
- `agnes-2.0-flash` → via proxy (Cloudflare-blocked)

### Claude Code

```bash
alias claude='wsl-proxy claude'
```

Anthropic API is blocked in China, so everything goes through proxy.

### One-off API calls

```bash
wsl-proxy curl -H "Authorization: Bearer sk-xxx" \
    https://api.openai.com/v1/models
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `No proxy detected` | Your proxy tool isn't running. Start it first, then retry. |
| Proxy found but command fails | Check if the proxy can reach the target: `wsl-proxy curl -I https://target.com` |
| Port extracted but probe fails | Your proxy may have authentication. Currently only supports open proxies. |
| My tool isn't detected | Add `--scan-dir /path/to/tool` or set `PROXY_SCAN_DIRS` |
| WSL can't access `/mnt/d/` | Make sure the drive is mounted: `ls /mnt/d/` in WSL |

## Comparison

| | `.bashrc` manual | WSL2 `autoProxy` | **wsl-proxy-launcher** |
|---|---|---|---|
| Auto-detect port | ❌ | ✅ | ✅ |
| Works without `Allow LAN` | ✅ | ❌ | ✅ |
| Multi-tool support | ❌ | ❌ | ✅ (7+ tools) |
| `no_proxy` exclusions | Manual | Manual | CLI flag + env var |
| Windows 10 support | ✅ | ❌ (Win11 only) | ✅ |
| Zero config after install | ❌ | ❌ | ✅ |

## License

MIT © 2026 hjt-shuai
