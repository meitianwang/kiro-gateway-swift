import SwiftUI

/// 仪表盘视图 — 服务状态、启停控制、连接信息、模型列表、cURL 示例
struct DashboardView: View {

    @EnvironmentObject var config: ConfigManager
    @EnvironmentObject var service: GatewayService

    @State private var selectedProtocol: APIProtocol = .openai
    @State private var selectedModel: String?
    @State private var showApiKey = false
    @State private var copiedField: String?

    enum APIProtocol: String, CaseIterable {
        case openai = "OpenAI"
        case anthropic = "Anthropic"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                statusSection
                if service.status == .running {
                    connectionSection
                    modelSection
                    curlSection
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 服务状态

    private var statusSection: some View {
        GroupBox {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 12, height: 12)
                        .shadow(color: statusColor.opacity(0.5), radius: 6)
                    Text(service.status.label)
                        .font(.title3.weight(.medium))
                    Spacer()
                    controlButtons
                }

                if service.status == .running {
                    HStack {
                        Label("端口 \(config.serverPort)", systemImage: "network")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Label(
                            config.serverHost == "0.0.0.0" ? "局域网可访问" : "仅本机",
                            systemImage: config.serverHost == "0.0.0.0" ? "wifi" : "lock.shield"
                        )
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
        } label: {
            Label("服务状态", systemImage: "bolt.fill")
        }
    }

    @ViewBuilder
    private var controlButtons: some View {
        switch service.status {
        case .stopped, .error:
            Button {
                service.start()
            } label: {
                Label("启动", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)

        case .starting:
            ProgressView()
                .controlSize(.small)

        case .running:
            Button { service.restart() } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
            .help("重启")

            Button { service.stop() } label: {
                Image(systemName: "stop.fill")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
    }

    // MARK: - 连接信息

    private var connectionSection: some View {
        GroupBox {
            VStack(spacing: 10) {
                copyRow("API 地址", value: config.baseURL)
                Divider()
                HStack {
                    Text("API Key")
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .leading)
                    if showApiKey {
                        Text(config.proxyApiKey)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .lineLimit(1)
                    } else {
                        Text(String(repeating: "•", count: min(config.proxyApiKey.count, 24)))
                            .font(.system(.body, design: .monospaced))
                    }
                    Spacer()
                    Button {
                        showApiKey.toggle()
                    } label: {
                        Image(systemName: showApiKey ? "eye.slash" : "eye")
                    }
                    .buttonStyle(.borderless)
                    copyButton(config.proxyApiKey, field: "apikey")
                }
            }
            .padding(12)
        } label: {
            Label("连接信息", systemImage: "link")
        }
    }

    // MARK: - 模型列表

    /// 过滤掉 auto 开头的内部模型
    private var displayModels: [String] {
        service.availableModels.filter { !$0.hasPrefix("auto") }
    }

    private var modelSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                if service.isLoadingModels {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text("加载模型列表…").foregroundStyle(.secondary)
                    }
                    .padding(8)
                } else if displayModels.isEmpty {
                    HStack {
                        Text("暂无模型数据")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("刷新") { service.fetchModels() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                    .padding(8)
                } else {
                    HStack {
                        Text("\(displayModels.count) 个可用模型")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button {
                            service.fetchModels()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .buttonStyle(.borderless)
                        .help("刷新模型列表")
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 8)

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(displayModels, id: \.self) { model in
                                HStack {
                                    Text(model)
                                        .font(.system(.callout, design: .monospaced))
                                        .textSelection(.enabled)
                                    Spacer()
                                    copyButton(model, field: model)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(
                                    selectedModel == model
                                        ? Color.accentColor.opacity(0.12)
                                        : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 6)
                                )
                                .contentShape(Rectangle())
                                .onTapGesture { selectedModel = model }
                            }
                        }
                    }
                    .frame(maxHeight: 180)
                }
            }
        } label: {
            Label("可用模型", systemImage: "cpu")
        }
    }

    // MARK: - cURL 示例

    private var curlSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Picker("协议", selection: $selectedProtocol) {
                    ForEach(APIProtocol.allCases, id: \.self) { p in
                        Text(p.rawValue).tag(p)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 240)

                let curlCmd = curlExample
                HStack(alignment: .top) {
                    Text(curlCmd)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                    copyButton(curlCmd, field: "curl")
                }
            }
            .padding(12)
        } label: {
            Label("cURL 示例", systemImage: "terminal")
        }
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
              -d '{
                "model": "\(model)",
                "messages": [{"role": "user", "content": "Hello!"}]
              }'
            """
        case .anthropic:
            return """
            curl \(config.baseURL)/v1/messages \\
              -H "x-api-key: \(config.proxyApiKey)" \\
              -H "Content-Type: application/json" \\
              -H "anthropic-version: 2023-06-01" \\
              -d '{
                "model": "\(model)",
                "max_tokens": 1024,
                "messages": [{"role": "user", "content": "Hello!"}]
              }'
            """
        }
    }

    private func copyRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(1)
            Spacer()
            copyButton(value, field: label)
        }
    }

    private func copyButton(_ value: String, field: String) -> some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(value, forType: .string)
            copiedField = field
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if copiedField == field { copiedField = nil }
            }
        } label: {
            Image(systemName: copiedField == field ? "checkmark" : "doc.on.doc")
                .foregroundStyle(copiedField == field ? .green : .secondary)
        }
        .buttonStyle(.borderless)
        .help("复制")
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
