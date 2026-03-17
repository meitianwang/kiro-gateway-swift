import Foundation
import Combine

/// 管理 Kiro Gateway 的 .env 配置文件
/// 配置存储在 ~/.kiro-gateway/.env
final class ConfigManager: ObservableObject {

    static let shared = ConfigManager()

    // MARK: - 配置目录

    static var configDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".kiro-gateway")
    }

    static var envFileURL: URL {
        configDir.appendingPathComponent(".env")
    }

    // MARK: - Published 配置项

    // 必填
    @Published var proxyApiKey: String = "my-super-secret-password-123"

    // 认证方式（四选一）
    @Published var authMethod: AuthMethod = .refreshToken
    @Published var refreshToken: String = ""
    @Published var kiroCredsFile: String = ""
    @Published var kiroCliDbFile: String = ""

    // 可选
    @Published var profileArn: String = ""
    @Published var kiroRegion: String = "us-east-1"

    // 服务器
    @Published var serverHost: String = "127.0.0.1"
    @Published var serverPort: String = "9001"

    // 代理
    @Published var vpnProxyUrl: String = ""

    // 超时
    @Published var firstTokenTimeout: String = "15"
    @Published var firstTokenMaxRetries: String = "3"
    @Published var streamingReadTimeout: String = "300"

    // Fake Reasoning
    @Published var fakeReasoning: Bool = true
    @Published var fakeReasoningMaxTokens: String = "4000"
    @Published var fakeReasoningHandling: String = "as_reasoning_content"

    // Truncation Recovery
    @Published var truncationRecovery: Bool = true

    // 日志
    @Published var logLevel: String = "INFO"
    @Published var debugMode: String = "off"

    // MARK: - 状态

    @Published var isConfigured: Bool = false
    @Published var credsFileAutoDetected: Bool = false

    enum AuthMethod: String, CaseIterable, Identifiable {
        case refreshToken = "Refresh Token"
        case credsFile = "Kiro IDE 凭证文件"
        case cliDb = "kiro-cli 数据库"
        case ssoCache = "AWS SSO 缓存文件"

        var id: String { rawValue }
    }

    // MARK: - Init

    private init() {
        load()
        // 首次启动时自动检测凭证文件
        if kiroCredsFile.isEmpty && authMethod == .refreshToken && refreshToken.isEmpty {
            autoDetectCredsFile()
            if !kiroCredsFile.isEmpty {
                authMethod = .credsFile
                isConfigured = hasCredentials
            }
        }
    }

    // MARK: - 自动检测凭证文件

    /// 自动扫描 ~/.aws/sso/cache/kiro-auth-token.json
    func autoDetectCredsFile() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let defaultPath = "\(home)/.aws/sso/cache/kiro-auth-token.json"
        if FileManager.default.fileExists(atPath: defaultPath) {
            kiroCredsFile = defaultPath
            credsFileAutoDetected = true
        } else {
            credsFileAutoDetected = false
        }
    }

    // MARK: - 加载

    func load() {
        guard FileManager.default.fileExists(atPath: Self.envFileURL.path) else {
            isConfigured = false
            return
        }

        guard let content = try? String(contentsOf: Self.envFileURL, encoding: .utf8) else {
            isConfigured = false
            return
        }

        let values = parseEnv(content)

        proxyApiKey = values["PROXY_API_KEY"] ?? proxyApiKey
        refreshToken = values["REFRESH_TOKEN"] ?? ""
        kiroCredsFile = values["KIRO_CREDS_FILE"] ?? ""
        kiroCliDbFile = values["KIRO_CLI_DB_FILE"] ?? ""
        profileArn = values["PROFILE_ARN"] ?? ""
        kiroRegion = values["KIRO_REGION"] ?? "us-east-1"
        serverHost = values["SERVER_HOST"] ?? "127.0.0.1"
        serverPort = values["SERVER_PORT"] ?? "9001"
        vpnProxyUrl = values["VPN_PROXY_URL"] ?? ""
        firstTokenTimeout = values["FIRST_TOKEN_TIMEOUT"] ?? "15"
        firstTokenMaxRetries = values["FIRST_TOKEN_MAX_RETRIES"] ?? "3"
        streamingReadTimeout = values["STREAMING_READ_TIMEOUT"] ?? "300"
        logLevel = values["LOG_LEVEL"] ?? "INFO"
        debugMode = values["DEBUG_MODE"] ?? "off"

        fakeReasoning = (values["FAKE_REASONING"] ?? "true").lowercased() != "false"
        fakeReasoningMaxTokens = values["FAKE_REASONING_MAX_TOKENS"] ?? "4000"
        fakeReasoningHandling = values["FAKE_REASONING_HANDLING"] ?? "as_reasoning_content"
        truncationRecovery = (values["TRUNCATION_RECOVERY"] ?? "true").lowercased() != "false"

        // 推断认证方式
        if !kiroCliDbFile.isEmpty {
            authMethod = .cliDb
        } else if !kiroCredsFile.isEmpty {
            authMethod = kiroCredsFile.contains("sso/cache") ? .ssoCache : .credsFile
        } else {
            authMethod = .refreshToken
        }

        isConfigured = hasCredentials
    }

    // MARK: - 保存

    func save() {
        let fm = FileManager.default
        if !fm.fileExists(atPath: Self.configDir.path) {
            try? fm.createDirectory(at: Self.configDir, withIntermediateDirectories: true)
        }

        var lines: [String] = []
        lines.append("# Kiro Gateway Configuration")
        lines.append("# 由 Kiro Gateway.app 自动生成\n")

        lines.append("PROXY_API_KEY=\"\(proxyApiKey)\"\n")

        switch authMethod {
        case .refreshToken:
            if !refreshToken.isEmpty {
                lines.append("REFRESH_TOKEN=\"\(refreshToken)\"")
            }
        case .credsFile, .ssoCache:
            if !kiroCredsFile.isEmpty {
                lines.append("KIRO_CREDS_FILE=\"\(kiroCredsFile)\"")
            }
        case .cliDb:
            if !kiroCliDbFile.isEmpty {
                lines.append("KIRO_CLI_DB_FILE=\"\(kiroCliDbFile)\"")
            }
        }

        if !profileArn.isEmpty {
            lines.append("PROFILE_ARN=\"\(profileArn)\"")
        }
        if kiroRegion != "us-east-1" {
            lines.append("KIRO_REGION=\"\(kiroRegion)\"")
        }

        lines.append("")
        lines.append("SERVER_HOST=\"\(serverHost)\"")
        lines.append("SERVER_PORT=\"\(serverPort)\"")

        if !vpnProxyUrl.isEmpty {
            lines.append("VPN_PROXY_URL=\"\(vpnProxyUrl)\"")
        }

        lines.append("")
        lines.append("FIRST_TOKEN_TIMEOUT=\"\(firstTokenTimeout)\"")
        lines.append("FIRST_TOKEN_MAX_RETRIES=\"\(firstTokenMaxRetries)\"")
        lines.append("STREAMING_READ_TIMEOUT=\"\(streamingReadTimeout)\"")

        lines.append("")
        lines.append("FAKE_REASONING=\(fakeReasoning ? "true" : "false")")
        lines.append("FAKE_REASONING_MAX_TOKENS=\(fakeReasoningMaxTokens)")
        lines.append("FAKE_REASONING_HANDLING=\(fakeReasoningHandling)")

        lines.append("")
        lines.append("TRUNCATION_RECOVERY=\(truncationRecovery ? "true" : "false")")

        lines.append("")
        lines.append("LOG_LEVEL=\"\(logLevel)\"")
        lines.append("DEBUG_MODE=\(debugMode)")

        let content = lines.joined(separator: "\n") + "\n"
        try? content.write(to: Self.envFileURL, atomically: true, encoding: .utf8)

        isConfigured = hasCredentials
    }

    // MARK: - Helpers

    var hasCredentials: Bool {
        switch authMethod {
        case .refreshToken: return !refreshToken.isEmpty
        case .credsFile, .ssoCache: return !kiroCredsFile.isEmpty
        case .cliDb: return !kiroCliDbFile.isEmpty
        }
    }

    var port: Int {
        Int(serverPort) ?? 9001
    }

    var baseURL: String {
        let host = serverHost == "0.0.0.0" ? "localhost" : serverHost
        return "http://\(host):\(serverPort)"
    }

    private func parseEnv(_ content: String) -> [String: String] {
        var result: [String: String] = [:]
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            guard let eqIndex = trimmed.firstIndex(of: "=") else { continue }
            let key = String(trimmed[trimmed.startIndex..<eqIndex])
                .trimmingCharacters(in: .whitespaces)
            var value = String(trimmed[trimmed.index(after: eqIndex)...])
                .trimmingCharacters(in: .whitespaces)
            // 去掉引号
            if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
               (value.hasPrefix("'") && value.hasSuffix("'")) {
                value = String(value.dropFirst().dropLast())
            }
            result[key] = value
        }
        return result
    }
}
