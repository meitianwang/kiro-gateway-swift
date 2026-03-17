# Kiro Gateway macOS App

原生 SwiftUI macOS 应用，为 Kiro Gateway 提供图形化管理界面。

## 功能

- 🧙 首次运行配置向导（4 步引导）
- ⚙️ 可视化配置所有 `.env` 参数
- ▶️ 一键启动/停止 Python Gateway 服务
- 📋 实时日志查看（搜索、自动滚动、颜色高亮）
- 🔔 菜单栏常驻（状态指示、快捷操作）
- 📎 一键复制 API 端点地址
- 🏥 自动健康检查

## 构建

需要 Xcode 15.0+（从 App Store 安装）：

```bash
cd KiroGateway
chmod +x build.sh
./build.sh
```

或直接用 Xcode 打开 `KiroGateway.xcodeproj` 编译运行。

产出在 `dist/KiroGateway.app`。

## 运行时要求

- macOS 13.0+
- Python 3.10+
- Kiro Gateway 源码（本仓库根目录）

## 使用

1. 双击打开 `KiroGateway.app`
2. 首次运行进入配置向导：
   - 检测 Python 环境
   - 选择 Gateway 代码目录（指向本仓库根目录）
   - 填入 Kiro 凭证和 API 密码
   - 配置服务器端口
3. 点击「启动」，服务就绪后自动显示连接信息
4. 菜单栏图标可快速控制服务

配置保存在 `~/.kiro-gateway/.env`。

## 项目结构

```
KiroGateway/
├── KiroGatewayApp.swift   # App 入口 + 窗口 + 菜单栏
├── ContentView.swift      # 主界面仪表盘
├── SetupView.swift        # 首次配置向导
├── SettingsView.swift     # 设置面板（3 个 Tab）
├── LogView.swift          # 实时日志查看器
├── MenuBarView.swift      # 菜单栏快捷操作
├── GatewayService.swift   # Python 子进程管理 + 健康检查
└── ConfigManager.swift    # .env 配置读写
```
