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
        NavigationSplitView {
            List(selection: $selectedTab) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Label(tab.rawValue, systemImage: tab.icon)
                        .tag(tab)
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 160)
        } detail: {
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
    }
}
