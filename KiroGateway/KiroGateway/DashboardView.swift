import SwiftUI

struct DashboardView: View {

    @EnvironmentObject var config: ConfigManager
    @EnvironmentObject var service: GatewayService

    @State private var selectedProtocol: APIProtocol = .openai
    @State private var selectedModel: String?
    @State private var showApiKey = false
    @State private var copiedField: String?

    // Claude Code 配置
    @State private var claudeOpusModel: String = ""
    @State private var claudeSonnetModel: String = ""
    @State private var claudeHaikuModel: String = ""
    @State private var claudeConfigSaving = false
    @State private var claudeConfigSaved = false

    enum APIProtocol: String, CaseIterable {
        case openai = "OpenAI"
        case anthropic = "Anthropic"
    }

    var body: some View {
        if service.status == .running {
            ScrollView {
                VStack(spacing: 12) {
                    connectionBar
                    claudeConfigSection
                    HStack(alignment: .top, spacing: 12) {
                        modelList
                        curlSection
                    }
                }
                .padding(16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
        } else {
            stoppedView
        }
    }

    // MARK: - 未运行

    private var stoppedView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "bolt.slash")
                .font(.system(size: 32))
                .foregroundStyle(.quaternary)
            Text("服务未运行")
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
            Text("点击右上角启动按钮开始")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 连接信息（紧凑横条）

    private var connectionBar: some View {
        HStack(spacing: 20) {
            // 地址
            HStack(spacing: 6) {
                Text("地址")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text(config.baseURL)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
                copyBtn(config.baseURL, field: "url")
            }

            Divider().frame(height: 16)

            // 密钥
            HStack(spacing: 6) {
                Text("密钥")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                if showApiKey {
                    Text(config.proxyApiKey)
                        .font(.system(.callout, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(1)
                } else {
                    Text(String(repeating: "•", count: min(config.proxyApiKey.count, 16)))
                        .font(.system(.callout, design: .monospaced))
                }
                Button { showApiKey.toggle() } label: {
                    Image(systemName: showApiKey ? "eye.slash" : "eye")
                        .font(.caption2)
                }
                .buttonStyle(.borderless)
                copyBtn(config.proxyApiKey, field: "key")
            }

            Divider().frame(height: 16)

            // 端口
            HStack(spacing: 6) {
                Text("端口")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text(config.serverPort)
                    .font(.system(.callout, design: .monospaced))
                Text(config.serverHost == "0.0.0.0" ? "局域网" : "本机")
                    .font(.caption2)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Color.accentColor.opacity(0.08), in: Capsule())
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .cardStyle()
    }

    // MARK: - Claude Code 配置

    private var claudeConfigSection: some View {
        HStack(spacing: 16) {
            HStack(spacing: 4) {
                Image(systemName: "terminal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Claude Code")
                    .font(.callout.weight(.medium))
                Text("~/.claude/settings.json")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            HStack(spacing: 12) {
                modelPicker("Opus", selection: $claudeOpusModel)
                modelPicker("Sonnet", selection: $claudeSonnetModel)
                modelPicker("Haiku", selection: $claudeHaikuModel)
            }

            Button {
                saveClaudeConfig()
            } label: {
                if claudeConfigSaving {
                    ProgressView().controlSize(.mini)
                } else if claudeConfigSaved {
                    Label("已保存", systemImage: "checkmark")
                        .font(.caption)
                } else {
                    Label("写入配置", systemImage: "square.and.arrow.down")
                        .font(.caption)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(claudeConfigSaving)
        }
        .cardStyle()
        .onAppear { loadClaudeConfig() }
    }

    private func modelPicker(_ label: String, selection: Binding<String>) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.tertiary)
            Picker("", selection: selection) {
                Text("(空)").tag("")
                ForEach(service.availableModels, id: \.self) { m in
                    Text(m).tag(m)
                }
            }
            .labelsHidden()
            .frame(width: 160)
        }
    }

    // MARK: - 模型列表

    private var displayModels: [String] {
        service.availableModels.filter { !$0.hasPrefix("auto") }
    }

    private var modelList: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("可用模型", systemImage: "cpu")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if service.isLoadingModels {
                    ProgressView().controlSize(.mini)
                } else {
                    Text("\(displayModels.count)")
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.accentColor.opacity(0.08), in: Capsule())
                        .foregroundStyle(.secondary)
                    Button { service.fetchModels() } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption2)
                    }
                    .buttonStyle(.borderless)
                }
            }

