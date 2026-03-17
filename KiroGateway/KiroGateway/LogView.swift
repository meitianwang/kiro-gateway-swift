import SwiftUI

struct LogView: View {

    @EnvironmentObject var service: GatewayService
    @State private var autoScroll = true
    @State private var searchText = ""

    private let teal = Color(red: 0.16, green: 0.71, blue: 0.55)

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            HStack(spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    TextField("搜索日志…", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.callout)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5), in: RoundedRectangle(cornerRadius: 6))

                Spacer()

                Text("\(filteredLogs.count) 行")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)

                Toggle(isOn: $autoScroll) {
                    Text("自动滚动")
                        .font(.caption)
                }
                .toggleStyle(.switch)
                .controlSize(.mini)
                .tint(teal)

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
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.bar)

            Divider()

            // Dark terminal-style log area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(filteredLogs.enumerated()), id: \.offset) { index, line in
                            HStack(alignment: .top, spacing: 0) {
                                Text("\(index + 1)")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(Color.white.opacity(0.2))
                                    .frame(width: 36, alignment: .trailing)
                                    .padding(.trailing, 10)

                                Text(line)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(logColor(for: line))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 2)
                            .background(
                                index % 2 == 0
                                    ? Color.clear
                                    : Color.white.opacity(0.02)
                            )
                            .id(index)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .background(Color(red: 0.11, green: 0.12, blue: 0.14))
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
        var result = service.logs.filter {
            !$0.localizedCaseInsensitiveContains("health")
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }

    private func logColor(for line: String) -> Color {
        if line.contains("ERROR") || line.contains("❌") { return Color(red: 0.95, green: 0.45, blue: 0.45) }
        if line.contains("WARNING") || line.contains("⚠️") { return Color(red: 0.95, green: 0.75, blue: 0.35) }
        if line.contains("✅") || line.contains("SUCCESS") { return Color(red: 0.38, green: 0.82, blue: 0.62) }
        if line.contains("DEBUG") { return Color.white.opacity(0.4) }
        return Color.white.opacity(0.7)
    }
}
