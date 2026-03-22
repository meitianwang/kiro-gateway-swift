<div align="center">

# Kiro Gateway

**Proxy gateway for Kiro API — use free Claude models with any client**

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![Python 3.10+](https://img.shields.io/badge/python-3.10+-blue.svg)](https://www.python.org/downloads/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.100+-green.svg)](https://fastapi.tiangolo.com/)
[![macOS](https://img.shields.io/badge/macOS-13.0+-black.svg)](https://www.apple.com/macos/)

Use Claude models from Kiro with Claude Code, Cursor, Cline, Roo Code, Kilo Code, OpenCode, Codex, Continue, LangChain, and any OpenAI/Anthropic compatible tool.

[Download macOS App](https://github.com/meitianwang/kiro-gateway-swift/releases/latest) · [Quick Start](#-quick-start) · [Configuration](#%EF%B8%8F-configuration)

English | [中文](README_CN.md)

</div>

---

## Table of Contents

- [macOS App](#-macos-app)
- [Available Models](#-available-models)
- [Core Features](#-core-features)
- [Quick Start](#-quick-start)
- [Configuration](#%EF%B8%8F-configuration)
- [Claude Code Integration](#-claude-code-integration)
- [API Reference](#-api-reference)
- [Advanced Features](#-advanced-features)
- [Building from Source](#%EF%B8%8F-building-from-source)
- [License](#-license)

---

## macOS App

Native SwiftUI app with one-click setup. No terminal needed.

Download the `.dmg` from [Releases](https://github.com/meitianwang/kiro-gateway-swift/releases/latest), drag to Applications, and launch.

### Dashboard

- Displays API address, key, port and other connection info with one-click copy
- Browse available models with live refresh
- Generate cURL examples in both OpenAI and Anthropic formats
- One-click write / restore Claude Code config (custom Opus, Sonnet, Haiku model mappings)

### Request Logs

- Real-time display of all API requests (method, path, status code, model, duration)
- Text search and status filtering (all / success / error)
- Click to expand request details: message count, tool count, system prompt preview, recent messages
- Copy full request JSON for debugging

### Runtime Logs

- Real-time stdout/stderr output from the Python backend
- Clear logs button

### Settings

- Visual configuration of all parameters: credentials, proxy, timeouts, debug mode, etc.
- Changes auto-saved to `~/.kiro-gateway/.env`
- Start / stop / restart gateway from menu bar

### Process Management

- Auto-detects system Python (homebrew, pyenv, system paths)
- Creates virtual environment on first launch (`~/.kiro-gateway/venv/`) and installs dependencies
- Health checks every 2 seconds, auto-restart on crash

---

## Available Models

> Model availability depends on your Kiro tier (free/paid).

| Model | Description |
|-------|-------------|
| Claude Sonnet 4.5 | Balanced performance. Great for coding and general tasks |
| Claude Haiku 4.5 | Fast. Good for quick responses and simple tasks |
| Claude Opus 4.5 / 4.6 | Most capable. May require paid tier |
| Claude Sonnet 4 / 4.6 | Previous generation, still reliable |
| Claude 3.7 Sonnet | Legacy, backward compatibility |
| DeepSeek-V3.2 | Open MoE (685B/37B active) |
| MiniMax M2.1 / M2.5 | Open MoE (230B/10B active) |
| Qwen3-Coder-Next | Open MoE (80B/3B active), coding-focused |

### Smart Model Resolution

The gateway has a 4-layer model resolution pipeline — no need to remember exact model IDs:

1. **Alias resolution** — Custom name mappings (e.g., `auto-kiro` → `auto`)
2. **Format normalization** — `claude-haiku-4-5`, `claude-haiku-4.5`, `claude-haiku-4-5-20251001` all work
3. **Dynamic cache** — Models from Kiro API with TTL-based auto-refresh
4. **Hidden models** — Models not in the API list but still functional (e.g., `claude-3.7-sonnet`)
5. **Pass-through** — Unknown models forwarded to Kiro as-is

---

## Core Features

### Dual Protocol Support

| Protocol | Endpoint | Use Cases |
|----------|----------|-----------|
| OpenAI | `/v1/chat/completions` | Cursor, Continue, LangChain, OpenAI SDK, etc. |
| Anthropic | `/v1/messages` | Claude Code, Cline, Anthropic SDK, etc. |

Both protocols support streaming and non-streaming responses with automatic format conversion.

### Streaming

- Full SSE (Server-Sent Events) streaming
- First token timeout detection: auto-cancel and retry if threshold exceeded (default 15s, max 3 retries)
- Streaming read timeout: max wait between chunks (default 300s)
- Per-request HTTP clients for streaming to prevent connection leaks (CLOSE_WAIT)
- Shared connection pool for non-streaming requests

### Extended Thinking (Fake Reasoning)

Injects `<thinking_mode>enabled</thinking_mode>` tags into requests to enable model reasoning. The `<thinking>` blocks in responses are parsed and converted to OpenAI-compatible `reasoning_content` format.

4 handling modes:

| Mode | Description |
|------|-------------|
| `as_reasoning_content` | Extract to `reasoning_content` field (recommended, OpenAI-compatible) |
| `remove` | Strip reasoning completely, return only final answer |
| `pass` | Keep original tags as-is |
| `strip_tags` | Remove tags but keep reasoning content inline |

The parser uses a finite state machine supporting `<thinking>`, `<think>`, `<reasoning>`, `<thought>` tag formats.

### Truncation Recovery

When Kiro API truncates large responses (e.g., long tool calls), the gateway auto-injects synthetic messages:

- Tool call truncated → injects `tool_result` error message
- Content truncated → injects user message explaining the situation

The model adapts its strategy automatically (e.g., splitting files, smaller operations) without manual intervention.

### Vision

Image input support with automatic base64 encoding and URL handling, compatible with both OpenAI and Anthropic image formats.

### Tool Calling

Full function calling / tool use support for both streaming and non-streaming. Automatic format conversion between OpenAI and Anthropic tool call formats.

Long tool descriptions are automatically handled: descriptions exceeding the threshold (default 10,000 chars) are moved to the system prompt to save tokens.

### Token Management

- Token counting via tiktoken (cl100k_base) with Claude correction factor of 1.15
- Auto-refresh before expiration, thread-safe
- Multiple token sources supported (Kiro IDE, AWS SSO, kiro-cli)

### Retry & Error Handling

| Status Code | Strategy |
|-------------|----------|
| 403 | Auto-refresh token and retry |
| 429 | Exponential backoff |
| 5xx | Exponential backoff |
| Timeout | Exponential backoff |

### Error Enhancement

Translates cryptic Kiro API error codes into readable messages:

- `CONTENT_LENGTH_EXCEEDS_THRESHOLD` → "Model context limit reached"
- `MONTHLY_REQUEST_COUNT` → "Monthly request limit exceeded"

Network errors are auto-classified (DNS, connection refused, timeout, SSL, proxy, etc.) with troubleshooting suggestions.

### Debugging & Observability

| Feature | Description |
|---------|-------------|
| Structured logging | loguru-based, supports TRACE / DEBUG / INFO / WARNING / ERROR / CRITICAL |
| Debug mode | `off` / `errors` (failed requests only) / `all` (every request) |
| Request history | In-memory ring buffer (last 50), powers macOS app UI |
| Health check | `GET /health` returns service status and timestamp |
| Token usage | Responses include token usage statistics |

### VPN / Proxy Support

For restricted networks (GFW, corporate firewalls):

```env
# HTTP proxy
VPN_PROXY_URL=http://127.0.0.1:7890

# SOCKS5 proxy
VPN_PROXY_URL=socks5://127.0.0.1:1080

# With authentication
VPN_PROXY_URL=http://user:pass@proxy.company.com:8080
```

---

## Quick Start

### macOS App (Recommended)

1. Download `KiroGateway.dmg` from [Releases](https://github.com/meitianwang/kiro-gateway-swift/releases/latest)
2. Drag to Applications
3. Launch, configure credentials in Settings
4. Click Start

### Python

```bash
git clone https://github.com/meitianwang/kiro-gateway-swift.git
cd kiro-gateway
pip install -r requirements.txt
cp .env.example .env
# Edit .env with your credentials
python main.py
```

Server starts at `http://localhost:9001` by default.

### Docker

```bash
git clone https://github.com/meitianwang/kiro-gateway-swift.git
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
  ghcr.io/meitianwang/kiro-gateway-swift:latest
```

</details>

---

## Configuration

### Authentication

Four authentication methods are supported — choose one:

#### Option 1: Kiro IDE Credentials File

```env
KIRO_CREDS_FILE="~/.aws/sso/cache/kiro-auth-token.json"
PROXY_API_KEY="your-password"
```

#### Option 2: Refresh Token

```env
REFRESH_TOKEN="your_kiro_refresh_token"
PROXY_API_KEY="your-password"
PROFILE_ARN="arn:aws:codewhisperer:us-east-1:..."
KIRO_REGION="us-east-1"
```

#### Option 3: AWS SSO Cache

```env
KIRO_CREDS_FILE="~/.aws/sso/cache/your-sso-cache-file.json"
PROXY_API_KEY="your-password"
```

#### Option 4: kiro-cli SQLite Database

```env
KIRO_CLI_DB_FILE="~/.local/share/kiro-cli/data.sqlite3"
PROXY_API_KEY="your-password"
```

### Full Configuration Reference

```env
# ===== Server =====
SERVER_HOST=127.0.0.1           # 0.0.0.0 for LAN access
SERVER_PORT=9001

# ===== Proxy Password =====
PROXY_API_KEY="your-password"   # Your own password, used by clients to connect

# ===== Network Proxy =====
VPN_PROXY_URL=                  # Leave empty for direct connection, supports http:// and socks5://

# ===== Timeouts & Retries =====
FIRST_TOKEN_TIMEOUT=15          # First token timeout (seconds)
FIRST_TOKEN_MAX_RETRIES=3       # First token timeout retry count
STREAMING_READ_TIMEOUT=300      # Streaming read timeout (seconds)

# ===== Extended Thinking =====
FAKE_REASONING=true             # Enable fake reasoning
FAKE_REASONING_MAX_TOKENS=4000  # Max reasoning tokens
FAKE_REASONING_HANDLING=as_reasoning_content  # Handling mode

# ===== Truncation Recovery =====
TRUNCATION_RECOVERY=true        # Auto truncation recovery

# ===== Tool Descriptions =====
TOOL_DESCRIPTION_MAX_LENGTH=10000  # Move long descriptions to system prompt

# ===== Model Configuration =====
HIDDEN_MODELS=                  # Hidden models (not in API list but usable)
MODEL_ALIASES=                  # Custom model aliases
HIDDEN_FROM_LIST=               # Hide from /v1/models response

# ===== Logging & Debug =====
LOG_LEVEL=INFO                  # TRACE / DEBUG / INFO / WARNING / ERROR / CRITICAL
DEBUG_MODE=off                  # off / errors / all
```

### Configuration Priority

| Type | Priority (high → low) |
|------|----------------------|
| Server config | CLI args > env vars > defaults |
| Credentials | SQLite DB > JSON file > env vars |
| Model resolution | Aliases > normalization > dynamic cache > hidden models > pass-through |

---

## Claude Code Integration

### Auto-Configure (macOS App)

In the dashboard's Claude Code section:

1. Select the actual models for Opus, Sonnet, and Haiku
2. Click "Write Config" — writes gateway address and model mappings to `~/.claude/settings.json`
3. Click "Restore Config" — restores the original configuration from before writing (backup stored at `~/.kiro-gateway/settings.env.backup.json`)

Write only modifies the `env` field — your existing settings (`model`, `enabledPlugins`, etc.) are preserved.

### Manual Configuration

Edit `~/.claude/settings.json` and add the `env` field:

```json
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "your-password",
    "ANTHROPIC_BASE_URL": "http://localhost:9001",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-opus-4.6",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "claude-sonnet-4.6",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "claude-haiku-4.5",
    "API_TIMEOUT_MS": "3000000",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1"
  }
}
```

---

## API Reference

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Health check with status and timestamp |
| `/v1/models` | GET | List available models (cached, with hidden models and aliases) |
| `/v1/chat/completions` | POST | OpenAI Chat Completions API |
| `/v1/messages` | POST | Anthropic Messages API |
| `/claude-config` | GET | Read current Claude Code configuration |
| `/claude-config` | POST | Write Claude Code model configuration |
| `/request-history/{rid}` | GET | Get request summary (used by macOS app) |
| `/request-history/{rid}/full` | GET | Get full request details |

### Authentication

- OpenAI format: `Authorization: Bearer your-password`
- Anthropic format: `x-api-key: your-password`

Both work for all endpoints.

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

## Advanced Features

### Model Aliases

Custom model name mappings:

```env
MODEL_ALIASES={"my-model": "claude-sonnet-4.5", "auto-kiro": "auto"}
```

### Hidden Models

Add models not in the Kiro API list but still functional:

```env
HIDDEN_MODELS=claude-3.7-sonnet
```

### Hide from List

Hide specific models from the `/v1/models` response (models remain usable by name):

```env
HIDDEN_FROM_LIST=some-model-id
```

### Fallback Model List

Hardcoded model list used when Kiro API is unreachable, ensuring `/v1/models` always responds.

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
hdiutil create -volname "KiroGateway" \
  -srcfolder KiroGateway/dist/KiroGateway.app \
  -ov -format UDZO \
  KiroGateway/dist/KiroGateway.dmg
```

### Docker

```bash
docker build -t kiro-gateway .
```

Docker image is based on Python 3.10-slim, runs as non-root user, with built-in health checks.

---

## Project Structure

```
kiro-gateway/
├── main.py                    # FastAPI app entry, middleware and route registration
├── kiro/
│   ├── config.py              # Configuration system (env vars, CLI args, defaults)
│   ├── auth.py                # Multi-source auth (Kiro IDE, AWS SSO, SQLite)
│   ├── routes_openai.py       # OpenAI-compatible API routes
│   ├── routes_anthropic.py    # Anthropic-compatible API routes
│   ├── routes_claude_config.py # Claude Code config API
│   ├── model_resolver.py      # 4-layer model resolution pipeline
│   ├── cache.py               # Model info cache (TTL-based)
│   ├── converters_openai.py   # OpenAI format converter
│   ├── converters_anthropic.py # Anthropic format converter
│   ├── converters_core.py     # Unified internal format conversion
│   ├── streaming_openai.py    # OpenAI SSE streaming
│   ├── streaming_anthropic.py # Anthropic SSE streaming
│   ├── streaming_core.py      # Unified streaming event parsing
│   ├── thinking_parser.py     # Extended thinking tag parser (FSM)
│   ├── truncation_recovery.py # Truncation recovery (synthetic message injection)
│   ├── http_client.py         # HTTP client (retry, backoff, connection management)
│   ├── tokenizer.py           # Token counting (tiktoken)
│   ├── kiro_errors.py         # Kiro error code enhancement
│   ├── network_errors.py      # Network error classification & troubleshooting
│   ├── request_history.py     # Request history ring buffer
│   ├── debug_middleware.py    # Debug logging middleware
│   └── debug_logger.py        # Debug log recorder
├── KiroGateway/               # macOS SwiftUI app
│   ├── KiroGateway/
│   │   ├── KiroGatewayApp.swift
│   │   ├── ContentView.swift
│   │   ├── DashboardView.swift
│   │   ├── RequestLogView.swift
│   │   ├── LogView.swift
│   │   ├── SettingsView.swift
│   │   ├── GatewayService.swift  # Python process management
│   │   ├── ConfigManager.swift   # Config persistence
│   │   └── MenuBarView.swift
│   └── build.sh               # Build script
├── Dockerfile
├── docker-compose.yml
├── requirements.txt
├── start.sh                   # Startup script
└── .env.example               # Configuration template
```

---

## License

[AGPL-3.0](LICENSE). You can use, modify, and distribute this software. Network use counts as distribution — if you deploy a modified version as a service, you must share the source.

## Disclaimer

Not affiliated with Amazon Web Services, Anthropic, or Kiro IDE. Use at your own risk.

---

<div align="center">

Made with ❤️ by [@meitianwang](https://github.com/meitianwang)

</div>
