import Foundation
import Combine

/// 请求日志条目
struct RequestLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let method: String
    let path: String
    let statusCode: Int
    let model: String
    let duration: TimeInterval

    var timeText: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss"
        return fmt.string(from: timestamp)
    }

    var durationText: String {
        if duration < 1 {
            return String(format: "%.0fms", duration * 1000)
        }
        return String(format: "%.1fs", duration)
    }
}

/// 管理 Python Gateway 子进程的生命周期
/// Gateway 源码打包在 app bundle 的 Resources/gateway/ 目录中
/// Python 依赖在首次启动时安装到 ~/.kiro-gateway/venv/
@MainActor
final class GatewayService: ObservableObject {

    static let shared = GatewayService()

    enum Status: Equatable {
        case stopped
        case starting
        case running
        case error(String)

        var label: String {
            switch self {
            case .stopped: return "已停止"
            case .starting: return "启动中…"
            case .running: return "运行中"
            case .error(let msg): return "错误: \(msg)"
            }
        }
    }

    @Published var status: Status = .stopped
    @Published private(set) var logs: [String] = []
    @Published private(set) var requestLogs: [RequestLogEntry] = []
    @Published private(set) var availableModels: [String] = []
    @Published var isLoadingModels: Bool = false
    @Published private(set) var pythonPath: String = ""
    @Published private(set) var isSettingUpVenv: Bool = false

    private var process: Process?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    private var healthCheckTimer: Timer?

    private let maxLogLines = 2000

    /// Gateway 源码在 bundle 内的路径
    var gatewayPath: String {
        if let resourcePath = Bundle.main.resourcePath {
            return URL(fileURLWithPath: resourcePath)
                .appendingPathComponent("gateway").path
        }
        return ""
    }

    /// venv 目录：~/.kiro-gateway/venv
    var venvDir: URL {
        ConfigManager.configDir.appendingPathComponent("venv")
    }

    /// venv 内的 python
    var venvPython: String {
        venvDir.appendingPathComponent("bin/python3").path
    }

    /// bundle 内的 requirements.txt
    var requirementsPath: String {
        URL(fileURLWithPath: gatewayPath)
            .appendingPathComponent("requirements.txt").path
    }

    /// venv 是否已就绪（python 可执行 + 核心依赖已安装）
    var isVenvReady: Bool {
        guard FileManager.default.isExecutableFile(atPath: venvPython) else { return false }
        let result = shell("\(venvPython) -c \"import httpx, fastapi; print('ok')\" 2>&1")
        return result?.trimmingCharacters(in: .whitespacesAndNewlines) == "ok"
    }

    var isGatewayAvailable: Bool {
        let mainPy = URL(fileURLWithPath: gatewayPath)
            .appendingPathComponent("main.py")
        return FileManager.default.fileExists(atPath: mainPy.path)
    }

    var isPythonAvailable: Bool { !pythonPath.isEmpty }

    private init() {
        detectPython()
    }

    // MARK: - Python 检测

