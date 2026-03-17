import SwiftUI

struct DashboardView: View {

    @EnvironmentObject var config: ConfigManager
    @EnvironmentObject var service: GatewayService

    @State private var selectedProtocol: APIProtocol = .openai
    @State private var selectedModel: String?
    @State private var showApiKey = false
    @State private var copiedField: String?
    @State private var hoveredModel: String?

    // Claude Code 配置
    @State private var claudeOpusModel: String = ""
    @State private var claudeSonnetModel: String = ""
    @State private var claudeHaikuModel: String = ""
    @State private var claudeConfigSaving = false
    @State private var claudeConfigSaved = false
    @State private var claudeConfigResetting = false
    @State private var claudeConfigReset = false

    enum APIProtocol: String, CaseIterable {
        case openai = "OpenAI"
        case anthropic = "Anthropic"
    }

    private let teal = Color(red: 0.16, green: 0.71, blue: 0.55)

    var body: some View {
        if service.status == .running {
            ScrollView {
                VStack(spacing: 20) {
                    statusCards
                    claudeConfigSection

                    HStack(alignment: .top, spacing: 16) {
                        modelList
                        curlSection
                    }
                }
                .padding(24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
        } else {
            stoppedView
        }
    }

    // MARK: - 未运行

    private var stoppedView: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [teal.opacity(0.08), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)

                Circle()
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .frame(width: 72, height: 72)
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 2)

                Image(systemName: "bolt.slash")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(.tertiary)
            }

            VStack(spacing: 6) {
                Text("服务未运行")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
                Text("点击顶部启动按钮开始")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 状态卡片

    private var statusCards: some View {
        HStack(spacing: 12) {
            // 地址
            VStack(alignment: .leading, spacing: 10) {
                Label("API 地址", systemImage: "link")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    Text(config.baseURL)
                        .font(.system(.callout, design: .monospaced, weight: .medium))
                        .textSelection(.enabled)
                        .lineLimit(1)
                    Spacer()
                    copyBtn(config.baseURL, field: "url")
                }
            }
            .cardStyle()

            // 密钥
            VStack(alignment: .leading, spacing: 10) {
                Label("API 密钥", systemImage: "key.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 6) {
                    if showApiKey {
                        Text(config.proxyApiKey)
                            .font(.system(.callout, design: .monospaced, weight: .medium))
                            .textSelection(.enabled)
                            .lineLimit(1)
                    } else {
                        Text(String(repeating: "•", count: min(config.proxyApiKey.count, 20)))
                            .font(.system(.callout, design: .monospaced))
                    }
                    Spacer()
                    Button { showApiKey.toggle() } label: {
                        Image(systemName: showApiKey ? "eye.slash" : "eye")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    copyBtn(config.proxyApiKey, field: "key")
                }
            }
            .cardStyle()

            // 端口
            VStack(alignment: .leading, spacing: 10) {
                Label("端口", systemImage: "network")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Text(config.serverPort)
                        .font(.system(.title2, design: .rounded, weight: .semibold))

                    Text(config.serverHost == "0.0.0.0" ? "局域网" : "本机")
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(teal.opacity(0.1), in: Capsule())
                        .foregroundStyle(teal)

                    Spacer()
                }
            }
            .cardStyle()
        }
    }

    // MARK: - Claude Code 配置

