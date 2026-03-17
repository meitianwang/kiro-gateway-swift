<div align="center">

# Kiro Gateway

**Proxy gateway for Kiro API — use free Claude models with any client**

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![Python 3.10+](https://img.shields.io/badge/python-3.10+-blue.svg)](https://www.python.org/downloads/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.100+-green.svg)](https://fastapi.tiangolo.com/)
[![macOS](https://img.shields.io/badge/macOS-13.0+-black.svg)](https://www.apple.com/macos/)

Use Claude models from Kiro with Claude Code, Cursor, Cline, Roo Code, Kilo Code, OpenCode, Codex, Continue, LangChain, and any OpenAI/Anthropic compatible tool.

[Download macOS App](https://github.com/Jwadow/kiro-gateway/releases/latest) · [Quick Start](#-quick-start) · [Configuration](#%EF%B8%8F-configuration)

English | [中文](README_CN.md)

</div>

---

## macOS App

Native SwiftUI app with one-click setup. No terminal needed.

- Start/stop/restart gateway from menu bar
- Configure credentials, proxy, timeouts visually
- View request logs and runtime logs in real-time
- One-click Claude Code config (`~/.claude/settings.json`)
- Browse available models, copy cURL examples

Download the `.dmg` from [Releases](https://github.com/Jwadow/kiro-gateway/releases/latest), drag to Applications, and launch.

---

## Available Models

> Model availability depends on your Kiro tier (free/paid).

| Model | Description |
|-------|-------------|
| Claude Sonnet 4.5 | Balanced performance. Great for coding and general tasks |
| Claude Haiku 4.5 | Fast. Good for quick responses and simple tasks |
| Claude Opus 4.5 / 4.6 | Most capable. May require paid tier |
| Claude Sonnet 4 | Previous generation, still reliable |
| Claude 3.7 Sonnet | Legacy, backward compatibility |
| DeepSeek-V3.2 | Open MoE (685B/37B active) |
| MiniMax M2.1 | Open MoE (230B/10B active) |
| Qwen3-Coder-Next | Open MoE (80B/3B active), coding-focused |

Smart model resolution: `claude-sonnet-4-5`, `claude-sonnet-4.5`, `claude-sonnet-4-5-20250929` all work.

---

## Features

| Feature | Description |
|---------|-------------|
| OpenAI-compatible API | `/v1/chat/completions` — works with any OpenAI client |
| Anthropic-compatible API | `/v1/messages` — native Anthropic endpoint |
| macOS App | Native SwiftUI GUI with menu bar control |
| Claude Code Integration | One-click `~/.claude/settings.json` configuration |
| Extended Thinking | Reasoning support |
| Vision | Image input support |
| Tool Calling | Function calling support |
| Streaming | Full SSE streaming |
| VPN/Proxy | HTTP/SOCKS5 proxy for restricted networks |
| Retry Logic | Auto retry on 403, 429, 5xx |
| Token Management | Auto refresh before expiration |

---

## Quick Start

### macOS App (Recommended)

1. Download `KiroGateway.dmg` from [Releases](https://github.com/Jwadow/kiro-gateway/releases/latest)
2. Drag to Applications
3. Launch, configure credentials in Settings
4. Click Start

### Python

```bash
git clone https://github.com/Jwadow/kiro-gateway.git
cd kiro-gateway
pip install -r requirements.txt
cp .env.example .env
# Edit .env with your credentials
python main.py
```

Server starts at `http://localhost:9001` by default.

### Docker

```bash
git clone https://github.com/Jwadow/kiro-gateway.git
cd kiro-gateway
cp .env.example .env
# Edit .env
docker-compose up -d
```

<details>
<summary>Docker run (without compose)</summary>

```bash
docker run -d \
  -p 9001:9001 \
  -e PROXY_API_KEY="your-password" \
  -e REFRESH_TOKEN="your_refresh_token" \
  --name kiro-gateway \
  ghcr.io/jwadow/kiro-gateway:latest
```

</details>

---

## Configuration

Four authentication methods are supported:

### Option 1: Kiro IDE Credentials File

```env
KIRO_CREDS_FILE="~/.aws/sso/cache/kiro-auth-token.json"
PROXY_API_KEY="your-password"
```

### Option 2: Refresh Token

```env
REFRESH_TOKEN="your_kiro_refresh_token"
PROXY_API_KEY="your-password"
PROFILE_ARN="arn:aws:codewhisperer:us-east-1:..."
KIRO_REGION="us-east-1"
```

### Option 3: AWS SSO Cache

```env
KIRO_CREDS_FILE="~/.aws/sso/cache/your-sso-cache-file.json"
PROXY_API_KEY="your-password"
```

### Option 4: kiro-cli SQLite Database

```env
KIRO_CLI_DB_FILE="~/.local/share/kiro-cli/data.sqlite3"
PROXY_API_KEY="your-password"
```

### Additional Settings

```env
# Server
SERVER_HOST=127.0.0.1      # 0.0.0.0 for LAN access
SERVER_PORT=9001

# Proxy (leave empty for direct connection)
VPN_PROXY_URL=http://127.0.0.1:7890

# Timeouts (seconds)
FIRST_TOKEN_TIMEOUT=15
FIRST_TOKEN_MAX_RETRIES=3
STREAMING_READ_TIMEOUT=300

# Fake Reasoning
FAKE_REASONING=true
FAKE_REASONING_MAX_TOKENS=4000

# Debug
DEBUG_MODE=off              # off / errors / all
LOG_LEVEL=INFO
```

---

## Claude Code Setup

The macOS app can auto-configure Claude Code. Or manually edit `~/.claude/settings.json`:

```json
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "your-password",
    "ANTHROPIC_BASE_URL": "http://localhost:9001",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-opus-4.6",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "claude-sonnet-4.6",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "claude-sonnet-4.6",
    "API_TIMEOUT_MS": "3000000",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1"
  }
}
```

---

## API Reference

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check |
| `/v1/models` | GET | List available models |
| `/v1/chat/completions` | POST | OpenAI Chat Completions |
| `/v1/messages` | POST | Anthropic Messages |

### Examples

<details>
<summary>OpenAI cURL</summary>

```bash
curl http://localhost:9001/v1/chat/completions \
  -H "Authorization: Bearer your-password" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-sonnet-4-5",
    "messages": [{"role": "user", "content": "Hello!"}],
    "stream": true
  }'
```

</details>

<details>
<summary>Anthropic cURL</summary>

```bash
curl http://localhost:9001/v1/messages \
  -H "x-api-key: your-password" \
  -H "anthropic-version: 2023-06-01" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-sonnet-4-5",
    "max_tokens": 1024,
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

</details>

<details>
<summary>Python (OpenAI SDK)</summary>

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:9001/v1",
    api_key="your-password"
)

response = client.chat.completions.create(
    model="claude-sonnet-4-5",
    messages=[{"role": "user", "content": "Hello!"}],
    stream=True
)

for chunk in response:
    if chunk.choices[0].delta.content:
        print(chunk.choices[0].delta.content, end="")
```

</details>

<details>
<summary>Python (Anthropic SDK)</summary>

```python
import anthropic

client = anthropic.Anthropic(
    api_key="your-password",
    base_url="http://localhost:9001"
)

response = client.messages.create(
    model="claude-sonnet-4-5",
    max_tokens=1024,
    messages=[{"role": "user", "content": "Hello!"}]
)
print(response.content[0].text)
```

</details>

---

## Building from Source

### macOS App

```bash
cd KiroGateway
bash build.sh
# Output: dist/KiroGateway.app
```

Requires Xcode 15+ and Python 3.10+. The build script bundles Python dependencies into the app.

### DMG

```bash
hdiutil create -volname "KiroGateway" -srcfolder KiroGateway/dist/KiroGateway.app -ov -format UDZO KiroGateway/dist/KiroGateway.dmg
```

---

## VPN/Proxy Support

For users in restricted networks:

```env
# HTTP proxy
VPN_PROXY_URL=http://127.0.0.1:7890

# SOCKS5 proxy
VPN_PROXY_URL=socks5://127.0.0.1:1080

# With authentication
VPN_PROXY_URL=http://user:pass@proxy.company.com:8080
```

---

## License

[AGPL-3.0](LICENSE). You can use, modify, and distribute this software. Network use counts as distribution — if you deploy a modified version as a service, you must share the source.

## Disclaimer

Not affiliated with Amazon Web Services, Anthropic, or Kiro IDE. Use at your own risk.

---

<div align="center">

Made with ❤️ by [@Jwadow](https://github.com/jwadow)

</div>
