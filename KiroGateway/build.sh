#!/usr/bin/env bash

# =============================================================================
# Kiro Gateway macOS App - 构建脚本
#
# 将 SwiftUI app + Python gateway 源码打包为 .app
# Python 依赖在首次启动时自动安装到 ~/.kiro-gateway/venv/
#
# 前置要求: Xcode 15.0+
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

# 1. 编译 Swift app
echo -e "${CYAN}[1/3] 编译 SwiftUI 应用...${NC}"
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

# 2. 将 Python gateway 源码打包进 Resources（不含依赖）
echo -e "${CYAN}[2/3] 打包 Gateway 源码...${NC}"

GATEWAY_DEST="$APP_SRC/Contents/Resources/gateway"
rm -rf "$GATEWAY_DEST"
mkdir -p "$GATEWAY_DEST"

cp "$PROJECT_ROOT/main.py" "$GATEWAY_DEST/"
cp "$PROJECT_ROOT/requirements.txt" "$GATEWAY_DEST/"
cp -R "$PROJECT_ROOT/kiro" "$GATEWAY_DEST/kiro"
cp "$PROJECT_ROOT/.env.example" "$GATEWAY_DEST/"

find "$GATEWAY_DEST" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true

echo -e "${GREEN}   ✅ 源码已打包${NC}"

# 3. 输出到 dist
echo -e "${CYAN}[3/3] 生成最终产物...${NC}"

mkdir -p "$DIST_DIR"
rm -rf "$DIST_DIR/KiroGateway.app"
cp -R "$APP_SRC" "$DIST_DIR/"

APP_SIZE=$(du -sh "$DIST_DIR/KiroGateway.app" | cut -f1)

echo ""
echo -e "${GREEN}✅ 构建完成！${NC}"
echo -e "   📦 ${CYAN}$DIST_DIR/KiroGateway.app${NC} ($APP_SIZE)"
echo -e "   Python 依赖将在首次启动时自动安装"
echo ""
echo -e "   运行:  ${YELLOW}open \"$DIST_DIR/KiroGateway.app\"${NC}"
echo -e "   安装:  ${YELLOW}cp -R \"$DIST_DIR/KiroGateway.app\" /Applications/${NC}"
