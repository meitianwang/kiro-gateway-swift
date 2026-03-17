import SwiftUI

struct MenuBarView: View {

    @EnvironmentObject var config: ConfigManager
    @EnvironmentObject var service: GatewayService

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // 状态头
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(statusGradient)
                        .frame(width: 22, height: 22)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Kiro Gateway")
                        .font(.system(.callout, weight: .medium))
                    Text(service.status.label)
                        .font(.caption2)
                        .foregroundStyle(statusForeground)
                }
                Spacer()
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)

            if service.status == .running {
                Text(config.baseURL)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 2)
            }

            Divider()
                .padding(.vertical, 2)

            // 控制
            switch service.status {
            case .stopped, .error:
                menuButton("启动服务", icon: "play.fill") { service.start() }
            case .starting:
                HStack(spacing: 6) {
                    ProgressView().controlSize(.mini)
                    Text("启动中…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 3)
            case .running:
                menuButton("停止服务", icon: "stop.fill") { service.stop() }
                menuButton("重启服务", icon: "arrow.clockwise") { service.restart() }
            }

            Divider()
                .padding(.vertical, 2)

            if service.status == .running {
                menuButton("复制 API 地址", icon: "doc.on.doc") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(
                        "\(config.baseURL)/v1/chat/completions",
                        forType: .string
                    )
                }

                menuButton("在浏览器中打开", icon: "safari") {
                    if let url = URL(string: "\(config.baseURL)/docs") {
                        NSWorkspace.shared.open(url)
                    }
                }

                Divider()
                    .padding(.vertical, 2)
            }

            menuButton("打开主窗口", icon: "macwindow") {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.title.contains("Kiro") || $0.isKeyWindow }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }

            Divider()
                .padding(.vertical, 2)

            menuButton("退出", icon: "power") {
                service.stop()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    NSApp.terminate(nil)
                }
            }
            .keyboardShortcut("q")
        }
        .padding(6)
        .frame(width: 200)
    }

    private func menuButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption)
                    .frame(width: 16)
                Text(title)
                    .font(.callout)
                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var statusGradient: LinearGradient {
        switch service.status {
        case .stopped:
            return LinearGradient(colors: [.gray.opacity(0.6), .gray.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .starting:
            return LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .running:
            return LinearGradient(colors: [Color(red: 0.16, green: 0.71, blue: 0.55), Color(red: 0.12, green: 0.55, blue: 0.65)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .error:
            return LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var statusForeground: Color {
        switch service.status {
        case .stopped: return .secondary
        case .starting: return .orange
        case .running: return Color(red: 0.16, green: 0.71, blue: 0.55)
        case .error: return .red
        }
    }
}
