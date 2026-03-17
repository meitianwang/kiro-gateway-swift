import SwiftUI

struct MenuBarView: View {

    @EnvironmentObject var config: ConfigManager
    @EnvironmentObject var service: GatewayService

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 状态
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text("Kiro Gateway")
                    .fontWeight(.medium)
                Spacer()
                Text(service.status.label)
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }

            if service.status == .running {
                Text(config.baseURL)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Divider()

            // 控制
            switch service.status {
            case .stopped, .error:
                Button("启动服务") { service.start() }
            case .starting:
                Text("启动中…").foregroundStyle(.secondary)
            case .running:
                Button("停止服务") { service.stop() }
                Button("重启服务") { service.restart() }
            }

            Divider()

            if service.status == .running {
                Button("复制 API 地址") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(
                        "\(config.baseURL)/v1/chat/completions",
                        forType: .string
                    )
                }

                Button("在浏览器中打开") {
                    if let url = URL(string: "\(config.baseURL)/docs") {
                        NSWorkspace.shared.open(url)
                    }
                }

                Divider()
            }

            Button("打开主窗口") {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first(where: { $0.title.contains("Kiro") || $0.isKeyWindow }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }

            Divider()

            Button("退出") {
                service.stop()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    NSApp.terminate(nil)
                }
            }
            .keyboardShortcut("q")
        }
        .padding(4)
    }

    private var statusColor: Color {
        switch service.status {
        case .stopped: return .gray
        case .starting: return .orange
        case .running: return .green
        case .error: return .red
        }
    }
}
