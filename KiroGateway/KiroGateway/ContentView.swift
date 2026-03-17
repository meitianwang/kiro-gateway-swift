import SwiftUI

struct ContentView: View {

    @EnvironmentObject var config: ConfigManager
    @EnvironmentObject var service: GatewayService

    @State private var selectedTab: Tab = .dashboard

    enum Tab: String, CaseIterable {
        case dashboard = "仪表盘"
        case requestLogs = "请求日志"
        case runLog = "运行日志"
        case settings = "设置"

        var icon: String {
            switch self {
            case .dashboard: return "square.grid.2x2"
            case .requestLogs: return "arrow.left.arrow.right"
            case .runLog: return "terminal"
            case .settings: return "gearshape"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()

            Group {
                switch selectedTab {
                case .dashboard:
                    DashboardView()
                case .requestLogs:
                    RequestLogView()
                case .runLog:
                    LogView()
                case .settings:
                    SettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("")
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 16) {
            // 左侧：状态图标 + 标题
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(statusGradient)
                        .frame(width: 26, height: 26)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 0) {
                    Text("Kiro Gateway")
                        .font(.system(.body, design: .rounded, weight: .semibold))
                    if case .error(let msg) = service.status {
                        Text(msg)
                            .font(.caption2)
                            .foregroundStyle(.red)
                            .lineLimit(1)
                    }
                }
            }

            // 中间：标签页
            HStack(spacing: 2) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedTab = tab
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: tab.icon)
                                .font(.caption)
                            Text(tab.rawValue)
                                .font(.caption)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            selectedTab == tab
                                ? Color.accentColor.opacity(0.12)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                        .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()

            // 右侧：状态标签 + 控制按钮
            HStack(spacing: 10) {
                if service.status == .running {
                    Text("运行中")
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(red: 0.16, green: 0.71, blue: 0.55).opacity(0.12), in: Capsule())
                        .foregroundStyle(Color(red: 0.16, green: 0.71, blue: 0.55))
                }

                controlButtons
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    @ViewBuilder
    private var controlButtons: some View {
        switch service.status {
        case .stopped, .error:
            Button {
                service.start()
            } label: {
                Label("启动", systemImage: "play.fill")
                    .font(.caption)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(red: 0.16, green: 0.71, blue: 0.55))
            .controlSize(.small)

        case .starting:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("启动中…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .running:
            HStack(spacing: 6) {
                Button { service.restart() } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("重启")

                Button { service.stop() } label: {
                    Image(systemName: "stop.fill")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .controlSize(.small)
                .help("停止")
            }
        }
    }

    // MARK: - Status Styling

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
}
