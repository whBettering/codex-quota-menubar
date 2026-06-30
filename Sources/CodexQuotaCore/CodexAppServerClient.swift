import Foundation

public protocol QuotaFetching: Sendable {
    func fetchQuota() async throws -> QuotaSnapshot
}

public enum CodexAppServerClientError: Error, Equatable, CustomStringConvertible {
    case binaryNotFound(String)
    case timedOut
    case missingResponse

    public var description: String {
        switch self {
        case .binaryNotFound(let path):
            return "Codex binary was not found at \(path)"
        case .timedOut:
            return "Timed out waiting for Codex app-server quota response"
        case .missingResponse:
            return "Codex app-server did not return a quota response"
        }
    }
}

public final class CodexAppServerClient: QuotaFetching, @unchecked Sendable {
    private let binaryPath: String
    private let timeoutSeconds: TimeInterval

    public init(
        binaryPath: String = CodexAppServerClient.resolveCodexBinaryPath(),
        timeoutSeconds: TimeInterval = 8
    ) {
        self.binaryPath = binaryPath
        self.timeoutSeconds = timeoutSeconds
    }

    public static func resolveCodexBinaryPath(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) -> String {
        if let override = environment["CODEX_QUOTA_CODEX_BIN"], !override.isEmpty {
            return override
        }

        let candidates = [
            "/Applications/Codex.app/Contents/Resources/codex",
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex"
        ]

        return candidates.first { fileManager.isExecutableFile(atPath: $0) } ?? candidates[0]
    }

    public func fetchQuota() async throws -> QuotaSnapshot {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    continuation.resume(returning: try self.fetchQuotaBlocking())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func fetchQuotaBlocking() throws -> QuotaSnapshot {
        guard FileManager.default.isExecutableFile(atPath: binaryPath) else {
            throw CodexAppServerClientError.binaryNotFound(binaryPath)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = ["app-server", "--stdio"]

        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        let accumulator = JSONRPCLineAccumulator(expectedId: 2)
        let responseSignal = DispatchSemaphore(value: 0)

        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                return
            }

            if accumulator.append(data: data) {
                responseSignal.signal()
            }
        }

        defer {
            outputPipe.fileHandleForReading.readabilityHandler = nil
            if process.isRunning {
                process.terminate()
                process.waitUntilExit()
            }
            try? inputPipe.fileHandleForWriting.close()
            try? outputPipe.fileHandleForReading.close()
            try? errorPipe.fileHandleForReading.close()
        }

        try process.run()

        let lines = try [
            JSONRPC.makeRequestLine(id: 1, method: "initialize", params: [
                "clientInfo": [
                    "name": "codex-quota-widget",
                    "title": "Codex Quota Widget",
                    "version": "0.1.0"
                ],
                "capabilities": [
                    "experimentalApi": true,
                    "requestAttestation": false,
                    "optOutNotificationMethods": []
                ]
            ]),
            JSONRPC.makeNotificationLine(method: "initialized"),
            JSONRPC.makeRequestLine(id: 2, method: "account/rateLimits/read")
        ].joined()

        inputPipe.fileHandleForWriting.write(Data(lines.utf8))

        let result = responseSignal.wait(timeout: .now() + timeoutSeconds)
        guard result == .success else {
            throw CodexAppServerClientError.timedOut
        }

        if let error = accumulator.error {
            throw error
        }

        guard let data = accumulator.resultData else {
            throw CodexAppServerClientError.missingResponse
        }

        let response = try JSONDecoder().decode(GetAccountRateLimitsResponse.self, from: data)
        return try QuotaMapper.makeSnapshot(from: response)
    }
}

private final class JSONRPCLineAccumulator: @unchecked Sendable {
    private let expectedId: Int
    private let lock = NSLock()
    private var buffer = ""

    private(set) var resultData: Data?
    private(set) var error: Error?

    init(expectedId: Int) {
        self.expectedId = expectedId
    }

    func append(data: Data) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        buffer += String(decoding: data, as: UTF8.self)
        var didComplete = false

        while let lineRange = buffer.range(of: "\n") {
            let line = String(buffer[..<lineRange.lowerBound])
            buffer.removeSubrange(buffer.startIndex...lineRange.lowerBound)

            guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }

            do {
                if let data = try JSONRPC.extractResultData(fromLine: line, matchingId: expectedId) {
                    resultData = data
                    didComplete = true
                }
            } catch {
                self.error = error
                didComplete = true
            }
        }

        return didComplete
    }
}
