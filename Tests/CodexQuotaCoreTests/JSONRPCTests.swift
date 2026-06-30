import Foundation
import CodexQuotaCore

func testBuildsAccountRateLimitRequestLine() throws {
    let line = try JSONRPC.makeRequestLine(id: 2, method: "account/rateLimits/read")
    let object = try JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any]

    try expectEqual(object?["id"] as? Int, 2, "request id")
    try expectEqual(object?["method"] as? String, "account/rateLimits/read", "request method")
    try expectEqual(line.hasSuffix("\n"), true, "request newline")
}

func testExtractsResultForMatchingResponseId() throws {
    let line = #"{"id":2,"result":{"rateLimits":{"limitId":"codex","limitName":null,"primary":null,"secondary":null,"credits":null,"individualLimit":null,"planType":"plus","rateLimitReachedType":null},"rateLimitsByLimitId":null,"rateLimitResetCredits":null}}"#

    let data = try JSONRPC.extractResultData(fromLine: line, matchingId: 2)
    let response = try JSONDecoder().decode(GetAccountRateLimitsResponse.self, from: data!)

    try expectEqual(response.rateLimits.limitId, "codex", "response limit id")
    try expectEqual(response.rateLimits.planType, "plus", "response plan type")
}

func testIgnoresNotificationLines() throws {
    let line = #"{"method":"account/rateLimits/updated","params":{}}"#
    try expectEqual(try JSONRPC.extractResultData(fromLine: line, matchingId: 2) == nil, true, "notification ignored")
}

func testThrowsForMatchingErrorResponse() throws {
    let line = #"{"id":2,"error":{"code":-32000,"message":"not logged in"}}"#

    try expectThrows(JSONRPCWireError.remote(code: -32000, message: "not logged in"), "matching error response") {
        _ = try JSONRPC.extractResultData(fromLine: line, matchingId: 2)
    }
}
