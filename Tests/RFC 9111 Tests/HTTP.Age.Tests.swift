// HTTP.Age.Tests.swift
// swift-rfc-9111

import Testing

@testable import RFC_9111

@Suite
struct `HTTP.Age Tests` {

    @Test
    func `Age creation with valid seconds`() async throws {
        let age = HTTP.Age(seconds: 120)

        #expect(age.seconds == 120)
    }

    @Test
    func `Age creation with zero`() async throws {
        let age = HTTP.Age(seconds: 0)

        #expect(age.seconds == 0)
    }

    @Test
    func `Header value format`() async throws {
        let age = HTTP.Age(seconds: 120)

        #expect(age.headerValue == "120")
    }

    @Test
    func `Parse valid age`() async throws {
        let parsed = HTTP.Age.parse("120")

        #expect(parsed != nil)
        #expect(parsed?.seconds == 120)
    }

    @Test
    func `Parse age with whitespace`() async throws {
        let parsed = HTTP.Age.parse("  120  ")

        #expect(parsed != nil)
        #expect(parsed?.seconds == 120)
    }

    @Test
    func `Parse invalid age`() async throws {
        #expect(HTTP.Age.parse("invalid") == nil)
        #expect(HTTP.Age.parse("") == nil)
        #expect(HTTP.Age.parse("-5") == nil)  // Negative ages invalid
        #expect(HTTP.Age.parse("120.5") == nil)  // No decimals
    }

    @Test
    func `Equality`() async throws {
        let age1 = HTTP.Age(seconds: 120)
        let age2 = HTTP.Age(seconds: 120)
        let age3 = HTTP.Age(seconds: 121)

        #expect(age1 == age2)
        #expect(age1 != age3)
    }

    @Test
    func `Hashable`() async throws {
        var set: Set<HTTP.Age> = []

        set.insert(HTTP.Age(seconds: 120))
        set.insert(HTTP.Age(seconds: 120))  // Duplicate
        set.insert(HTTP.Age(seconds: 121))

        #expect(set.count == 2)
    }

    @Test
    func `Comparable`() async throws {
        let younger = HTTP.Age(seconds: 100)
        let older = HTTP.Age(seconds: 200)

        #expect(younger < older)
        #expect(older > younger)
    }

    @Test
    func `Codable`() async throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let age = HTTP.Age(seconds: 120)
        let encoded = try encoder.encode(age)
        let decoded = try decoder.decode(HTTP.Age.self, from: encoded)

        #expect(decoded == age)
    }

    @Test
    func `Description`() async throws {
        let age = HTTP.Age(seconds: 120)

        #expect(age.description == "120")
    }

    @Test
    func `LosslessStringConvertible`() async throws {
        let age = HTTP.Age("120")

        #expect(age != nil)
        #expect(age?.seconds == 120)
        #expect(String(age!) == "120")
    }

    @Test
    func `ExpressibleByIntegerLiteral`() async throws {
        let age: HTTP.Age = 120

        #expect(age.seconds == 120)
    }

    @Test
    func `Round trip - format and parse`() async throws {
        let original = HTTP.Age(seconds: 120)
        let headerValue = original.headerValue
        let parsed = HTTP.Age.parse(headerValue)

        #expect(parsed != nil)
        #expect(parsed == original)
    }
}