            if displayModels.isEmpty && !service.isLoadingModels {
                Text("暂无模型")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                VStack(spacing: 0) {
                    ForEach(displayModels, id: \.self) { model in
                        HStack {
                            Text(model)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                            Spacer()
                            copyBtn(model, field: model)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 6)
                        .background(
                            selectedModel == model
                                ? Color.accentColor.opacity(0.06)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 4)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { selectedModel = model }
                    }
                }
            }
        }
        .cardStyle()
        .frame(minWidth: 240)
    }

    // MARK: - cURL 示例

    private var curlSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("cURL 示例", systemImage: "chevronleft.forwardslash.chevronright")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: $selectedProtocol) {
                    ForEach(APIProtocol.allCases, id: \.self) { p in
                        Text(p.rawValue).tag(p)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }

            let cmd = curlExample
            ZStack(alignment: .topTrailing) {
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    Text(cmd)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))

                copyBtn(cmd, field: "curl")
                    .padding(6)
            }
        }
        .cardStyle()
    }

    // MARK: - Claude Config IO

    private static var claudeSettingsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude")
            .appendingPathComponent("settings.json")
    }

    private func loadClaudeConfig() {
        let url = Self.claudeSettingsURL
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let env = json["env"] as? [String: Any] else { return }
        claudeOpusModel = env["ANTHROPIC_DEFAULT_OPUS_MODEL"] as? String ?? ""
        claudeSonnetModel = env["ANTHROPIC_DEFAULT_SONNET_MODEL"] as? String ?? ""
        claudeHaikuModel = env["ANTHROPIC_DEFAULT_HAIKU_MODEL"] as? String ?? ""
    }

    private func saveClaudeConfig() {
        claudeConfigSaving = true
        let url = Self.claudeSettingsURL
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        var settings: [String: Any] = [:]
        if let data = try? Data(contentsOf: url),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            settings = existing
        }

        let cfg = ConfigManager.shared
        settings["env"] = [
            "ANTHROPIC_AUTH_TOKEN": cfg.proxyApiKey,
            "ANTHROPIC_BASE_URL": cfg.baseURL,
            "ANTHROPIC_DEFAULT_OPUS_MODEL": claudeOpusModel,
            "ANTHROPIC_DEFAULT_SONNET_MODEL": claudeSonnetModel,
            "ANTHROPIC_DEFAULT_HAIKU_MODEL": claudeHaikuModel,
            "API_TIMEOUT_MS": "3000000",
            "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1",
        ]

        if let data = try? JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]) {
            try? data.write(to: url)
        }

        claudeConfigSaving = false
        claudeConfigSaved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { claudeConfigSaved = false }
    }

    // MARK: - Helpers

    private var curlExample: String {
        let model = selectedModel ?? displayModels.first ?? "claude-sonnet-4-20250514"
        switch selectedProtocol {
        case .openai:
            return """
            curl \(config.baseURL)/v1/chat/completions \\
              -H "Authorization: Bearer \(config.proxyApiKey)" \\
              -H "Content-Type: application/json" \\
              -d '{"model": "\(model)", "messages": [{"role": "user", "content": "Hello!"}]}'
            """
        case .anthropic:
            return """
            curl \(config.baseURL)/v1/messages \\
              -H "x-api-key: \(config.proxyApiKey)" \\
              -H "Content-Type: application/json" \\
              -H "anthropic-version: 2023-06-01" \\
              -d '{"model": "\(model)", "max_tokens": 1024, "messages": [{"role": "user", "content": "Hello!"}]}'
            """
        }
    }

    private func copyBtn(_ value: String, field: String) -> some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(value, forType: .string)
            copiedField = field
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if copiedField == field { copiedField = nil }
            }
        } label: {
            Image(systemName: copiedField == field ? "checkmark" : "doc.on.doc")
                .font(.caption2)
                .foregroundStyle(copiedField == field ? Color.green : Color.secondary)
        }
        .buttonStyle(.borderless)
        .help("复制")
    }
}

// MARK: - Card Modifier

extension View {
    func cardStyle() -> some View {
        self
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(.background, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
            )
    }
}
