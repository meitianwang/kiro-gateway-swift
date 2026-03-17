import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject var config: ConfigManager
    @EnvironmentObject var service: GatewayService
    @State private var showSaveConfirm = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                pythonSection
                credentialsSection
                serverSection
                proxySection
                timeoutSection
                reasoningSection
                otherSection
                saveSection
            }.padding(24)
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var pythonSection: some View {
        GroupBox {
            HStack {
                Text("Python").frame(width: 80, alignment: .leading)
                if service.isPythonAvailable {
                    Text(service.pythonPath)
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.secondary).lineLimit(1)
                    Spacer()
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                } else {
                    Text("未检测到 Python3").foregroundStyle(.red)
                    Spacer()
                    Button("重新检测") { service.detectPython() }.controlSize(.small)
                }
            }.padding(12)
        } label: { Label("运行环境", systemImage: "cpu") }
    }

    private var credentialsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("API 密码（PROXY_API_KEY）").font(.callout.weight(.medium))
                    Text("连接时用作 API Key，自己设定即可").font(.caption).foregroundStyle(.secondary)
                    SecureField("自定义密码", text: $config.proxyApiKey).textFieldStyle(.roundedBorder)
                }
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Kiro 凭证来源").font(.callout.weight(.medium))
                    Picker("认证方式", selection: $config.authMethod) {
                        ForEach(ConfigManager.AuthMethod.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }.pickerStyle(.radioGroup)
                    .onChange(of: config.authMethod) { newValue in
                        if newValue == .credsFile { config.autoDetectCredsFile() }
                    }
                    authMethodDetail
                }
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Profile ARN（可选）").font(.callout.weight(.medium))
                    Text("Kiro IDE 用户通常自动检测，无需填写").font(.caption).foregroundStyle(.secondary)
                    TextField("arn:aws:codewhisperer:...", text: $config.profileArn).textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Region").font(.callout.weight(.medium))
                    TextField("us-east-1", text: $config.kiroRegion).textFieldStyle(.roundedBorder).frame(maxWidth: 200)
                }
            }.padding(12)
        } label: { Label("凭证", systemImage: "key.fill") }
    }

    @ViewBuilder
    private var authMethodDetail: some View {
        switch config.authMethod {
        case .refreshToken:
            VStack(alignment: .leading, spacing: 4) {
                Text("从 Kiro IDE 抓包获取的 refresh_token，适合快速测试").font(.caption).foregroundStyle(.secondary)
                SecureField("粘贴 Refresh Token", text: $config.refreshToken).textFieldStyle(.roundedBorder)
            }
        case .credsFile:
            VStack(alignment: .leading, spacing: 4) {
                Text("Kiro IDE 登录后自动生成的 JSON 凭证文件，推荐使用").font(.caption).foregroundStyle(.secondary)
                HStack {
                    TextField("~/.aws/sso/cache/kiro-auth-token.json", text: $config.kiroCredsFile).textFieldStyle(.roundedBorder)
                    if config.credsFileAutoDetected {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).help("已自动检测到")
                    }
                }
                if config.kiroCredsFile.isEmpty {
                    Text("未检测到凭证文件，请确认已登录 Kiro IDE").font(.caption).foregroundStyle(.orange)
                }
            }
        case .ssoCache:
            VStack(alignment: .leading, spacing: 4) {
                Text("AWS SSO 缓存文件（含 clientId/clientSecret），适合企业用户").font(.caption).foregroundStyle(.secondary)
                HStack {
                    TextField("~/.aws/sso/cache/xxx.json", text: $config.kiroCredsFile).textFieldStyle(.roundedBorder)
                    filePickerButton(types: ["json"], binding: $config.kiroCredsFile)
                }
            }
        case .cliDb:
            VStack(alignment: .leading, spacing: 4) {
                Text("kiro-cli 的 SQLite 数据库，适合 IAM Identity Center 用户").font(.caption).foregroundStyle(.secondary)
                HStack {
                    TextField("~/.local/share/kiro-cli/data.sqlite3", text: $config.kiroCliDbFile).textFieldStyle(.roundedBorder)
                    filePickerButton(types: ["sqlite3", "db"], binding: $config.kiroCliDbFile)
                }
            }
        }
    }

    private var serverSection: some View {
        GroupBox {
            VStack(spacing: 10) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("监听地址").font(.callout.weight(.medium))
                        TextField("127.0.0.1", text: $config.serverHost).textFieldStyle(.roundedBorder)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("端口").font(.callout.weight(.medium))
                        TextField("8000", text: $config.serverPort).textFieldStyle(.roundedBorder).frame(width: 100)
                    }
                }
                Toggle("允许局域网访问（监听 0.0.0.0）", isOn: Binding(
                    get: { config.serverHost == "0.0.0.0" },
                    set: { config.serverHost = $0 ? "0.0.0.0" : "127.0.0.1" }
                ))
            }.padding(12)
        } label: { Label("服务器", systemImage: "server.rack") }
    }

    private var proxySection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 4) {
                Text("VPN/Proxy URL（留空直连）").font(.callout.weight(.medium))
                Text("支持 HTTP 和 SOCKS5，适合翻墙或公司代理").font(.caption).foregroundStyle(.secondary)
                TextField("http://127.0.0.1:7890", text: $config.vpnProxyUrl).textFieldStyle(.roundedBorder)
            }.padding(12)
        } label: { Label("代理", systemImage: "network.badge.shield.half.filled") }
    }

    private var timeoutSection: some View {
        GroupBox {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("首 Token 超时（秒）").font(.callout)
                    TextField("15", text: $config.firstTokenTimeout).textFieldStyle(.roundedBorder).frame(width: 80)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("最大重试次数").font(.callout)
                    TextField("3", text: $config.firstTokenMaxRetries).textFieldStyle(.roundedBorder).frame(width: 80)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("流式读取超时（秒）").font(.callout)
                    TextField("300", text: $config.streamingReadTimeout).textFieldStyle(.roundedBorder).frame(width: 80)
                }
            }.padding(12)
        } label: { Label("超时设置", systemImage: "clock") }
    }

    private var reasoningSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("启用 Fake Reasoning（推荐）", isOn: $config.fakeReasoning)
                if config.fakeReasoning {
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("最大思考 Token").font(.callout)
                            TextField("4000", text: $config.fakeReasoningMaxTokens).textFieldStyle(.roundedBorder).frame(width: 100)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text("处理方式").font(.callout)
                            Picker("", selection: $config.fakeReasoningHandling) {
                                Text("reasoning_content").tag("as_reasoning_content")
                                Text("移除").tag("remove")
                                Text("原样传递").tag("pass")
                                Text("仅去标签").tag("strip_tags")
                            }.frame(width: 180)
                        }
                    }
                }
            }.padding(12)
        } label: { Label("Fake Reasoning", systemImage: "brain") }
    }

    private var otherSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Toggle("截断恢复", isOn: $config.truncationRecovery)
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("日志级别").font(.callout)
                        Picker("", selection: $config.logLevel) {
                            ForEach(["TRACE", "DEBUG", "INFO", "WARNING", "ERROR"], id: \.self) { Text($0).tag($0) }
                        }.frame(width: 120)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("调试模式").font(.callout)
                        Picker("", selection: $config.debugMode) {
                            Text("关闭").tag("off"); Text("仅错误").tag("errors"); Text("全部").tag("all")
                        }.frame(width: 120)
                    }
                }
            }.padding(12)
        } label: { Label("其他", systemImage: "slider.horizontal.3") }
    }

    private var saveSection: some View {
        HStack {
            if showSaveConfirm {
                Label("已保存", systemImage: "checkmark.circle.fill").foregroundStyle(.green).transition(.opacity)
            }
            Spacer()
            if service.status == .running {
                Button("保存并重启") {
                    config.save(); showSaveConfirm = true; service.restart()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { showSaveConfirm = false } }
                }.buttonStyle(.bordered)
            }
            Button("保存") {
                config.save(); withAnimation { showSaveConfirm = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { withAnimation { showSaveConfirm = false } }
            }.buttonStyle(.borderedProminent)
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
    }
}
