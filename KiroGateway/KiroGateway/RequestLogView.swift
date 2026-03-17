import SwiftUI

struct RequestLogView: View {

    @EnvironmentObject var service: GatewayService

    @State private var searchText = ""
    @State private var selectedStatus: StatusFilter = .all

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
            Image(systemName: "magnifyingglass")
                .font(.caption)
                .foregroundStyle(.tertiary)
            TextField("搜索…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.callout)
                .frame(maxWidth: 200)

            Picker("", selection: $selectedStatus) {
                ForEach(StatusFilter.allCases, id: \.self) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 160)

            Spacer()

            Text("\(filteredLogs.count) 条")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Button {
                service.clearRequestLogs()
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("清空")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(.quaternary)
            Text("暂无请求记录")
                .font(.callout)
                .foregroundStyle(.tertiary)
            if service.status != .running {
                Text("启动服务后将在此显示")
                    .font(.caption)
                    .foregroundStyle(.quaternary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 表格

    private var logTable: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // 表头
                HStack(spacing: 0) {
                    headerCell("状态", width: 50)
                    headerCell("方法", width: 50)
                    headerCell("路径", flex: true)
                    headerCell("模型", flex: true)
                    headerCell("耗时", width: 70)
                    headerCell("时间", width: 70)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))

                Divider()

                ForEach(filteredLogs) { entry in
                    logRow(entry)
                    Divider().opacity(0.5)
                }
            }
        }
    }

    @ViewBuilder
    private func headerCell(_ title: String, width: CGFloat? = nil, flex: Bool = false) -> some View {
        if flex {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.tertiary)
                .frame(width: width ?? 50, alignment: .leading)
        }
    }

    private func logRow(_ entry: RequestLogEntry) -> some View {
        HStack(spacing: 0) {
            // 状态码
            Text("\(entry.statusCode)")
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(
                    entry.statusCode >= 400
                        ? Color.red.opacity(0.1)
                        : Color.green.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 3)
                )
                .foregroundStyle(entry.statusCode >= 400 ? .red : .green)
                .frame(width: 50, alignment: .leading)

            // 方法
            Text(entry.method)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)

            // 路径
            Text(entry.path)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 模型
            Text(entry.model)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            // 耗时
            Text(entry.durationText)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 70, alignment: .leading)

            // 时间
            Text(entry.timeText)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 70, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
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
