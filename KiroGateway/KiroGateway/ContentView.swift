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
            case .dashboard: return "gauge"
            case .requestLogs: return "list.bullet.rectangle"
            case .runLog: return "text.alignleft"
            case .settings: return "gearshape"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部栏：标题 + 状态 + 标签页
            topBar
            Divider()

            // 内容区
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
    }

    private var topBar: some View {
        HStack(spacing: 16) {
            // 左侧：状态指示 + 标题
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: statusColor.opacity(0.6), radius: 4)
                Text("Kiro Gateway")
                    .font(.system(.body, design: .rounded, weight: .semibold))
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

            // 右侧：启停按钮
            controlButtons
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
            .tint(.green)
            .controlSize(.small)

        case .starting:
            ProgressView()
                .controlSize(.small)

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

    private var statusColor: Color {
        switch service.status {
        case .stopped: return .gray
        case .starting: return .orange
        case .running: return .green
        case .error: return .red
        }
    }
}
