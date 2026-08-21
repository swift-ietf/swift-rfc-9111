import Foundation
import RFC_5322
import Testing

@testable import RFC_9111

@Suite
struct `HTTP.Expires Tests` {

    @Test
    func `Expires creation`() async throws {
        let date = HTTP.Date(secondsSinceEpoch: 1_445_412_480)
        let expires = HTTP.Expires(date: date)

        #expect(expires.date == date)
    }

    @Test
    func `Header value format`() async throws {
        let date = HTTP.Date(secondsSinceEpoch: 784_111_777)
        let expires = HTTP.Expires(date: date)

        let headerValue = expires.headerValue

        #expect(headerValue == "Sun, 06 Nov 1994 08:49:37 GMT")
        #expect(headerValue.contains("GMT"))
        #expect(!headerValue.contains("+0000"))
    }

    @Test
    func `Parse valid expires`() async throws {
        let parsed = HTTP.Expires.parse("Sun, 06 Nov 1994 08:49:37 GMT")

        #expect(parsed != nil)

        let expectedDate = HTTP.Date(secondsSinceEpoch: 784_111_777)
        let diff = abs(parsed!.date.timeIntervalSince(expectedDate))
        #expect(diff < 1.0)
    }

    @Test
    func `Parse invalid expires`() async throws {
        #expect(HTTP.Expires.parse("invalid") == nil)
        #expect(HTTP.Expires.parse("") == nil)
        #expect(HTTP.Expires.parse("2024-11-16") == nil)
    }

    @Test
    func `isExpired - past date`() async throws {
        let now = HTTP.Date(secondsSinceEpoch: 1_445_412_480)
        let pastDate = now.adding(-3600)
        let expires = HTTP.Expires(date: pastDate)

        #expect(expires.isExpired(at: now))
    }

    @Test
    func `isExpired - future date`() async throws {
        let now = HTTP.Date(secondsSinceEpoch: 1_445_412_480)
        let futureDate = now.adding(3600)
        let expires = HTTP.Expires(date: futureDate)

        #expect(!expires.isExpired(at: now))
    }

    @Test
    func `isExpired - custom now`() async throws {
        let expirationDate = HTTP.Date(secondsSinceEpoch: 1_000_000)
        let expires = HTTP.Expires(date: expirationDate)

        let beforeExpiration = HTTP.Date(secondsSinceEpoch: 999999)
        let afterExpiration = HTTP.Date(secondsSinceEpoch: 1_000_001)

        #expect(!expires.isExpired(at: beforeExpiration))
        #expect(expires.isExpired(at: afterExpiration))
    }

    @Test
    func `timeRemaining - positive`() async throws {
        let now = HTTP.Date(secondsSinceEpoch: 1_445_412_480)
        let futureDate = now.adding(3600)
        let expires = HTTP.Expires(date: futureDate)

        let remaining = expires.timeRemaining(from: now)

        #expect(remaining > 3500)
        #expect(remaining < 3700)
    }

    @Test
    func `timeRemaining - negative`() async throws {
        let now = HTTP.Date(secondsSinceEpoch: 1_445_412_480)
        let pastDate = now.adding(-3600)
        let expires = HTTP.Expires(date: pastDate)

        let remaining = expires.timeRemaining(from: now)

        #expect(remaining < -3500)
        #expect(remaining > -3700)
    }

    @Test
    func `Equality`() async throws {
        let date1 = HTTP.Date(secondsSinceEpoch: 784_111_777)
        let date2 = HTTP.Date(secondsSinceEpoch: 784_111_777)
        let date3 = HTTP.Date(secondsSinceEpoch: 784_111_778)

        let expires1 = HTTP.Expires(date: date1)
        let expires2 = HTTP.Expires(date: date2)
        let expires3 = HTTP.Expires(date: date3)

        #expect(expires1 == expires2)
        #expect(expires1 != expires3)
    }

    @Test
    func `Hashable`() async throws {
        var set: Set<HTTP.Expires> = []
        let date = HTTP.Date(secondsSinceEpoch: 784_111_777)

        set.insert(HTTP.Expires(date: date))
        set.insert(HTTP.Expires(date: date))
        set.insert(HTTP.Expires(date: HTTP.Date(secondsSinceEpoch: 784_111_778)))

        #expect(set.count == 2)
    }

    @Test
    func `Comparable`() async throws {
        let earlier = HTTP.Expires(date: HTTP.Date(secondsSinceEpoch: 1000))
        let later = HTTP.Expires(date: HTTP.Date(secondsSinceEpoch: 2000))

        #expect(earlier < later)
        #expect(later > earlier)
    }

    @Test
    func `Codable`() async throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let date = HTTP.Date(secondsSinceEpoch: 784_111_777)
        let expires = HTTP.Expires(date: date)

        let encoded = try encoder.encode(expires)
        let decoded = try decoder.decode(HTTP.Expires.self, from: encoded)

        let diff = abs(decoded.date.timeIntervalSince(expires.date))
        #expect(diff < 1.0)
    }

    @Test
    func `Description`() async throws {
        let date = HTTP.Date(secondsSinceEpoch: 784_111_777)
        let expires = HTTP.Expires(date: date)

        let description = expires.description

        #expect(description.contains("Sun"))
        #expect(description.contains("GMT"))
        #expect(!description.contains("+0000"))
    }

    @Test
    func `LosslessStringConvertible`() async throws {
        let expires = HTTP.Expires("Sun, 06 Nov 1994 08:49:37 GMT")

        #expect(expires != nil)

        let expectedDate = HTTP.Date(secondsSinceEpoch: 784_111_777)
        let diff = abs(expires!.date.timeIntervalSince(expectedDate))
        #expect(diff < 1.0)
    }

    @Test
    func `Round trip - format and parse`() async throws {
        let original = HTTP.Date(secondsSinceEpoch: 784_111_777)
        let expires = HTTP.Expires(date: original)

        let headerValue = expires.headerValue
        let parsed = HTTP.Expires.parse(headerValue)

        #expect(parsed != nil)
        let diff = abs(parsed!.date.timeIntervalSince(original))
        #expect(diff < 1.0)
    }
}
