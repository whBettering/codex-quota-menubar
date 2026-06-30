import Foundation

public enum JSONRPCWireError: Error, Equatable, CustomStringConvertible {
    case invalidLine(String)
    case missingResult
    case remote(code: Int, message: String)

    public var description: String {
        switch self {
        case .invalidLine(let line):
            return "Invalid JSON-RPC line: \(line)"
        case .missingResult:
            return "JSON-RPC response did not include a result"
        case .remote(let code, let message):
            return "JSON-RPC error \(code): \(message)"
        }
    }
}

public enum JSONRPC {
    public static func makeRequestLine(id: Int, method: String, params: Any? = nil) throws -> String {
        var object: [String: Any] = [
            "id": id,
            "method": method
        ]

        if let params {
            object["params"] = params
        }

        return try makeLine(from: object)
    }

    public static func makeNotificationLine(method: String, params: Any? = nil) throws -> String {
        var object: [String: Any] = [
            "method": method
        ]

        if let params {
            object["params"] = params
        }

        return try makeLine(from: object)
    }

    public static func extractResultData(fromLine line: String, matchingId expectedId: Int) throws -> Data? {
        guard
            let data = line.data(using: .utf8),
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw JSONRPCWireError.invalidLine(line)
        }

        guard matchesId(object["id"], expectedId: expectedId) else {
            return nil
        }

        if let error = object["error"] as? [String: Any] {
            let code = error["code"] as? Int ?? -1
            let message = error["message"] as? String ?? "Unknown JSON-RPC error"
            throw JSONRPCWireError.remote(code: code, message: message)
        }

        guard let result = object["result"] else {
            throw JSONRPCWireError.missingResult
        }

        if result is NSNull {
            return Data("null".utf8)
        }

        return try JSONSerialization.data(withJSONObject: result)
    }

    private static func makeLine(from object: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        return String(decoding: data, as: UTF8.self) + "\n"
    }

    private static func matchesId(_ value: Any?, expectedId: Int) -> Bool {
        if let intValue = value as? Int {
            return intValue == expectedId
        }

        if let stringValue = value as? String {
            return stringValue == String(expectedId)
        }

        return false
    }
}
