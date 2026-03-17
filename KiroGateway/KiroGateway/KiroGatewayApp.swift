import SwiftUI

@main
struct KiroGatewayApp: App {

    @StateObject private var config = ConfigManager.shared
    @StateObject private var service = GatewayService.shared

    var body: some Scene {
        // 主窗口
        WindowGroup {
            ContentView()
                .environmentObject(config)
                .environmentObject(service)
                .frame(minWidth: 800, minHeight: 520)
                .onAppear {
                    if service.status == .stopped {
                        service.start()
                    }
                }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 960, height: 640)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        // 菜单栏图标
        MenuBarExtra {
            MenuBarView()
                .environmentObject(config)
                .environmentObject(service)
        } label: {
            Image(systemName: menuBarIcon)
        }
    }

    private var menuBarIcon: String {
        switch service.status {
        case .running: return "bolt.fill"
        case .starting: return "bolt.badge.clock"
        case .error: return "bolt.trianglebadge.exclamationmark"
        case .stopped: return "bolt.slash"
        }
    }
}