    func detectPython() {
        if let result = shell("which python3"),
           !result.isEmpty {
            let path = result.trimmingCharacters(in: .whitespacesAndNewlines)
            if FileManager.default.isExecutableFile(atPath: path) {
                pythonPath = path
                return
            }
        }
        let candidates = [
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/usr/bin/python3",
            "\(NSHomeDirectory())/.pyenv/shims/python3",
        ]
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                pythonPath = path
                return
            }
        }
        pythonPath = ""
    }

    // MARK: - Venv 管理

    /// 创建 venv 并安装依赖（后台执行）
    private func setupVenv(completion: @escaping (Bool) -> Void) {
        guard isPythonAvailable else {
            appendLog("❌ 未找到 Python3")
            completion(false)
            return
        }

        isSettingUpVenv = true
        appendLog("📦 首次启动，正在创建 Python 虚拟环境...")
        appendLog("   路径: \(venvDir.path)")

        // 在主线程上捕获所有需要的值
        let python = pythonPath
        let venvPath = venvDir.path
        let venvPy = venvPython
        let reqPath = requirementsPath

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // 1. 创建 venv
            let createResult = self.shell("\(python) -m venv \(venvPath)")
            if !FileManager.default.isExecutableFile(atPath: venvPy) {
                Task { @MainActor [weak self] in
                    self?.appendLog("❌ 创建虚拟环境失败: \(createResult ?? "unknown error")")
                    self?.isSettingUpVenv = false
                    completion(false)
                }
                return
            }

            Task { @MainActor [weak self] in
                self?.appendLog("✅ 虚拟环境已创建")
                self?.appendLog("📦 正在安装依赖（首次可能需要 1-2 分钟）...")
            }

            // 2. 安装依赖
            let pipResult = self.shell("\(venvPy) -m pip install --no-cache-dir -r \(reqPath) 2>&1")

            // 验证安装成功（检查 fastapi 能否 import）
            let verifyResult = self.shell("\(venvPy) -c \"import fastapi; print('ok')\" 2>&1")
            let success = verifyResult?.trimmingCharacters(in: .whitespacesAndNewlines) == "ok"

            Task { @MainActor [weak self] in
                self?.isSettingUpVenv = false
                if success {
                    self?.appendLog("✅ 依赖安装完成")
                } else {
                    self?.appendLog("❌ 依赖安装失败")
                    if let output = pipResult {
                        let lines = output.components(separatedBy: .newlines).suffix(5)
                        for line in lines where !line.isEmpty {
                            self?.appendLog("   \(line)")
                        }
                    }
                }
                completion(success)
            }
        }
    }

    // MARK: - 启动 / 停止

    func start() {
        guard status == .stopped || isErrorStatus else { return }
        guard isPythonAvailable else {
            status = .error("未找到 Python3，请先安装 Python 3.10+")
            return
        }
        guard isGatewayAvailable else {
            status = .error("Gateway 资源缺失，请重新安装应用")
            return
        }

        status = .starting
        logs.removeAll()

        // 检查 venv 是否就绪
        if isVenvReady {
            launchGateway()
        } else {
            appendLog("🚀 准备启动 Kiro Gateway...")
            setupVenv { [weak self] success in
                guard let self = self else { return }
                if success {
                    self.launchGateway()
                } else {
                    self.status = .error("依赖安装失败，请检查网络连接")
                }
            }
        }
    }

    private func launchGateway() {
        let config = ConfigManager.shared
        config.save()
        killPortProcess(port: config.serverPort)

        appendLog("🚀 启动 Kiro Gateway...")
        appendLog("   端口: \(config.serverPort)")

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: venvPython)
        proc.arguments = ["main.py", "--host", config.serverHost, "--port", config.serverPort]
        proc.currentDirectoryURL = URL(fileURLWithPath: gatewayPath)

        var env = ProcessInfo.processInfo.environment
        env["DOTENV_PATH"] = ConfigManager.envFileURL.path
        proc.environment = env

        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe
        outputPipe = outPipe
        errorPipe = errPipe

        outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor [weak self] in self?.appendLog(text) }
        }

        errPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor [weak self] in self?.appendLog(text) }
        }

        proc.terminationHandler = { [weak self] process in
            Task { @MainActor [weak self] in
                self?.healthCheckTimer?.invalidate()
                self?.healthCheckTimer = nil
                if self?.status == .running || self?.status == .starting {
                    let code = process.terminationStatus
                    if code == 0 || code == 15 || code == 9 {
                        self?.status = .stopped
                        self?.appendLog("⏹ 服务已停止")
                    } else {
                        self?.status = .error("进程退出码: \(code)")
                        self?.appendLog("❌ 进程异常退出 (code: \(code))")
                    }
                }
            }
        }

        do {
            try proc.run()
            process = proc
            startHealthCheck()
        } catch {
            status = .error(error.localizedDescription)
            appendLog("❌ 启动失败: \(error.localizedDescription)")
        }
    }

    func stop() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil

        guard let proc = process, proc.isRunning else {
            process = nil
            status = .stopped
            return
        }

        appendLog("⏹ 正在停止服务...")
        proc.terminationHandler = nil
        proc.terminate()

        DispatchQueue.global().async { [weak self] in
            proc.waitUntilExit()
            if proc.isRunning {
                proc.interrupt()
                proc.waitUntilExit()
            }

            Task { @MainActor [weak self] in
                self?.outputPipe?.fileHandleForReading.readabilityHandler = nil
                self?.errorPipe?.fileHandleForReading.readabilityHandler = nil
                self?.outputPipe = nil
                self?.errorPipe = nil
                self?.process = nil
                self?.status = .stopped
                self?.appendLog("⏹ 服务已停止")
            }
        }
    }

    func restart() {
        guard let proc = process, proc.isRunning else {
            start()
            return
        }

        appendLog("🔄 正在重启...")
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
        proc.terminationHandler = nil
        proc.terminate()

        DispatchQueue.global().async { [weak self] in
            proc.waitUntilExit()
            if proc.isRunning { proc.interrupt(); proc.waitUntilExit() }

            Task { @MainActor [weak self] in
                self?.outputPipe?.fileHandleForReading.readabilityHandler = nil
                self?.errorPipe?.fileHandleForReading.readabilityHandler = nil
                self?.outputPipe = nil
                self?.errorPipe = nil
                self?.process = nil
                self?.status = .stopped
                self?.start()
            }
        }
    }

    // MARK: - 健康检查

    private func startHealthCheck() {
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { [weak self] in await self?.checkHealth() }
        }
    }

    private func checkHealth() async {
        let config = ConfigManager.shared
        guard let url = URL(string: "\(config.baseURL)/health") else { return }

        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                if status == .starting {
                    status = .running
                    appendLog("✅ 服务已就绪: \(config.baseURL)")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                        self?.fetchModels()
                    }
                }
            }
        } catch {
            if status == .running {
                status = .error("健康检查失败")
            }
        }
    }

    // MARK: - 日志

    func appendLog(_ text: String) {
        let lines = text.components(separatedBy: .newlines)
            .filter { !$0.isEmpty }
        logs.append(contentsOf: lines)
        if logs.count > maxLogLines {
            logs.removeFirst(logs.count - maxLogLines)
        }
        for line in lines {
            parseRequestLog(line)
        }
    }

    func clearLogs() { logs.removeAll() }

    func clearRequestLogs() { requestLogs.removeAll() }

    // MARK: - 模型列表

    func fetchModels(retryCount: Int = 0) {
        let config = ConfigManager.shared
        guard let url = URL(string: "\(config.baseURL)/v1/models") else { return }

        isLoadingModels = true
        var request = URLRequest(url: url)
        request.setValue("Bearer \(config.proxyApiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isLoadingModels = false

                if let error = error {
                    self.appendLog("⚠️ 获取模型列表失败: \(error.localizedDescription)")
                    if retryCount < 2 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                            self?.fetchModels(retryCount: retryCount + 1)
                        }
                    }
                    return
                }

                if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                    self.appendLog("⚠️ 获取模型列表返回 \(http.statusCode)")
                    if retryCount < 2 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                            self?.fetchModels(retryCount: retryCount + 1)
                        }
                    }
                    return
                }

                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let dataArray = json["data"] as? [[String: Any]] else {
                    if retryCount < 2 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                            self?.fetchModels(retryCount: retryCount + 1)
                        }
                    }
                    return
                }

                self.availableModels = dataArray
                    .compactMap { $0["id"] as? String }
                    .sorted()
                self.appendLog("📋 已加载 \(self.availableModels.count) 个模型")
            }
        }.resume()
    }

    // MARK: - 请求日志解析

    private func parseRequestLog(_ line: String) {
        guard line.contains("[GATEWAY_REQUEST]") else { return }

        let ansiPattern = "\u{1B}\\[[0-9;]*m"
        let cleanLine = line.replacingOccurrences(of: ansiPattern, with: "", options: .regularExpression)

        func extractValue(_ key: String) -> String? {
            guard let range = cleanLine.range(of: "\(key)=") else { return nil }
            let after = cleanLine[range.upperBound...]
            let value = after.prefix(while: { $0 != " " && $0 != "\n" && $0 != "\r" })
            return String(value)
        }

        let method = extractValue("method") ?? "POST"
        let path = extractValue("path") ?? "-"
        let code = Int(extractValue("status") ?? "0") ?? 0
        let model = extractValue("model") ?? "-"
        let durationStr = extractValue("duration") ?? "0ms"
        let durationMs = Double(durationStr.replacingOccurrences(of: "ms", with: "")) ?? 0
        let duration = durationMs / 1000.0

        let entry = RequestLogEntry(
            timestamp: Date(),
            method: method,
            path: path,
            statusCode: code,
            model: model,
            duration: duration
        )
        requestLogs.insert(entry, at: 0)
        if requestLogs.count > 500 { requestLogs.removeLast() }
    }

    // MARK: - Helpers

    private var isErrorStatus: Bool {
        if case .error = status { return true }
        return false
    }

    private nonisolated func killPortProcess(port: String) {
        guard let result = shell("lsof -ti tcp:\(port)"),
              !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let pids = result.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines)
        for pid in pids {
            _ = shell("kill -9 \(pid)")
        }
        Thread.sleep(forTimeInterval: 0.3)
    }

    private nonisolated func shell(_ command: String) -> String? {
        let proc = Process()
        let pipe = Pipe()
        proc.executableURL = URL(fileURLWithPath: "/bin/bash")
        proc.arguments = ["-l", "-c", command]
        proc.standardOutput = pipe
        proc.standardError = pipe
        try? proc.run()
        proc.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)
    }
}
