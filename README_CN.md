<div align="center">

# Kiro Gateway

**Kiro API 代理网关 — 用免费的 Claude 模型接入任意客户端**

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![Python 3.10+](https://img.shields.io/badge/python-3.10+-blue.svg)](https://www.python.org/downloads/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.100+-green.svg)](https://fastapi.tiangolo.com/)
[![macOS](https://img.shields.io/badge/macOS-13.0+-black.svg)](https://www.apple.com/macos/)

通过 Kiro 使用 Claude 模型，兼容 Claude Code、Cursor、Cline、Roo Code、Kilo Code、OpenCode、Codex、Continue、LangChain 以及任何 OpenAI/Anthropic 兼容工具。

[下载 macOS 应用](https://github.com/Jwadow/kiro-gateway/releases/latest) · [快速开始](#-快速开始) · [配置说明](#%EF%B8%8F-配置说明)

[English](README.md) | 中文

</div>

---

## macOS 应用

原生 SwiftUI 应用，一键启动，无需终端操作。

- 从菜单栏启动/停止/重启网关
- 可视化配置凭证、代理、超时等参数
- 实时查看请求日志和运行日志
- 一键配置 Claude Code（`~/.claude/settings.json`）
- 浏览可用模型，复制 cURL 示例

从 [Releases](https://github.com/Jwadow/kiro-gateway/releases/latest) 下载 `.dmg`，拖入应用程序文件夹即可使用。

---

## 可用模型

> 模型可用性取决于你的 Kiro 套餐（免费/付费）。

| 模型 | 说明 |
|------|------|
| Claude Sonnet 4.5 | 性能均衡，适合编程和通用任务 |
| Claude Haiku 4.5 | 速度快，适合快速响应和简单任务 |
| Claude Opus 4.5 / 4.6 | 最强能力，可能需要付费套餐 |
| Claude Sonnet 4 | 上一代模型，依然可靠 |
| Claude 3.7 Sonnet | 旧版，向后兼容 |
| DeepSeek-V3.2 | 开源 MoE（685B/37B 激活） |
| MiniMax M2.1 | 开源 MoE（230B/10B 激活） |
| Qwen3-Coder-Next | 开源 MoE（80B/3B 激活），编程专用 |

智能模型解析：`claude-sonnet-4-5`、`claude-sonnet-4.5`、`claude-sonnet-4-5-20250929` 均可使用。

---

## 功能特性

| 功能 | 说明 |
|------|------|
| OpenAI 兼容 API | `/v1/chat/completions` — 适配任何 OpenAI 客户端 |
| Anthropic 兼容 API | `/v1/messages` — 原生 Anthropic 端点 |
| macOS 应用 | 原生 SwiftUI 图形界面，菜单栏控制 |
| Claude Code 集成 | 一键配置 `~/.claude/settings.json` |
| 扩展思考 | 推理支持 |
| 视觉能力 | 图片输入支持 |
| 工具调用 | 函数调用支持 |
| 流式输出 | 完整 SSE 流式传输 |
| VPN/代理 | HTTP/SOCKS5 代理，适用于受限网络 |
| 重试逻辑 | 遇到 403、429、5xx 自动重试 |
| Token 管理 | 过期前自动刷新 |

---

## 快速开始

### macOS 应用（推荐）

1. 从 [Releases](https://github.com/Jwadow/kiro-gateway/releases/latest) 下载 `KiroGateway.dmg`
2. 拖入应用程序文件夹
3. 启动后在设置中配置凭证
4. 点击启动

### Python

```bash
git clone https://github.com/Jwadow/kiro-gateway.git
cd kiro-gateway
pip install -r requirements.txt
cp .env.example .env
# 编辑 .env 填入你的凭证
python main.py
```

服务默认启动在 `http://localhost:9001`。

### Docker

```bash
git clone https://github.com/Jwadow/kiro-gateway.git
cd kiro-gateway
cp .env.example .env
# 编辑 .env
docker-compose up -d
```

<details>
<summary>Docker run（不使用 compose）</summary>

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

## 配置说明

支持四种认证方式：

### 方式一：Kiro IDE 凭证文件

```env
KIRO_CREDS_FILE="~/.aws/sso/cache/kiro-auth-token.json"
PROXY_API_KEY="your-password"
```

### 方式二：Refresh Token

```env
REFRESH_TOKEN="your_kiro_refresh_token"
PROXY_API_KEY="your-password"
PROFILE_ARN="arn:aws:codewhisperer:us-east-1:..."
KIRO_REGION="us-east-1"
```

### 方式三：AWS SSO 缓存

```env
KIRO_CREDS_FILE="~/.aws/sso/cache/your-sso-cache-file.json"
PROXY_API_KEY="your-password"
```

### 方式四：kiro-cli SQLite 数据库

```env
KIRO_CLI_DB_FILE="~/.local/share/kiro-cli/data.sqlite3"
PROXY_API_KEY="your-password"
```

### 其他设置

```env
# 服务器
SERVER_HOST=127.0.0.1      # 0.0.0.0 可局域网访问
SERVER_PORT=9001

# 代理（留空则直连）
VPN_PROXY_URL=http://127.0.0.1:7890

# 超时（秒）
FIRST_TOKEN_TIMEOUT=15
FIRST_TOKEN_MAX_RETRIES=3
STREAMING_READ_TIMEOUT=300

# 伪推理
FAKE_REASONING=true
FAKE_REASONING_MAX_TOKENS=4000

# 调试
DEBUG_MODE=off              # off / errors / all
LOG_LEVEL=INFO
```

---

## Claude Code 配置

macOS 应用可自动配置 Claude Code，也可手动编辑 `~/.claude/settings.json`：

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

## API 参考

| 端点 | 方法 | 说明 |
|------|------|------|
| `/health` | GET | 健康检查 |
| `/v1/models` | GET | 列出可用模型 |
| `/v1/chat/completions` | POST | OpenAI Chat Completions |
| `/v1/messages` | POST | Anthropic Messages |

### 示例

<details>
<summary>OpenAI cURL</summary>

```bash
curl http://localhost:9001/v1/chat/completions \
  -H "Authorization: Bearer your-password" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-sonnet-4-5",
    "messages": [{"role": "user", "content": "你好！"}],
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
    "messages": [{"role": "user", "content": "你好！"}]
  }'
```

</details>

<details>
<summary>Python（OpenAI SDK）</summary>

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:9001/v1",
    api_key="your-password"
)

response = client.chat.completions.create(
    model="claude-sonnet-4-5",
    messages=[{"role": "user", "content": "你好！"}],
    stream=True
)

for chunk in response:
    if chunk.choices[0].delta.content:
        print(chunk.choices[0].delta.content, end="")
```

</details>

<details>
<summary>Python（Anthropic SDK）</summary>

```python
import anthropic

client = anthropic.Anthropic(
    api_key="your-password",
    base_url="http://localhost:9001"
)

response = client.messages.create(
    model="claude-sonnet-4-5",
    max_tokens=1024,
    messages=[{"role": "user", "content": "你好！"}]
)
print(response.content[0].text)
```

</details>

---

## 从源码构建

### macOS 应用

```bash
cd KiroGateway
bash build.sh
# 输出: dist/KiroGateway.app
```

需要 Xcode 15+ 和 Python 3.10+。构建脚本会将 Python 依赖打包进应用。

### DMG

```bash
hdiutil create -volname "KiroGateway" -srcfolder KiroGateway/dist/KiroGateway.app -ov -format UDZO KiroGateway/dist/KiroGateway.dmg
```

---

## VPN/代理支持

适用于受限网络环境：

```env
# HTTP 代理
VPN_PROXY_URL=http://127.0.0.1:7890

# SOCKS5 代理
VPN_PROXY_URL=socks5://127.0.0.1:1080

# 带认证的代理
VPN_PROXY_URL=http://user:pass@proxy.company.com:8080
```

---

## 许可证

[AGPL-3.0](LICENSE)。你可以使用、修改和分发本软件。网络使用视为分发——如果你将修改版本部署为服务，必须公开源代码。

## 免责声明

本项目与 Amazon Web Services、Anthropic 或 Kiro IDE 无关。使用风险自负。

---

<div align="center">

Made with ❤️ by [@Jwadow](https://github.com/jwadow)

</div>
