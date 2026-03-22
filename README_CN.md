<div align="center">

# Kiro Gateway

**Kiro API 代理网关 — 用免费的 Claude 模型接入任意客户端**

[![License: AGPL v3](https://img.shields.io/badge/License-AGPL%20v3-blue.svg)](https://www.gnu.org/licenses/agpl-3.0)
[![Python 3.10+](https://img.shields.io/badge/python-3.10+-blue.svg)](https://www.python.org/downloads/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.100+-green.svg)](https://fastapi.tiangolo.com/)
[![macOS](https://img.shields.io/badge/macOS-13.0+-black.svg)](https://www.apple.com/macos/)

通过 Kiro 使用 Claude 模型，兼容 Claude Code、Cursor、Cline、Roo Code、Kilo Code、OpenCode、Codex、Continue、LangChain 以及任何 OpenAI/Anthropic 兼容工具。

[下载 macOS 应用](https://github.com/meitianwang/kiro-gateway-swift/releases/latest) · [快速开始](#-快速开始) · [配置说明](#%EF%B8%8F-配置说明)

[English](README.md) | 中文

</div>

---

## 目录

- [macOS 应用](#-macos-应用)
- [可用模型](#-可用模型)
- [核心功能](#-核心功能)
- [快速开始](#-快速开始)
- [配置说明](#%EF%B8%8F-配置说明)
- [Claude Code 集成](#-claude-code-集成)
- [API 参考](#-api-参考)
- [高级功能](#-高级功能)
- [从源码构建](#%EF%B8%8F-从源码构建)
- [许可证](#-许可证)

---

## macOS 应用

原生 SwiftUI 应用，一键启动，无需终端操作。

从 [Releases](https://github.com/meitianwang/kiro-gateway-swift/releases/latest) 下载 `.dmg`，拖入应用程序文件夹即可使用。

### 仪表盘

- 显示 API 地址、密钥、端口等连接信息，支持一键复制
- 浏览可用模型列表，实时刷新
- 生成 OpenAI / Anthropic 两种格式的 cURL 示例
- 一键写入 / 还原 Claude Code 配置（自定义 Opus、Sonnet、Haiku 模型映射）

### 请求日志

- 实时展示所有 API 请求（方法、路径、状态码、模型、耗时）
- 支持文本搜索和状态过滤（全部 / 成功 / 错误）
- 点击展开查看请求详情：消息数、工具数、System Prompt 预览、最近消息列表
- 复制完整请求 JSON，方便调试

### 运行日志

- 实时显示 Python 后端的 stdout/stderr 输出
- 支持清空日志

### 设置

- 可视化配置所有参数：凭证、代理、超时、调试模式等
- 修改后自动写入 `~/.kiro-gateway/.env`
- 从菜单栏启动 / 停止 / 重启网关

### 进程管理

- 自动检测系统 Python（支持 homebrew、pyenv、系统路径）
- 首次启动自动创建虚拟环境（`~/.kiro-gateway/venv/`）并安装依赖
- 每 2 秒健康检查，崩溃后自动重启

---

## 可用模型

> 模型可用性取决于你的 Kiro 套餐（免费/付费）。

| 模型 | 说明 |
|------|------|
| Claude Sonnet 4.5 | 性能均衡，适合编程和通用任务 |
| Claude Haiku 4.5 | 速度快，适合快速响应和简单任务 |
| Claude Opus 4.5 / 4.6 | 最强能力，可能需要付费套餐 |
| Claude Sonnet 4 / 4.6 | 上一代模型，依然可靠 |
| Claude 3.7 Sonnet | 旧版，向后兼容 |
| DeepSeek-V3.2 | 开源 MoE（685B/37B 激活） |
| MiniMax M2.1 / M2.5 | 开源 MoE（230B/10B 激活） |
| Qwen3-Coder-Next | 开源 MoE（80B/3B 激活），编程专用 |

### 智能模型解析

网关内置 4 层模型解析管道，你不需要记住精确的模型 ID：

1. **别名解析** — 支持自定义名称映射（如 `auto-kiro` → `auto`）
2. **格式归一化** — `claude-haiku-4-5`、`claude-haiku-4.5`、`claude-haiku-4-5-20251001` 均可识别
3. **动态缓存** — 从 Kiro API 获取的模型列表，带 TTL 自动刷新
4. **隐藏模型** — 不在 API 列表中但仍可使用的模型（如 `claude-3.7-sonnet`）
5. **透传** — 未知模型直接转发给 Kiro，由上游决定

---

## 核心功能

### 双协议兼容

| 协议 | 端点 | 适用场景 |
|------|------|----------|
| OpenAI | `/v1/chat/completions` | Cursor、Continue、LangChain、OpenAI SDK 等 |
| Anthropic | `/v1/messages` | Claude Code、Cline、Anthropic SDK 等 |

两种协议均支持流式和非流式响应，网关内部统一转换格式。

### 流式传输

- 完整 SSE（Server-Sent Events）流式输出
- 首 Token 超时检测：超过阈值自动取消并重试（默认 15 秒，最多 3 次）
- 流式读取超时：两个 chunk 之间最大等待时间（默认 300 秒）
- 流式请求使用独立 HTTP 客户端，避免连接泄漏（CLOSE_WAIT）
- 非流式请求使用共享连接池，提升性能

### 扩展思考（伪推理）

通过向请求注入 `<thinking_mode>enabled</thinking_mode>` 标签，让模型输出推理过程。响应中的 `<thinking>` 块会被解析并转换为 OpenAI 兼容的 `reasoning_content` 格式。

支持 4 种处理模式：

| 模式 | 说明 |
|------|------|
| `as_reasoning_content` | 提取为 `reasoning_content` 字段（推荐，OpenAI 兼容） |
| `remove` | 完全移除推理内容，只返回最终答案 |
| `pass` | 保留原始标签，原样透传 |
| `strip_tags` | 移除标签但保留推理内容在正文中 |

解析器使用有限状态机，支持 `<thinking>`、`<think>`、`<reasoning>`、`<thought>` 等多种标签格式。

### 截断恢复

当 Kiro API 截断大型响应（如长工具调用）时，网关自动注入合成消息通知模型：

- 工具调用被截断 → 注入 `tool_result` 错误消息
- 内容被截断 → 注入用户消息说明情况

模型收到通知后会自动调整策略（如拆分文件、缩小操作），无需用户手动干预。

### 视觉能力

支持图片输入，自动处理 base64 编码和图片 URL，兼容 OpenAI 和 Anthropic 两种图片格式。

### 工具调用

完整支持函数调用（Function Calling / Tool Use），流式和非流式均可。自动转换 OpenAI 和 Anthropic 的工具调用格式。

长工具描述自动处理：超过阈值（默认 10000 字符）的工具描述会被移至 System Prompt，避免 Token 浪费。

### Token 管理

- 使用 tiktoken（cl100k_base）进行 Token 计数，Claude 修正系数 1.15
- 自动在过期前刷新 Token，线程安全
- 支持多种 Token 来源（Kiro IDE、AWS SSO、kiro-cli）

### 重试与容错

| 状态码 | 策略 |
|--------|------|
| 403 | 自动刷新 Token 后重试 |
| 429 | 指数退避重试 |
| 5xx | 指数退避重试 |
| 超时 | 指数退避重试 |

### 错误增强

将 Kiro API 的晦涩错误码转换为可读信息：

- `CONTENT_LENGTH_EXCEEDS_THRESHOLD` → "模型上下文长度超限"
- `MONTHLY_REQUEST_COUNT` → "月度请求配额已用完"

网络错误自动分类（DNS、连接拒绝、超时、SSL、代理等），并提供排查建议。

### 调试与可观测性

| 功能 | 说明 |
|------|------|
| 结构化日志 | 基于 loguru，支持 TRACE / DEBUG / INFO / WARNING / ERROR / CRITICAL |
| 调试模式 | `off` / `errors`（仅记录失败请求）/ `all`（记录所有请求） |
| 请求历史 | 内存环形缓冲区（最近 50 条），供 macOS 应用 UI 展示 |
| 健康检查 | `GET /health` 返回服务状态和时间戳 |
| Token 用量 | 响应中包含 Token 使用统计 |

### VPN / 代理支持

适用于受限网络环境（如 GFW、企业内网）：

```env
# HTTP 代理
VPN_PROXY_URL=http://127.0.0.1:7890

# SOCKS5 代理
VPN_PROXY_URL=socks5://127.0.0.1:1080

# 带认证的代理
VPN_PROXY_URL=http://user:pass@proxy.company.com:8080
```

---

## 快速开始

### macOS 应用（推荐）

1. 从 [Releases](https://github.com/meitianwang/kiro-gateway-swift/releases/latest) 下载 `KiroGateway.dmg`
2. 拖入应用程序文件夹
3. 启动后在设置中配置凭证
4. 点击启动

### Python

```bash
git clone https://github.com/meitianwang/kiro-gateway-swift.git
cd kiro-gateway
pip install -r requirements.txt
cp .env.example .env
# 编辑 .env 填入你的凭证
python main.py
```

服务默认启动在 `http://localhost:9001`。

### Docker

```bash
git clone https://github.com/meitianwang/kiro-gateway-swift.git
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
  ghcr.io/meitianwang/kiro-gateway-swift:latest
```

</details>

---

## 配置说明

### 认证方式

支持四种认证方式，选择其中一种即可：

#### 方式一：Kiro IDE 凭证文件

```env
KIRO_CREDS_FILE="~/.aws/sso/cache/kiro-auth-token.json"
PROXY_API_KEY="your-password"
```

#### 方式二：Refresh Token

```env
REFRESH_TOKEN="your_kiro_refresh_token"
PROXY_API_KEY="your-password"
PROFILE_ARN="arn:aws:codewhisperer:us-east-1:..."
KIRO_REGION="us-east-1"
```

#### 方式三：AWS SSO 缓存

```env
KIRO_CREDS_FILE="~/.aws/sso/cache/your-sso-cache-file.json"
PROXY_API_KEY="your-password"
```

#### 方式四：kiro-cli SQLite 数据库

```env
KIRO_CLI_DB_FILE="~/.local/share/kiro-cli/data.sqlite3"
PROXY_API_KEY="your-password"
```

### 完整配置参考

```env
# ===== 服务器 =====
SERVER_HOST=127.0.0.1           # 0.0.0.0 可局域网访问
SERVER_PORT=9001

# ===== 代理密码 =====
PROXY_API_KEY="your-password"   # 你自己设定的密码，客户端连接时使用

# ===== 网络代理 =====
VPN_PROXY_URL=                  # 留空则直连，支持 http:// 和 socks5://

# ===== 超时与重试 =====
FIRST_TOKEN_TIMEOUT=15          # 首 Token 超时（秒）
FIRST_TOKEN_MAX_RETRIES=3       # 首 Token 超时重试次数
STREAMING_READ_TIMEOUT=300      # 流式读取超时（秒）

# ===== 扩展思考 =====
FAKE_REASONING=true             # 启用伪推理
FAKE_REASONING_MAX_TOKENS=4000  # 推理最大 Token 数
FAKE_REASONING_HANDLING=as_reasoning_content  # 处理模式

# ===== 截断恢复 =====
TRUNCATION_RECOVERY=true        # 自动截断恢复

# ===== 工具描述 =====
TOOL_DESCRIPTION_MAX_LENGTH=10000  # 超过此长度的工具描述移至 System Prompt

# ===== 模型配置 =====
HIDDEN_MODELS=                  # 隐藏模型（不在 API 列表但可用）
MODEL_ALIASES=                  # 自定义模型别名
HIDDEN_FROM_LIST=               # 从 /v1/models 列表中隐藏

# ===== 日志与调试 =====
LOG_LEVEL=INFO                  # TRACE / DEBUG / INFO / WARNING / ERROR / CRITICAL
DEBUG_MODE=off                  # off / errors / all
```

### 配置优先级

| 类型 | 优先级（高 → 低） |
|------|-------------------|
| 服务器配置 | CLI 参数 > 环境变量 > 默认值 |
| 凭证来源 | SQLite 数据库 > JSON 文件 > 环境变量 |
| 模型解析 | 别名 > 归一化 > 动态缓存 > 隐藏模型 > 透传 |

---

## Claude Code 集成

### 自动配置（macOS 应用）

在仪表盘的 Claude Code 区域：

1. 选择 Opus、Sonnet、Haiku 对应的实际模型
2. 点击「写入配置」— 自动将网关地址和模型映射写入 `~/.claude/settings.json`
3. 点击「还原配置」— 恢复写入前的原始配置（备份存储在 `~/.kiro-gateway/settings.env.backup.json`）

写入配置只修改 `env` 字段，不会影响你已有的其他设置（如 `model`、`enabledPlugins` 等）。

### 手动配置

编辑 `~/.claude/settings.json`，添加 `env` 字段：

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

## API 参考

| 端点 | 方法 | 说明 |
|------|------|------|
| `/health` | GET | 健康检查，返回服务状态和时间戳 |
| `/v1/models` | GET | 列出可用模型（带缓存，支持隐藏模型和别名） |
| `/v1/chat/completions` | POST | OpenAI Chat Completions API |
| `/v1/messages` | POST | Anthropic Messages API |
| `/claude-config` | GET | 读取当前 Claude Code 配置 |
| `/claude-config` | POST | 写入 Claude Code 模型配置 |
| `/request-history/{rid}` | GET | 获取请求摘要（macOS 应用使用） |
| `/request-history/{rid}/full` | GET | 获取完整请求详情 |

### 认证

- OpenAI 格式：`Authorization: Bearer your-password`
- Anthropic 格式：`x-api-key: your-password`

两种方式均可用于所有端点。

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

## 高级功能

### 模型别名

自定义模型名称映射，方便使用：

```env
MODEL_ALIASES={"my-model": "claude-sonnet-4.5", "auto-kiro": "auto"}
```

### 隐藏模型

添加不在 Kiro API 列表中但仍可使用的模型：

```env
HIDDEN_MODELS=claude-3.7-sonnet
```

### 从列表隐藏

从 `/v1/models` 响应中隐藏特定模型（模型仍可直接使用）：

```env
HIDDEN_FROM_LIST=some-model-id
```

### 回退模型列表

当 Kiro API 不可达时使用的硬编码模型列表，确保 `/v1/models` 始终有响应。

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
hdiutil create -volname "KiroGateway" \
  -srcfolder KiroGateway/dist/KiroGateway.app \
  -ov -format UDZO \
  KiroGateway/dist/KiroGateway.dmg
```

### Docker

```bash
docker build -t kiro-gateway .
```

Docker 镜像基于 Python 3.10-slim，使用非 root 用户运行，内置健康检查。

---

## 项目结构

```
kiro-gateway/
├── main.py                    # FastAPI 应用入口，中间件和路由注册
├── kiro/
│   ├── config.py              # 配置系统（环境变量、CLI 参数、默认值）
│   ├── auth.py                # 多源认证（Kiro IDE、AWS SSO、SQLite）
│   ├── routes_openai.py       # OpenAI 兼容 API 路由
│   ├── routes_anthropic.py    # Anthropic 兼容 API 路由
│   ├── routes_claude_config.py # Claude Code 配置 API
│   ├── model_resolver.py      # 4 层模型解析管道
│   ├── cache.py               # 模型信息缓存（TTL）
│   ├── converters_openai.py   # OpenAI 格式转换器
│   ├── converters_anthropic.py # Anthropic 格式转换器
│   ├── converters_core.py     # 统一内部格式转换
│   ├── streaming_openai.py    # OpenAI SSE 流式处理
│   ├── streaming_anthropic.py # Anthropic SSE 流式处理
│   ├── streaming_core.py      # 统一流式事件解析
│   ├── thinking_parser.py     # 扩展思考标签解析（有限状态机）
│   ├── truncation_recovery.py # 截断恢复（合成消息注入）
│   ├── http_client.py         # HTTP 客户端（重试、退避、连接管理）
│   ├── tokenizer.py           # Token 计数（tiktoken）
│   ├── kiro_errors.py         # Kiro 错误码增强
│   ├── network_errors.py      # 网络错误分类与排查建议
│   ├── request_history.py     # 请求历史环形缓冲区
│   ├── debug_middleware.py    # 调试日志中间件
│   └── debug_logger.py        # 调试日志记录器
├── KiroGateway/               # macOS SwiftUI 应用
│   ├── KiroGateway/
│   │   ├── KiroGatewayApp.swift
│   │   ├── ContentView.swift
│   │   ├── DashboardView.swift
│   │   ├── RequestLogView.swift
│   │   ├── LogView.swift
│   │   ├── SettingsView.swift
│   │   ├── GatewayService.swift  # Python 进程管理
│   │   ├── ConfigManager.swift   # 配置持久化
│   │   └── MenuBarView.swift
│   └── build.sh               # 构建脚本
├── Dockerfile
├── docker-compose.yml
├── requirements.txt
├── start.sh                   # 启动脚本
└── .env.example               # 配置模板
```

---

## 许可证

[AGPL-3.0](LICENSE)。你可以使用、修改和分发本软件。网络使用视为分发——如果你将修改版本部署为服务，必须公开源代码。

## 免责声明

本项目与 Amazon Web Services、Anthropic 或 Kiro IDE 无关。使用风险自负。

---

<div align="center">

Made with ❤️ by [@meitianwang](https://github.com/meitianwang)

</div>
