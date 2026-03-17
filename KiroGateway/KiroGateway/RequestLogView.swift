import SwiftUI

struct RequestLogView: View {

    @EnvironmentObject var service: GatewayService

    @State private var searchText = ""
    @State private var selectedStatus: StatusFilter = .all
    @State private var hoveredRow: UUID?

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

            // Custom segmented filter
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
                // 表头
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
                    logRow(entry)
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
            // 状态码
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

            // 方法
            Text(entry.method)
                .font(.system(.caption, design: .monospaced, weight: .medium))
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
                .frame(width: 72, alignment: .leading)

            // 时间
            Text(entry.timeText)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 72, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(
            hoveredRow == entry.id
                ? teal.opacity(0.04)
                : Color.clear
        )
        .onHover { isHovered in
            hoveredRow = isHovered ? entry.id : nil
        }
        .overlay(alignment: .bottom) {
            Divider().opacity(0.3)
        }
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
