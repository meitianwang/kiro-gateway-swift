import SwiftUI

struct RequestLogView: View {

    @EnvironmentObject var config: ConfigManager
    @EnvironmentObject var service: GatewayService

    @State private var searchText = ""
    @State private var selectedStatus: StatusFilter = .all
    @State private var hoveredRow: UUID?
    @State private var expandedRow: UUID?
    @State private var detailData: RequestDetail?
    @State private var detailLoading = false

    private let teal = Color(red: 0.16, green: 0.71, blue: 0.55)

    enum StatusFilter: String, CaseIterable {
        case all = "全部"
        case success = "成功"
        case error = "失败"
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            if filteredLogs.isEmpty {
                emptyState
            } else {
                logTable
            }
        }
    }

    // MARK: - 工具栏

    private var toolbar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                TextField("搜索…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .frame(maxWidth: 200)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5), in: RoundedRectangle(cornerRadius: 6))

            HStack(spacing: 0) {
                ForEach(StatusFilter.allCases, id: \.self) { f in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedStatus = f
                        }
                    } label: {
                        Text(f.rawValue)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                selectedStatus == f
                                    ? teal.opacity(0.15)
                                    : Color.clear,
                                in: RoundedRectangle(cornerRadius: 5)
                            )
                            .foregroundStyle(selectedStatus == f ? teal : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.3), in: RoundedRectangle(cornerRadius: 7))

            Spacer()

            Text("\(filteredLogs.count) 条")
                .font(.caption2)
                .foregroundStyle(.quaternary)

            Button {
                service.clearRequestLogs()
                expandedRow = nil
                detailData = nil
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("清空")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [teal.opacity(0.06), Color.clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 50
                        )
                    )
                    .frame(width: 100, height: 100)

                Circle()
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .frame(width: 60, height: 60)
                    .shadow(color: .black.opacity(0.05), radius: 6, y: 2)

                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(.tertiary)
            }

            VStack(spacing: 4) {
                Text("暂无请求记录")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                if service.status != .running {
                    Text("启动服务后将在此显示")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 表格

    private var logTable: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                HStack(spacing: 0) {
                    headerCell("状态", width: 54)
                    headerCell("方法", width: 50)
                    headerCell("路径", flex: true)
                    headerCell("模型", flex: true)
                    headerCell("耗时", width: 72)
                    headerCell("时间", width: 72)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))

                Divider()

                ForEach(filteredLogs) { entry in
                    VStack(spacing: 0) {
                        logRow(entry)

                        if expandedRow == entry.id {
                            detailPanel(entry)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func headerCell(_ title: String, width: CGFloat? = nil, flex: Bool = false) -> some View {
        if flex {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
                .frame(width: width ?? 50, alignment: .leading)
        }
    }

    private func logRow(_ entry: RequestLogEntry) -> some View {
        HStack(spacing: 0) {
            // 展开指示器
            Image(systemName: expandedRow == entry.id ? "chevron.down" : "chevron.right")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(entry.rid != nil ? .tertiary : .quaternary)
                .frame(width: 16)

            Text("\(entry.statusCode)")
                .font(.system(.caption, design: .monospaced, weight: .semibold))
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(
                    entry.statusCode >= 400
                        ? Color.red.opacity(0.1)
                        : teal.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 4)
                )
                .foregroundStyle(entry.statusCode >= 400 ? .red : teal)
                .frame(width: 54, alignment: .leading)

            Text(entry.method)
                .font(.system(.caption, design: .monospaced, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)

            Text(entry.path)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(entry.model)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(entry.durationText)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 72, alignment: .leading)

            Text(entry.timeText)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 72, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(
            expandedRow == entry.id
                ? teal.opacity(0.06)
                : (hoveredRow == entry.id ? teal.opacity(0.03) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) {
                if expandedRow == entry.id {
                    expandedRow = nil
                    detailData = nil
                } else {
                    expandedRow = entry.id
                    detailData = nil
                    fetchDetail(entry)
                }
            }
        }
        .onHover { isHovered in
            hoveredRow = isHovered ? entry.id : nil
        }
        .overlay(alignment: .bottom) {
            if expandedRow != entry.id {
                Divider().opacity(0.3)
            }
        }
    }

    // MARK: - Detail Panel

    @ViewBuilder
    private func detailPanel(_ entry: RequestLogEntry) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if detailLoading {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("加载中…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(16)
            } else if let detail = detailData {
                // Summary header
                HStack(spacing: 16) {
                    detailBadge("消息数", value: "\(detail.messagesCount)")
                    detailBadge("工具数", value: "\(detail.toolsCount)")
                    if !detail.model.isEmpty {
                        detailBadge("模型", value: detail.model)
                    }
                    Spacer()
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(detail.fullJSON, forType: .string)
                    } label: {
                        Label("复制完整请求", systemImage: "doc.on.doc")
                            .font(.caption2)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

                // System prompt
                if !detail.systemPreview.isEmpty {
                    detailSection("System Prompt") {
                        Text(detail.systemPreview)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.7))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color(red: 0.11, green: 0.12, blue: 0.14), in: RoundedRectangle(cornerRadius: 6))
                    }
                }

                // Messages (last 10)
                if !detail.messages.isEmpty {
                    detailSection("最近 \(detail.messages.count) 条消息") {
                        VStack(spacing: 2) {
                            ForEach(Array(detail.messages.enumerated()), id: \.offset) { idx, msg in
                                HStack(alignment: .top, spacing: 8) {
                                    Text(msg.role)
                                        .font(.system(.caption2, design: .monospaced, weight: .semibold))
                                        .foregroundStyle(roleColor(msg.role))
                                        .frame(width: 55, alignment: .trailing)

                                    Text(msg.preview)
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundStyle(Color.white.opacity(0.6))
                                        .lineLimit(3)
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 10)
                                .background(
                                    idx % 2 == 0 ? Color.clear : Color.white.opacity(0.02)
                                )
                            }
                        }
                        .background(Color(red: 0.11, green: 0.12, blue: 0.14), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            } else if entry.rid == nil {
                Text("此请求无详细数据（需要重启服务以启用请求历史）")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(16)
            } else {
                Text("加载失败")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(16)
            }
        }
        .padding(.bottom, 8)
        .background(teal.opacity(0.03))
        .overlay(alignment: .bottom) {
            Divider().opacity(0.3)
        }
    }

    private func detailBadge(_ label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.caption2.weight(.medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(teal.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
                .foregroundStyle(teal)
        }
    }

    private func detailSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            content()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func roleColor(_ role: String) -> Color {
        switch role {
        case "system": return .orange
        case "user": return teal
        case "assistant": return Color(red: 0.55, green: 0.82, blue: 0.96)
        case "tool": return Color(red: 0.78, green: 0.58, blue: 0.96)
        default: return .secondary
        }
    }

    // MARK: - Fetch Detail

    private func fetchDetail(_ entry: RequestLogEntry) {
        guard let rid = entry.rid else { return }
        let entryId = entry.id
        detailLoading = true

        let urlStr = "\(ConfigManager.shared.baseURL)/request-history/\(rid)"
        guard let url = URL(string: urlStr) else {
            detailLoading = false
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                guard expandedRow == entryId else { return }
                detailLoading = false
                guard let data = data, error == nil else { return }
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

                let summary = json["summary"] as? [String: Any] ?? [:]
                let messages = (summary["messages"] as? [[String: Any]] ?? []).map {
                    MessagePreview(
                        role: $0["role"] as? String ?? "",
                        preview: $0["preview"] as? String ?? ""
                    )
                }

                // Also fetch full JSON for copy
                let fullUrlStr = "\(ConfigManager.shared.baseURL)/request-history/\(rid)/full"
                if let fullUrl = URL(string: fullUrlStr) {
                    URLSession.shared.dataTask(with: fullUrl) { fullData, _, _ in
                        var fullJSON = ""
                        if let fullData = fullData,
                           let fullObj = try? JSONSerialization.jsonObject(with: fullData),
                           let prettyData = try? JSONSerialization.data(withJSONObject: fullObj, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]) {
                            fullJSON = String(data: prettyData, encoding: .utf8) ?? ""
                        }

                        DispatchQueue.main.async {
                            guard self.expandedRow == entryId else { return }
                            self.detailData = RequestDetail(
                                model: summary["model"] as? String ?? "",
                                messagesCount: summary["messages_count"] as? Int ?? 0,
                                toolsCount: summary["tools_count"] as? Int ?? 0,
                                systemPreview: summary["system_preview"] as? String ?? "",
                                messages: messages,
                                fullJSON: fullJSON
                            )
                        }
                    }.resume()
                }
            }
        }.resume()
    }

    // MARK: - 过滤

    private var filteredLogs: [RequestLogEntry] {
        var result = service.requestLogs
        switch selectedStatus {
        case .all: break
        case .success: result = result.filter { $0.statusCode < 400 }
        case .error: result = result.filter { $0.statusCode >= 400 }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.path.localizedCaseInsensitiveContains(searchText) ||
                $0.model.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }
}

// MARK: - Models

struct RequestDetail {
    let model: String
    let messagesCount: Int
    let toolsCount: Int
    let systemPreview: String
    let messages: [MessagePreview]
    let fullJSON: String
}

struct MessagePreview {
    let role: String
    let preview: String
}
