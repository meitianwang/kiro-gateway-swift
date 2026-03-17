import SwiftUI

/// 请求日志视图 — 展示每个请求的状态、模型、耗时、时间
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
        HStack(spacing: 12) {
            TextField("搜索…", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 240)

            Picker("状态", selection: $selectedStatus) {
                ForEach(StatusFilter.allCases, id: \.self) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 200)

            Spacer()

            Text("\(filteredLogs.count) 条记录")
                .font(.callout)
                .foregroundStyle(.secondary)

            Button {
                service.clearRequestLogs()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("清空日志")
        }
        .padding(10)
    }

    // MARK: - 空状态

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("暂无请求记录")
                .font(.title3)
                .foregroundStyle(.secondary)
            if service.status != .running {
                Text("启动服务后，请求日志将在此显示")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - 日志表格

    private var logTable: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                // 表头
                HStack(spacing: 0) {
                    headerCell("状态", width: 60)
                    headerCell("方法", width: 60)
                    headerCell("路径", width: 180)
                    headerCell("模型", width: 180)
                    headerCell("耗时", width: 80)
                    headerCell("时间", width: 140)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(nsColor: .controlBackgroundColor))

                ForEach(filteredLogs) { entry in
                    logRow(entry)
                }
            }
        }
    }

    private func headerCell(_ title: String, width: CGFloat) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(width: width, alignment: .leading)
    }

    private func logRow(_ entry: RequestLogEntry) -> some View {
        HStack(spacing: 0) {
            // 状态码
            Text("\(entry.statusCode)")
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(entry.statusCode >= 400 ? .red : .green)
                .frame(width: 60, alignment: .leading)

            // 方法
            Text(entry.method)
                .font(.system(.callout, design: .monospaced))
                .frame(width: 60, alignment: .leading)

            // 路径
            Text(entry.path)
                .font(.system(.callout, design: .monospaced))
                .lineLimit(1)
                .frame(width: 180, alignment: .leading)

            // 模型
            Text(entry.model)
                .font(.system(.callout, design: .monospaced))
                .lineLimit(1)
                .frame(width: 180, alignment: .leading)

            // 耗时
            Text(entry.durationText)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)

            // 时间
            Text(entry.timeText)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 140, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
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
