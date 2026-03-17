import SwiftUI

struct LogView: View {

    @EnvironmentObject var service: GatewayService
    @State private var autoScroll = true
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                TextField("搜索日志…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.callout)

                Spacer()

                Toggle(isOn: $autoScroll) {
                    Text("自动滚动")
                        .font(.caption)
                }
                .toggleStyle(.switch)
                .controlSize(.mini)

                Button {
                    service.clearLogs()
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

            Divider()

            // 日志内容
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(filteredLogs.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(logColor(for: line))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 2)
                                .id(index)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .background(Color(nsColor: .textBackgroundColor))
                .onChange(of: service.logs.count) { _ in
                    if autoScroll, let last = filteredLogs.indices.last {
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo(last, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    private var filteredLogs: [String] {
        if searchText.isEmpty { return service.logs }
        return service.logs.filter {
            $0.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func logColor(for line: String) -> Color {
        if line.contains("ERROR") || line.contains("❌") { return .red }
        if line.contains("WARNING") || line.contains("⚠️") { return .orange }
        if line.contains("✅") || line.contains("SUCCESS") { return .green }
        if line.contains("DEBUG") { return .secondary }
        return .primary
    }
}
