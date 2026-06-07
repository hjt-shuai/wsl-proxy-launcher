# wsl-proxy-launcher

**Auto-detect Windows proxy from WSL2 and launch any command with it.**

You run a proxy tool on Windows (Clash, v2rayN, sing-box, Hiddify...). You want
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
export PROXY_SCAN_DIRS="/mnt/d/tools/clash:/mnt/c/Users/$USER/AppData/Roaming/v2rayN"
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
│    Clash Verge/  v2rayN/  sing-box/  Hiddify/  ...      │
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

## WSL AI Agents & the GFW Problem

If you use AI coding agents in WSL2 (Hermes, Claude Code, Codex, OpenHands,
etc.), you have probably hit this:

```
🔁 Transient APIConnectionError — Connection error
❌ API failed after 3 retries
```

### Why this happens

The AI ecosystem's API landscape splits into two categories from China:

| Category | APIs | GFW Status |
|----------|------|------------|
| **Blocked** | `api.openai.com`, `api.anthropic.com`, `apihub.agnes-ai.com`, `api.groq.com` | ❌ Direct connection fails (TCP RST / timeout) |
| **Accessible** | `api.deepseek.com`, `api.moonshot.cn`, `dashscope.aliyuncs.com` | ✅ Works from within China |

Most AI agents connect to multiple providers. Claude Code talks to Anthropic.
Hermes talks to DeepSeek **and** Agnes. Codex talks to OpenAI. When your agent
switches models mid-session, it needs to route some requests through a proxy and
others directly — all within the same process.

### The standard approaches and their limits

#### Approach 1: Set `https_proxy` globally

```bash
# ~/.bashrc
export https_proxy=http://127.0.0.1:7890
```

**Problem:** Everything goes through the proxy — even `api.deepseek.com`.
DeepSeek V3 responds in <2s from China without a proxy, but through one it's
slower and less reliable. Plus, if the proxy is down, **nothing** works.

#### Approach 2: WSL2 `autoProxy=true`

```ini
# .wslconfig
[experimental]
autoProxy=true
networkingMode=mirrored
```

**Problem:** Requires Windows 11 22H2+. Requires your proxy to listen on
`0.0.0.0` (Allow LAN). Many proxy tools default to
`allow-lan: false` for security. Also, you can't control **which** hosts go
through the proxy — it copies Windows' system proxy setting, which is
all-or-nothing.

#### Approach 3: `wsl-proxy-launcher` (this tool)

```bash
wsl-proxy --no-proxy "api.deepseek.com,api.moonshot.cn" -- hermes
```

**How it solves the problem:**

```
                   ┌──────────────────────────────┐
                   │       Hermes / Claude Code    │
                   │    (running in WSL2 process)  │
                   └──────────┬───────────────────┘
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
        api.deepseek.com  api.anthropic.com  apihub.agnes-ai.com
              │               │               │
        no_proxy skips   https_proxy      https_proxy
        → DIRECT (fast)  → 127.0.0.1:7890 → 127.0.0.1:7890
                         → Windows proxy  → Windows proxy
                         → Internet       → Internet ✅
```

Each request takes the optimal path:
- **China APIs** → Direct, <200ms latency
- **Foreign APIs** → Auto-routed through whatever proxy tool is active
- **Proxy tool offline** → China APIs still work, foreign APIs fail gracefully

### Quick setup for common agents

```bash
# Hermes — DeepSeek (direct) + Agnes (proxy)
alias hermes='wsl-proxy --no-proxy "api.deepseek.com,api.moonshot.cn" -- hermes'

# Claude Code — Anthropic API is fully blocked
alias claude='wsl-proxy claude'

# Codex / OpenAI Codex CLI
alias codex='wsl-proxy codex'

# OpenHands / OpenDevin
alias openhands='wsl-proxy python -m openhands'

# Aider
alias aider='wsl-proxy aider'

# Generic: proxy everything except China LLM APIs
wsl-proxy --no-proxy "api.deepseek.com,api.moonshot.cn,dashscope.aliyuncs.com,api.siliconflow.cn" \
    -- your-command
```

### Why WSL2 instead of Windows-native?

Many AI agents are built Unix-first. Hermes, Claude Code, Aider, and OpenHands
all assume a POSIX shell, `/tmp`, and Unix file permissions. Running them
natively on Windows often means fighting path issues, shell compatibility, and
tool execution errors. WSL2 gives you a real Linux environment with full access
to your Windows filesystem (`/mnt/c/`, `/mnt/d/`) — and now, with this script,
seamless access to your Windows proxy too.

## Supported Proxy Tools

Scans these Windows proxy tools automatically:

| Tool | Config Location | Default Port(s) |
|------|----------------|-----------------|
| Clash Meta / Clash Verge | `~/.config/clash-verge/`, `AppData/` | 7890 |
| v2rayN | `AppData/Roaming/v2rayN/` | 1080, 10809 |
| sing-box | `~/.config/sing-box/` | 1080 |
| Hiddify | `AppData/Roaming/hiddify/` | 1080 |

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
    --scan-dir "/mnt/d/tools/clash" \
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
