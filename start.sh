#!/usr/bin/env bash

# Kiro Gateway 启动脚本
# 自动 kill 占用端口的进程，后台启动服务，日志输出到项目目录

set -euo pipefail

# 项目根目录（脚本所在目录）
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 日志与 PID 文件
LOG_DIR="${SCRIPT_DIR}/logs"
LOG_FILE="${LOG_DIR}/kiro-gateway.log"
PID_FILE="${SCRIPT_DIR}/.kiro-gateway.pid"

# 默认值
DEFAULT_HOST="0.0.0.0"
DEFAULT_PORT=9000

# 解析参数
HOST="${1:-$DEFAULT_HOST}"
PORT="${2:-$DEFAULT_PORT}"

# 支持环境变量覆盖
HOST="${SERVER_HOST:-$HOST}"
PORT="${SERVER_PORT:-$PORT}"

# 确保日志目录存在
mkdir -p "$LOG_DIR"

echo -e "${CYAN}🚀 Kiro Gateway 启动脚本${NC}"
echo -e "${CYAN}   Host: ${HOST}  Port: ${PORT}${NC}"
echo ""

# 检查端口是否被占用，如果是则 kill 对应进程
kill_port_process() {
    local port=$1
    local pids

    # 获取占用端口的进程 PID（排除表头）
    pids=$(lsof -ti :"$port" 2>/dev/null || true)

    if [ -n "$pids" ]; then
        echo -e "${YELLOW}⚠️  端口 ${port} 已被占用，正在终止相关进程...${NC}"
        for pid in $pids; do
            local proc_name
            proc_name=$(ps -p "$pid" -o comm= 2>/dev/null || echo "unknown")
            echo -e "   ${RED}killing PID ${pid} (${proc_name})${NC}"
            kill -9 "$pid" 2>/dev/null || true
        done
        # 等待端口释放
        sleep 1
        echo -e "${GREEN}✅ 端口 ${port} 已释放${NC}"
    else
        echo -e "${GREEN}✅ 端口 ${PORT} 未被占用${NC}"
    fi
}

# 检查 Python 环境
check_python() {
    if ! command -v python &>/dev/null && ! command -v python3 &>/dev/null; then
        echo -e "${RED}❌ 未找到 Python，请先安装 Python 3.10+${NC}"
        exit 1
    fi

    # 优先使用 python3
    if command -v python3 &>/dev/null; then
        PYTHON_CMD="python3"
    else
        PYTHON_CMD="python"
    fi
}

# 检查依赖
check_deps() {
    if [ ! -f "requirements.txt" ]; then
        echo -e "${YELLOW}⚠️  未找到 requirements.txt${NC}"
        return
    fi

    # 快速检查核心依赖是否已安装
    if ! $PYTHON_CMD -c "import fastapi, uvicorn, httpx" 2>/dev/null; then
        echo -e "${YELLOW}⚠️  缺少依赖，正在安装...${NC}"
        $PYTHON_CMD -m pip install -r requirements.txt -q
        echo -e "${GREEN}✅ 依赖安装完成${NC}"
    fi
}

# 检查 .env 文件
check_env() {
    if [ ! -f ".env" ]; then
        echo -e "${YELLOW}⚠️  未找到 .env 文件，请先配置：cp .env.example .env${NC}"
        exit 1
    fi
}

# 主流程
check_python
check_env
check_deps
kill_port_process "$PORT"

echo ""
echo -e "${GREEN}🟢 正在后台启动 Kiro Gateway...${NC}"

# 后台启动，stdout 和 stderr 都写入日志文件
nohup $PYTHON_CMD main.py --host "$HOST" --port "$PORT" >> "$LOG_FILE" 2>&1 &
BG_PID=$!

# 保存 PID
echo "$BG_PID" > "$PID_FILE"

# 等一下确认进程存活
sleep 2
if kill -0 "$BG_PID" 2>/dev/null; then
    echo -e "${GREEN}✅ Kiro Gateway 已启动 (PID: ${BG_PID})${NC}"
    echo -e "${CYAN}   日志文件: ${LOG_FILE}${NC}"
    echo -e "${CYAN}   PID 文件: ${PID_FILE}${NC}"
    echo ""
    echo -e "   查看日志: ${YELLOW}tail -f ${LOG_FILE}${NC}"
    echo -e "   停止服务: ${YELLOW}kill \$(cat ${PID_FILE})${NC}"
else
    echo -e "${RED}❌ 启动失败，请查看日志: ${LOG_FILE}${NC}"
    exit 1
fi
