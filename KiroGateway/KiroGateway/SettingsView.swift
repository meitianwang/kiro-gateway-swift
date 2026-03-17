import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var config: ConfigManager
    @EnvironmentObject var service: GatewayService
    @State private var showSaveConfirm = false

    private let teal = Color(red: 0.16, green: 0.71, blue: 0.55)

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                credentialsCard
                HStack(alignment: .top, spacing: 12) {
                    serverCard
                    proxyCard
                }
                HStack(alignment: .top, spacing: 12) {
                    timeoutCard
                    reasoningCard
                }
                HStack(alignment: .top, spacing: 12) {
                    otherCard
                    environmentCard
                }
                saveBar
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - 凭证

    private var credentialsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("凭证", icon: "key.fill")

            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    field("API 密码") {
                        SecureField("自定义密码", text: $config.proxyApiKey)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.small)
                    }
                    field("认证方式") {
                        Picker("", selection: $config.authMethod) {
                            ForEach(ConfigManager.AuthMethod.allCases) { m in
                                Text(m.rawValue).tag(m)
                            }
                        }
                        .labelsHidden()
                        .controlSize(.small)
                        .onChange(of: config.authMethod) { v in
                            if v == .credsFile { config.autoDetectCredsFile() }
                        }
                    }
                    authDetail
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 10) {
                    field("Profile ARN") {
                        TextField("arn:aws:codewhisperer:...", text: $config.profileArn)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.small)
                    }
                    field("Region") {
                        TextField("us-east-1", text: $config.kiroRegion)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.small)
                            .frame(maxWidth: 180)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .cardStyle()
    }

    @ViewBuilder
    private var authDetail: some View {
        switch config.authMethod {
        case .refreshToken:
            field("Refresh Token") {
                SecureField("粘贴 Token", text: $config.refreshToken)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
            }
        case .credsFile:
            field("凭证文件") {
                HStack(spacing: 4) {
                    TextField("~/.aws/sso/cache/kiro-auth-token.json", text: $config.kiroCredsFile)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                    if config.credsFileAutoDetected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(teal)
                            .font(.caption2)
                    }
                }
            }
        case .ssoCache:
            field("SSO 缓存文件") {
                HStack(spacing: 4) {
                    TextField("~/.aws/sso/cache/xxx.json", text: $config.kiroCredsFile)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                    filePickerButton(types: ["json"], binding: $config.kiroCredsFile)
                }
            }
        case .cliDb:
            field("SQLite 数据库") {
                HStack(spacing: 4) {
                    TextField("~/.local/share/kiro-cli/data.sqlite3", text: $config.kiroCliDbFile)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                    filePickerButton(types: ["sqlite3", "db"], binding: $config.kiroCliDbFile)
                }
            }
        }
    }

    // MARK: - 服务器

    private var serverCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("服务器", icon: "server.rack")

            HStack(spacing: 8) {
                field("地址") {
                    TextField("127.0.0.1", text: $config.serverHost)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                }
                field("端口") {
                    TextField("9001", text: $config.serverPort)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                        .frame(width: 60)
                }
            }

            Toggle("允许局域网访问", isOn: Binding(
                get: { config.serverHost == "0.0.0.0" },
                set: { config.serverHost = $0 ? "0.0.0.0" : "127.0.0.1" }
            ))
            .controlSize(.small)
            .tint(teal)
        }
        .cardStyle()
    }

    // MARK: - 代理

    private var proxyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("代理", icon: "network.badge.shield.half.filled")

            field("VPN/Proxy URL") {
                TextField("http://127.0.0.1:7890", text: $config.vpnProxyUrl)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
            }
            Text("留空直连，支持 HTTP/SOCKS5")
                .font(.caption2)
                .foregroundStyle(.quaternary)
        }
        .cardStyle()
    }

    // MARK: - 超时

    private var timeoutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("超时（秒）", icon: "clock")

            HStack(spacing: 8) {
                field("首 Token") {
                    TextField("15", text: $config.firstTokenTimeout)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                        .frame(width: 50)
                }
                field("重试") {
                    TextField("3", text: $config.firstTokenMaxRetries)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                        .frame(width: 50)
                }
                field("流式读取") {
                    TextField("300", text: $config.streamingReadTimeout)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                        .frame(width: 50)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - Reasoning

    private var reasoningCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Fake Reasoning", icon: "brain")

            Toggle("启用", isOn: $config.fakeReasoning)
                .controlSize(.small)
                .tint(teal)

            if config.fakeReasoning {
                HStack(spacing: 8) {
                    field("最大 Token") {
                        TextField("4000", text: $config.fakeReasoningMaxTokens)
                            .textFieldStyle(.roundedBorder)
                            .controlSize(.small)
                            .frame(width: 60)
                    }
                    field("处理方式") {
                        Picker("", selection: $config.fakeReasoningHandling) {
                            Text("reasoning_content").tag("as_reasoning_content")
                            Text("移除").tag("remove")
                            Text("原样").tag("pass")
                            Text("去标签").tag("strip_tags")
                        }
                        .labelsHidden()
                        .controlSize(.small)
                    }
                }
            }
        }
        .cardStyle()
    }

    // MARK: - 其他

    private var otherCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("其他", icon: "slider.horizontal.3")

            Toggle("截断恢复", isOn: $config.truncationRecovery)
                .controlSize(.small)
                .tint(teal)

            HStack(spacing: 8) {
                field("日志级别") {
                    Picker("", selection: $config.logLevel) {
                        ForEach(["TRACE", "DEBUG", "INFO", "WARNING", "ERROR"], id: \.self) {
                            Text($0).tag($0)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.small)
                }
                field("调试模式") {
                    Picker("", selection: $config.debugMode) {
                        Text("关闭").tag("off")
                        Text("仅错误").tag("errors")
                        Text("全部").tag("all")
                    }
                    .labelsHidden()
                    .controlSize(.small)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - 环境

    private var environmentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("运行环境", icon: "cpu")

            HStack {
                Text("Python")
                    .font(.callout)
                Spacer()
                if service.isPythonAvailable {
                    Text(service.pythonPath)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(teal)
                        .font(.caption2)
                } else {
                    Text("未检测到")
                        .font(.caption)
                        .foregroundStyle(.red)
                    Button("检测") { service.detectPython() }
                        .controlSize(.mini)
                }
            }
        }
        .cardStyle()
    }

    // MARK: - 保存

    private var saveBar: some View {
        HStack {
            if showSaveConfirm {
                Label("已保存", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(teal)
                    .transition(.opacity)
            }
            Spacer()
            if service.status == .running {
                Button("保存并重启") {
                    config.save()
                    showSaveConfirm = true
                    service.restart()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { showSaveConfirm = false }
                    }
                }
                .controlSize(.small)
                .buttonStyle(.bordered)
            }
            Button("保存") {
                config.save()
                withAnimation { showSaveConfirm = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation { showSaveConfirm = false }
                }
            }
            .controlSize(.small)
            .buttonStyle(.borderedProminent)
            .tint(teal)
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(teal)
            Text(title)
                .font(.callout.weight(.medium))
        }
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func filePickerButton(types: [String], binding: Binding<String>) -> some View {
        Button("选择…") {
            let panel = NSOpenPanel()
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            panel.allowedContentTypes = types.compactMap { UTType(filenameExtension: $0) }
            if panel.runModal() == .OK, let url = panel.url { binding.wrappedValue = url.path }
        }
        .controlSize(.mini)
    }
}
