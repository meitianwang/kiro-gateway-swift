import SwiftUI

struct LogView: View {

    @EnvironmentObject var service: GatewayService
    @State private var autoScroll = true
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            HStack {
                TextField("搜索日志…", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 300)

                Spacer()

                Toggle("自动滚动", isOn: $autoScroll)
                    .toggleStyle(.switch)
                    .controlSize(.small)

                Button {
                    service.clearLogs()
                } label: {
                    Image(systemName: "trash")
                }
                .help("清空日志")
            }
            .padding(8)

            Divider()

            // 日志内容
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(Array(filteredLogs.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(logColor(for: line))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 1)
                                .id(index)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .background(Color(nsColor: .textBackgroundColor))
                .onChange(of: service.logs.count) { _ in
                    if autoScroll, let last = filteredLogs.indices.last {
                        withAnimation {
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