    private var claudeConfigSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "terminal")
                    .font(.caption)
                    .foregroundStyle(teal)
                Text("Claude Code")
                    .font(.callout.weight(.medium))
                Text("~/.claude/settings.json")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.6), in: Capsule())
                Spacer()
            }

            HStack(spacing: 16) {
                modelPicker("Opus", selection: $claudeOpusModel)
                modelPicker("Sonnet", selection: $claudeSonnetModel)
                modelPicker("Haiku", selection: $claudeHaikuModel)

                Spacer()

                Button {
                    resetClaudeConfig()
                } label: {
                    if claudeConfigResetting {
                        ProgressView().controlSize(.mini)
                    } else if claudeConfigReset {
                        Label("已还原", systemImage: "checkmark")
                            .font(.caption)
                    } else {
                        Label("还原配置", systemImage: "arrow.counterclockwise")
                            .font(.caption)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(claudeConfigResetting)

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
                .tint(teal)
                .controlSize(.small)
                .disabled(claudeConfigSaving)
            }
        }
        .cardStyle()
        .onAppear { loadClaudeConfig() }
    }

    private func modelPicker(_ label: String, selection: Binding<String>) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize()
            Picker("", selection: selection) {
                Text("(空)").tag("")
                ForEach(service.availableModels, id: \.self) { m in
                    Text(m).tag(m)
                }
            }
            .labelsHidden()
            .frame(minWidth: 160)
        }
    }

    // MARK: - 模型列表

    private var displayModels: [String] {
        service.availableModels.filter { !$0.hasPrefix("auto") }
    }

    private var modelList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "cpu")
                        .font(.caption)
                        .foregroundStyle(teal)
                    Text("可用模型")
                        .font(.callout.weight(.medium))
                }
                Spacer()
                if service.isLoadingModels {
                    ProgressView().controlSize(.mini)
                } else {
                    Text("\(displayModels.count)")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(teal.opacity(0.1), in: Capsule())
                        .foregroundStyle(teal)
                    Button { service.fetchModels() } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }

            if displayModels.isEmpty && !service.isLoadingModels {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.title3)
                        .foregroundStyle(.quaternary)
                    Text("暂无模型")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                VStack(spacing: 2) {
                    ForEach(displayModels, id: \.self) { model in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(teal.opacity(0.6))
                                .frame(width: 5, height: 5)
                            Text(model)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                            Spacer()
                            copyBtn(model, field: model)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(
                            hoveredModel == model
                                ? teal.opacity(0.06)
                                : (selectedModel == model ? teal.opacity(0.04) : Color.clear),
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture { selectedModel = model }
                        .onHover { h in hoveredModel = h ? model : nil }
                    }
                }
            }
        }
        .cardStyle()
        .frame(minWidth: 260)
    }

    // MARK: - cURL 示例 (Dark IDE Style)

    private var curlSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.caption)
                        .foregroundStyle(teal)
                    Text("cURL 示例")
                        .font(.callout.weight(.medium))
                }
                Spacer()

                // Protocol toggle
                HStack(spacing: 0) {
                    ForEach(APIProtocol.allCases, id: \.self) { p in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedProtocol = p
                            }
                        } label: {
                            Text(p.rawValue)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(
                                    selectedProtocol == p
                                        ? teal
                                        : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 5)
                                )
                                .foregroundStyle(selectedProtocol == p ? .white : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(2)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5), in: RoundedRectangle(cornerRadius: 7))
            }

            // Dark code block
            let cmd = curlExample
            ZStack(alignment: .topTrailing) {
                ScrollView([.horizontal, .vertical], showsIndicators: false) {
                    curlHighlighted(cmd)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 120)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(red: 0.11, green: 0.12, blue: 0.14))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                )

                // Copy button on dark bg
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(cmd, forType: .string)
                    copiedField = "curl"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        if copiedField == "curl" { copiedField = nil }
                    }
                } label: {
                    Image(systemName: copiedField == "curl" ? "checkmark" : "doc.on.doc")
                        .font(.caption2)
                        .foregroundStyle(copiedField == "curl" ? .green : Color.white.opacity(0.4))
                        .padding(6)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
                }
                .buttonStyle(.plain)
                .padding(10)
            }
        }
        .cardStyle()
    }

    // Syntax-highlighted cURL
    private func curlHighlighted(_ code: String) -> some View {
        let lines = code.components(separatedBy: "\n")
        return VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(lines.enumerated()), id: \.offset) { idx, line in
                HStack(alignment: .top, spacing: 0) {
                    Text("\(idx + 1)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.2))
                        .frame(width: 20, alignment: .trailing)
                        .padding(.trailing, 12)

                    highlightedLine(line)
                }
            }
        }
    }

    private func highlightedLine(_ line: String) -> Text {
        var result = Text("")
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        let leadingSpaces = String(line.prefix(while: { $0 == " " }))

        if !leadingSpaces.isEmpty {
            result = result + Text(leadingSpaces).font(.system(.caption, design: .monospaced)).foregroundColor(Color.white.opacity(0.7))
        }

        // Simple token-based highlighting
        let tokens = trimmed.components(separatedBy: " ")
        for (i, token) in tokens.enumerated() {
            if i > 0 {
                result = result + Text(" ").font(.system(.caption, design: .monospaced)).foregroundColor(Color.white.opacity(0.7))
            }

            if token == "curl" {
                result = result + Text(token).font(.system(.caption, design: .monospaced).weight(.semibold)).foregroundColor(Color(red: 0.55, green: 0.82, blue: 0.96))
            } else if token == "-H" || token == "-d" {
                result = result + Text(token).font(.system(.caption, design: .monospaced).weight(.medium)).foregroundColor(Color(red: 0.78, green: 0.58, blue: 0.96))
            } else if token == "\\" {
                result = result + Text(token).font(.system(.caption, design: .monospaced)).foregroundColor(Color.white.opacity(0.3))
            } else if token.hasPrefix("\"") || token.hasPrefix("'") {
                result = result + Text(token).font(.system(.caption, design: .monospaced)).foregroundColor(Color(red: 0.81, green: 0.89, blue: 0.53))
            } else if token.contains("://") {
                result = result + Text(token).font(.system(.caption, design: .monospaced)).foregroundColor(Color(red: 0.38, green: 0.79, blue: 0.69))
            } else {
                result = result + Text(token).font(.system(.caption, design: .monospaced)).foregroundColor(Color.white.opacity(0.7))
            }
        }

        return result
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

    private func resetClaudeConfig() {
        claudeConfigResetting = true
        let url = Self.claudeSettingsURL
        let dir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let defaultSettings: [String: Any] = [
            "model": "opus",
            "skipDangerousModePermissionPrompt": true
        ]

        if let data = try? JSONSerialization.data(withJSONObject: defaultSettings, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]) {
            try? data.write(to: url)
        }

        // Clear local state
        claudeOpusModel = ""
        claudeSonnetModel = ""
        claudeHaikuModel = ""

        claudeConfigResetting = false
        claudeConfigReset = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { claudeConfigReset = false }
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
                .foregroundStyle(copiedField == field ? teal : Color.secondary)
        }
        .buttonStyle(.borderless)
        .help("复制")
    }
}

// MARK: - Card Modifier

extension View {
    func cardStyle() -> some View {
        self
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(.background, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
    }
}
