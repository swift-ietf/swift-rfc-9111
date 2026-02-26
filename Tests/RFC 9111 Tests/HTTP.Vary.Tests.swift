// HTTP.Vary.Tests.swift
// swift-rfc-9111

import Testing

@testable import RFC_9111

@Suite
struct `HTTP.Vary Tests` {

    @Test
    func `Vary creation with field names`() async throws {
        let vary = HTTP.Vary(fieldNames: ["Accept-Encoding", "Accept-Language"])

        #expect(vary.fieldNames == ["accept-encoding", "accept-language"])  // Lowercased
        #expect(!vary.variesOnAllAspects)
    }

    @Test
    func `Vary.all - varies on all aspects`() async throws {
        let vary = HTTP.Vary.all

        #expect(vary.fieldNames.isEmpty)
        #expect(vary.variesOnAllAspects)
    }

    @Test
    func `Header value - field names`() async throws {
        let vary = HTTP.Vary(fieldNames: ["Accept-Encoding", "Accept-Language"])

        #expect(vary.headerValue == "accept-encoding, accept-language")
    }

    @Test
    func `Header value - all aspects`() async throws {
        let vary = HTTP.Vary.all

        #expect(vary.headerValue == "*")
    }

    @Test
    func `Parse field names`() async throws {
        let parsed = HTTP.Vary.parse("Accept-Encoding, User-Agent")

        #expect(parsed != nil)
        #expect(parsed?.fieldNames == ["accept-encoding", "user-agent"])
        #expect(parsed?.variesOnAllAspects == false)
    }

    @Test
    func `Parse all aspects`() async throws {
        let parsed = HTTP.Vary.parse("*")

        #expect(parsed != nil)
        #expect(parsed?.variesOnAllAspects == true)
    }

    @Test
    func `Parse with whitespace`() async throws {
        let parsed = HTTP.Vary.parse("  Accept-Encoding ,  User-Agent  ")

        #expect(parsed != nil)
        #expect(parsed?.fieldNames == ["accept-encoding", "user-agent"])
    }

    @Test
    func `Parse empty string`() async throws {
        #expect(HTTP.Vary.parse("") == nil)
        #expect(HTTP.Vary.parse("  ") == nil)
    }

    @Test
    func `includes - field name present`() async throws {
        let vary = HTTP.Vary(fieldNames: ["Accept-Encoding", "User-Agent"])

        #expect(vary.includes("Accept-Encoding"))
        #expect(vary.includes("accept-encoding"))  // Case-insensitive
        #expect(vary.includes("User-Agent"))
    }

    @Test
    func `includes - field name absent`() async throws {
        let vary = HTTP.Vary(fieldNames: ["Accept-Encoding"])

        #expect(!vary.includes("Cookie"))
        #expect(!vary.includes("User-Agent"))
    }

    @Test
    func `includes - all aspects`() async throws {
        let vary = HTTP.Vary.all

        #expect(vary.includes("Accept-Encoding"))
        #expect(vary.includes("Cookie"))
        #expect(vary.includes("anything"))
    }

    @Test
    func `matches - same headers`() async throws {
        let vary = HTTP.Vary(fieldNames: ["Accept-Encoding"])

        let result = vary.matches(
            requestHeaders: ["accept-encoding": "gzip"],
            cachedRequestHeaders: ["accept-encoding": "gzip"]
        )

        #expect(result == true)
    }

    @Test
    func `matches - different headers`() async throws {
        let vary = HTTP.Vary(fieldNames: ["Accept-Encoding"])

        let result = vary.matches(
            requestHeaders: ["accept-encoding": "br"],
            cachedRequestHeaders: ["accept-encoding": "gzip"]
        )

        #expect(result == false)
    }

    @Test
    func `matches - all aspects never matches`() async throws {
        let vary = HTTP.Vary.all

        let result = vary.matches(
            requestHeaders: ["accept-encoding": "gzip"],
            cachedRequestHeaders: ["accept-encoding": "gzip"]
        )

        #expect(result == false)
    }

    @Test
    func `matches - multiple fields`() async throws {
        let vary = HTTP.Vary(fieldNames: ["Accept-Encoding", "User-Agent"])

        let result1 = vary.matches(
            requestHeaders: ["accept-encoding": "gzip", "user-agent": "Mozilla"],
            cachedRequestHeaders: ["accept-encoding": "gzip", "user-agent": "Mozilla"]
        )
        #expect(result1 == true)

        let result2 = vary.matches(
            requestHeaders: ["accept-encoding": "gzip", "user-agent": "Chrome"],
            cachedRequestHeaders: ["accept-encoding": "gzip", "user-agent": "Mozilla"]
        )
        #expect(result2 == false)
    }

    @Test
    func `Equality`() async throws {
        let vary1 = HTTP.Vary(fieldNames: ["Accept-Encoding"])
        let vary2 = HTTP.Vary(fieldNames: ["Accept-Encoding"])
        let vary3 = HTTP.Vary(fieldNames: ["User-Agent"])
        let vary4 = HTTP.Vary.all

        #expect(vary1 == vary2)
        #expect(vary1 != vary3)
        #expect(vary1 != vary4)
    }

    @Test
    func `Hashable`() async throws {
        var set: Set<HTTP.Vary> = []

        set.insert(HTTP.Vary(fieldNames: ["Accept-Encoding"]))
        set.insert(HTTP.Vary(fieldNames: ["Accept-Encoding"]))  // Duplicate
        set.insert(HTTP.Vary(fieldNames: ["User-Agent"]))
        set.insert(HTTP.Vary.all)

        #expect(set.count == 3)
    }

    @Test
    func `Codable`() async throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let vary = HTTP.Vary(fieldNames: ["Accept-Encoding", "User-Agent"])
        let encoded = try encoder.encode(vary)
        let decoded = try decoder.decode(HTTP.Vary.self, from: encoded)

        #expect(decoded == vary)
    }

    @Test
    func `Description`() async throws {
        let vary = HTTP.Vary(fieldNames: ["Accept-Encoding"])

        #expect(vary.description == "accept-encoding")
    }

    @Test
    func `LosslessStringConvertible`() async throws {
        let vary = HTTP.Vary("Accept-Encoding, User-Agent")

        #expect(vary != nil)
        #expect(vary?.fieldNames == ["accept-encoding", "user-agent"])
    }

    @Test
    func `ExpressibleByArrayLiteral`() async throws {
        let vary: HTTP.Vary = ["Accept-Encoding", "User-Agent"]

        #expect(vary.fieldNames == ["accept-encoding", "user-agent"])
    }

    @Test
    func `Round trip - format and parse`() async throws {
        let original = HTTP.Vary(fieldNames: ["Accept-Encoding", "User-Agent"])
        let headerValue = original.headerValue
        let parsed = HTTP.Vary.parse(headerValue)

        #expect(parsed != nil)
        #expect(parsed == original)
    }
}
