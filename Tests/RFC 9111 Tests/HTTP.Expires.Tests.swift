// HTTP.Expires.Tests.swift
// swift-rfc-9111

import Testing

@testable import RFC_9111

@Suite
struct `HTTP.Expires Tests` {

    @Test
    func `Expires creation`() async throws {
        let date = Date(timeIntervalSince1970: 1_445_412_480)
        let expires = HTTP.Expires(date: date)

        #expect(expires.date == date)
    }

    @Test
    func `Header value format`() async throws {
        let date = Date(timeIntervalSince1970: 784_111_777)  // Sun, 06 Nov 1994 08:49:37 GMT
        let expires = HTTP.Expires(date: date)

        let headerValue = expires.headerValue

        #expect(headerValue.contains("Sun"))
        #expect(headerValue.contains("06 Nov 1994"))
        #expect(headerValue.contains("GMT"))
    }

    @Test
    func `Parse valid expires`() async throws {
        let parsed = HTTP.Expires.parse("Sun, 06 Nov 1994 08:49:37 GMT")

        #expect(parsed != nil)

        let expectedDate = Date(timeIntervalSince1970: 784_111_777)
        let diff = abs(parsed!.date.timeIntervalSince(expectedDate))
        #expect(diff < 1.0)  // Within 1 second
    }

    @Test
    func `Parse invalid expires`() async throws {
        #expect(HTTP.Expires.parse("invalid") == nil)
        #expect(HTTP.Expires.parse("") == nil)
        #expect(HTTP.Expires.parse("2024-11-16") == nil)  // Wrong format
    }

    @Test
    func `isExpired - past date`() async throws {
        let pastDate = Date().addingTimeInterval(-3600)  // 1 hour ago
        let expires = HTTP.Expires(date: pastDate)

        #expect(expires.isExpired())
    }

    @Test
    func `isExpired - future date`() async throws {
        let futureDate = Date().addingTimeInterval(3600)  // 1 hour from now
        let expires = HTTP.Expires(date: futureDate)

        #expect(!expires.isExpired())
    }

    @Test
    func `isExpired - custom now`() async throws {
        let expirationDate = Date(timeIntervalSince1970: 1_000_000)
        let expires = HTTP.Expires(date: expirationDate)

        let beforeExpiration = Date(timeIntervalSince1970: 999999)
        let afterExpiration = Date(timeIntervalSince1970: 1_000_001)

        #expect(!expires.isExpired(at: beforeExpiration))
        #expect(expires.isExpired(at: afterExpiration))
    }

    @Test
    func `timeRemaining - positive`() async throws {
        let futureDate = Date().addingTimeInterval(3600)  // 1 hour from now
        let expires = HTTP.Expires(date: futureDate)

        let remaining = expires.timeRemaining()

        #expect(remaining > 3500)  // Approximately 3600, allowing for test execution time
        #expect(remaining < 3700)
    }

    @Test
    func `timeRemaining - negative`() async throws {
        let pastDate = Date().addingTimeInterval(-3600)  // 1 hour ago
        let expires = HTTP.Expires(date: pastDate)

        let remaining = expires.timeRemaining()

        #expect(remaining < -3500)  // Negative value
        #expect(remaining > -3700)
    }

    @Test
    func `Equality`() async throws {
        let date1 = Date(timeIntervalSince1970: 784_111_777)
        let date2 = Date(timeIntervalSince1970: 784_111_777)
        let date3 = Date(timeIntervalSince1970: 784_111_778)

        let expires1 = HTTP.Expires(date: date1)
        let expires2 = HTTP.Expires(date: date2)
        let expires3 = HTTP.Expires(date: date3)

        #expect(expires1 == expires2)
        #expect(expires1 != expires3)
    }

    @Test
    func `Hashable`() async throws {
        var set: Set<HTTP.Expires> = []
        let date = Date(timeIntervalSince1970: 784_111_777)

        set.insert(HTTP.Expires(date: date))
        set.insert(HTTP.Expires(date: date))  // Duplicate
        set.insert(HTTP.Expires(date: Date(timeIntervalSince1970: 784_111_778)))

        #expect(set.count == 2)
    }

    @Test
    func `Comparable`() async throws {
        let earlier = HTTP.Expires(date: Date(timeIntervalSince1970: 1000))
        let later = HTTP.Expires(date: Date(timeIntervalSince1970: 2000))

        #expect(earlier < later)
        #expect(later > earlier)
    }

    @Test
    func `Codable`() async throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let date = Date(timeIntervalSince1970: 784_111_777)
        let expires = HTTP.Expires(date: date)

        let encoded = try encoder.encode(expires)
        let decoded = try decoder.decode(HTTP.Expires.self, from: encoded)

        let diff = abs(decoded.date.timeIntervalSince(expires.date))
        #expect(diff < 1.0)  // Within 1 second
    }

    @Test
    func `Description`() async throws {
        let date = Date(timeIntervalSince1970: 784_111_777)
        let expires = HTTP.Expires(date: date)

        let description = expires.description

        #expect(description.contains("Sun"))
        #expect(description.contains("GMT"))
    }

    @Test
    func `LosslessStringConvertible`() async throws {
        let expires = HTTP.Expires("Sun, 06 Nov 1994 08:49:37 GMT")

        #expect(expires != nil)

        let expectedDate = Date(timeIntervalSince1970: 784_111_777)
        let diff = abs(expires!.date.timeIntervalSince(expectedDate))
        #expect(diff < 1.0)
    }

    @Test
    func `Round trip - format and parse`() async throws {
        let original = Date(timeIntervalSince1970: 784_111_777)
        let expires = HTTP.Expires(date: original)

        let headerValue = expires.headerValue
        let parsed = HTTP.Expires.parse(headerValue)

        #expect(parsed != nil)
        let diff = abs(parsed!.date.timeIntervalSince(original))
        #expect(diff < 1.0)  // Within 1 second
    }
}
