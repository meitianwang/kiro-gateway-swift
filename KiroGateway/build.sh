#!/usr/bin/env bash

# =============================================================================
# Kiro Gateway macOS App - 构建脚本
#
# 将 SwiftUI app + Python gateway 源码 + Python 依赖打包为完整的 .app
# 用户无需手动安装任何 Python 依赖，开箱即用
#
# 前置要求: Xcode 15.0+, Python 3.10+, pip
# 用法: bash KiroGateway/build.sh
# 产出: KiroGateway/dist/KiroGateway.app
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$SCRIPT_DIR/dist"
BUILD_DIR="$SCRIPT_DIR/.build"

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
NC='\033[0m'

echo -e "${CYAN}🔨 构建 KiroGateway.app ...${NC}"

# 检查 Xcode
if ! xcodebuild -version &>/dev/null; then
    echo -e "${RED}❌ 需要安装 Xcode${NC}"
    exit 1
fi
echo -e "   $(xcodebuild -version | head -1)"

# 检查 Python（构建时需要，用于安装依赖）
PYTHON3=""
for p in python3 /opt/homebrew/bin/python3 /usr/local/bin/python3; do
    if command -v "$p" &>/dev/null; then
        PYTHON3="$p"
        break
    fi
done

if [ -z "$PYTHON3" ]; then
    echo -e "${RED}❌ 需要 Python3 来安装依赖${NC}"
    exit 1
fi
echo -e "   Python: $($PYTHON3 --version)"

# 1. 编译 Swift app
echo -e "${CYAN}[1/4] 编译 SwiftUI 应用...${NC}"
xcodebuild \
    -project "$SCRIPT_DIR/KiroGateway.xcodeproj" \
    -scheme KiroGateway \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    ONLY_ACTIVE_ARCH=NO \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    -quiet 2>&1

APP_SRC="$BUILD_DIR/Build/Products/Release/KiroGateway.app"

if [ ! -d "$APP_SRC" ]; then
    echo -e "${RED}❌ 编译失败${NC}"
    exit 1
fi
echo -e "${GREEN}   ✅ 编译成功${NC}"

# 2. 将 Python gateway 源码打包进 Resources
echo -e "${CYAN}[2/4] 打包 Gateway 源码...${NC}"

GATEWAY_DEST="$APP_SRC/Contents/Resources/gateway"
rm -rf "$GATEWAY_DEST"
mkdir -p "$GATEWAY_DEST"

# 复制核心文件
cp "$PROJECT_ROOT/main.py" "$GATEWAY_DEST/"
cp "$PROJECT_ROOT/requirements.txt" "$GATEWAY_DEST/"
cp -R "$PROJECT_ROOT/kiro" "$GATEWAY_DEST/kiro"
cp "$PROJECT_ROOT/.env.example" "$GATEWAY_DEST/"

# 清理 __pycache__
find "$GATEWAY_DEST" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true

echo -e "${GREEN}   ✅ 源码已打包${NC}"

# 3. 安装 Python 运行时依赖到 vendor 目录
echo -e "${CYAN}[3/4] 安装 Python 依赖到 app bundle...${NC}"

VENDOR_DIR="$GATEWAY_DEST/vendor"
mkdir -p "$VENDOR_DIR"

# 只安装运行时依赖（排除测试依赖）
$PYTHON3 -m pip install \
    --target "$VENDOR_DIR" \
    --no-user \
    --no-cache-dir \
    --quiet \
    fastapi "uvicorn[standard]" httpx loguru python-dotenv tiktoken requests 2>&1

# 清理不需要的文件以减小体积
find "$VENDOR_DIR" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find "$VENDOR_DIR" -type d -name "*.dist-info" -exec rm -rf {} + 2>/dev/null || true
find "$VENDOR_DIR" -type d -name "tests" -exec rm -rf {} + 2>/dev/null || true
find "$VENDOR_DIR" -type d -name "test" -exec rm -rf {} + 2>/dev/null || true
find "$VENDOR_DIR" -name "*.pyc" -delete 2>/dev/null || true

VENDOR_SIZE=$(du -sh "$VENDOR_DIR" | cut -f1)
echo -e "${GREEN}   ✅ 依赖已安装 ($VENDOR_SIZE)${NC}"

# 4. 输出到 dist
echo -e "${CYAN}[4/4] 生成最终产物...${NC}"

mkdir -p "$DIST_DIR"
rm -rf "$DIST_DIR/KiroGateway.app"
cp -R "$APP_SRC" "$DIST_DIR/"

APP_SIZE=$(du -sh "$DIST_DIR/KiroGateway.app" | cut -f1)

echo ""
echo -e "${GREEN}✅ 构建完成！${NC}"
echo -e "   📦 ${CYAN}$DIST_DIR/KiroGateway.app${NC} ($APP_SIZE)"
echo -e "   Python 依赖已内置，用户无需手动安装"
echo ""
echo -e "   运行:  ${YELLOW}open \"$DIST_DIR/KiroGateway.app\"${NC}"
echo -e "   安装:  ${YELLOW}cp -R \"$DIST_DIR/KiroGateway.app\" /Applications/${NC}"
