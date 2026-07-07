// HTTP.Freshness.Tests.swift
// swift-rfc-9111

import RFC_5322
import Testing

@testable import RFC_9111

/// Builds an RFC 9110 HTTP-date header value (IMF-fixdate, GMT) from a date-time.
private func httpDate(_ date: HTTP.Date) -> String {
    HTTP.Header.Field(dateTime: date).value.rawValue
}

@Suite
struct `HTTP.Freshness Tests` {

    @Test
    func `calculateFreshnessLifetime - max-age`() async throws {
        let response = HTTP.Response(
            status: .ok,
            headers: [
                try .init(name: "Cache-Control", value: "max-age=3600")
            ]
        )

        let lifetime = HTTP.Freshness.calculateFreshnessLifetime(response: response)

        #expect(lifetime == 3600)
    }

    @Test
    func `calculateFreshnessLifetime - s-maxage for shared cache`() async throws {
        let response = HTTP.Response(
            status: .ok,
            headers: [
                try .init(name: "Cache-Control", value: "max-age=3600, s-maxage=7200")
            ]
        )

        let lifetime = HTTP.Freshness.calculateFreshnessLifetime(
            response: response,
            isSharedCache: true
        )

        #expect(lifetime == 7200)  // s-maxage takes precedence for shared caches
    }

    @Test
    func `calculateFreshnessLifetime - s-maxage ignored for private cache`() async throws {
        let response = HTTP.Response(
            status: .ok,
            headers: [
                try .init(name: "Cache-Control", value: "max-age=3600, s-maxage=7200")
            ]
        )

        let lifetime = HTTP.Freshness.calculateFreshnessLifetime(
            response: response,
            isSharedCache: false
        )

        #expect(lifetime == 3600)  // s-maxage ignored for private caches
    }

    @Test
    func `calculateFreshnessLifetime - Expires header`() async throws {
        let date = HTTP.Date(secondsSinceEpoch: 1_445_412_480)
        let expiresDate = date.adding(3600)

        let response = HTTP.Response(
            status: .ok,
            headers: [
                try .init(name: "Date", value: httpDate(date)),
                try .init(name: "Expires", value: httpDate(expiresDate)),
            ]
        )

        let lifetime = HTTP.Freshness.calculateFreshnessLifetime(response: response)

        #expect(lifetime > 3550)
        #expect(lifetime < 3650)
    }

    @Test
    func `calculateFreshnessLifetime - max-age overrides Expires`() async throws {
        let date = HTTP.Date(secondsSinceEpoch: 1_445_412_480)
        let expiresDate = date.adding(7200)

        let response = HTTP.Response(
            status: .ok,
            headers: [
                try .init(name: "Cache-Control", value: "max-age=3600"),
                try .init(name: "Date", value: httpDate(date)),
                try .init(name: "Expires", value: httpDate(expiresDate)),
            ]
        )

        let lifetime = HTTP.Freshness.calculateFreshnessLifetime(response: response)

        #expect(lifetime == 3600)  // max-age takes precedence
    }

    @Test
    func `calculateFreshnessLifetime - no freshness info`() async throws {
        let response = HTTP.Response(
            status: .ok,
            headers: []
        )

        let lifetime = HTTP.Freshness.calculateFreshnessLifetime(response: response)

        #expect(lifetime == 0)
    }

    @Test
    func `calculateAge - with Age header`() async throws {
        let now = HTTP.Date(secondsSinceEpoch: 1_445_412_480)

        let response = HTTP.Response(
            status: .ok,
            headers: [
                try .init(name: "Age", value: "120"),
                try .init(name: "Date", value: httpDate(now)),
            ]
        )

        let age = HTTP.Freshness.calculateAge(response: response, now: now)

        #expect(age >= 120)
    }

    @Test
    func `calculateAge - without Age header`() async throws {
        let now = HTTP.Date(secondsSinceEpoch: 1_445_412_480)
        let responseTime = now.adding(-300)  // Received 5 minutes ago
        let pastDate = now.adding(-310)  // Date header 10 seconds before response

        let response = HTTP.Response(
            status: .ok,
            headers: [
                try .init(name: "Date", value: httpDate(pastDate))
            ]
        )

        let age = HTTP.Freshness.calculateAge(
            response: response,
            now: now,
            responseTime: responseTime
        )

        #expect(age >= 290)  // Close to 300 seconds
        #expect(age <= 320)
    }

    @Test
    func `calculateAge - with request and response times`() async throws {
        let now = HTTP.Date(secondsSinceEpoch: 1_445_412_480)
        let requestTime = now.adding(-10)
        let responseTime = now.adding(-5)
        let dateValue = now.adding(-7)

        let response = HTTP.Response(
            status: .ok,
            headers: [
                try .init(name: "Date", value: httpDate(dateValue))
            ]
        )

        let age = HTTP.Freshness.calculateAge(
            response: response,
            now: now,
            requestTime: requestTime,
            responseTime: responseTime
        )

        #expect(age > 0)
    }

    @Test
    func `isFresh - fresh response`() async throws {
        let now = HTTP.Date(secondsSinceEpoch: 1_445_412_480)

        let response = HTTP.Response(
            status: .ok,
            headers: [
                try .init(name: "Cache-Control", value: "max-age=3600"),
                try .init(name: "Date", value: httpDate(now)),
            ]
        )

        #expect(HTTP.Freshness.isFresh(response: response, now: now))
    }

    @Test
    func `isFresh - stale response`() async throws {
        let now = HTTP.Date(secondsSinceEpoch: 1_445_412_480)
        let responseTime = now.adding(-7200)  // Received 2 hours ago

        let response = HTTP.Response(
            status: .ok,
            headers: [
                try .init(name: "Cache-Control", value: "max-age=3600"),
                try .init(name: "Date", value: httpDate(responseTime)),
            ]
        )

        #expect(
            !HTTP.Freshness.isFresh(
                response: response,
                now: now,
                responseTime: responseTime
            )
        )
    }

    @Test
    func `isFresh - with custom times`() async throws {
        let responseTime = HTTP.Date(secondsSinceEpoch: 1_000_000)
        // 4000 seconds later (exceeds max-age of 3600)
        let now = HTTP.Date(secondsSinceEpoch: 1_004_000)

        let response = HTTP.Response(
            status: .ok,
            headers: [
                try .init(name: "Cache-Control", value: "max-age=3600"),
                try .init(name: "Date", value: httpDate(responseTime)),
            ]
        )

        #expect(
            !HTTP.Freshness.isFresh(
                response: response,
                now: now,
                responseTime: responseTime
            )
        )
    }

    @Test
    func `staleDate - valid lifetime`() async throws {
        let responseTime = HTTP.Date(secondsSinceEpoch: 1_445_412_480)

        let response = HTTP.Response(
            status: .ok,
            headers: [
                try .init(name: "Cache-Control", value: "max-age=3600"),
                try .init(name: "Date", value: httpDate(responseTime)),
            ]
        )

        let staleDate = HTTP.Freshness.staleDate(
            response: response,
            responseTime: responseTime
        )

        #expect(staleDate != nil)

        let expectedStaleDate = responseTime.adding(3600)
        let diff = abs(staleDate!.timeIntervalSince(expectedStaleDate))
        #expect(diff < 1.0)
    }

    @Test
    func `staleDate - zero lifetime`() async throws {
        let responseTime = HTTP.Date(secondsSinceEpoch: 1_445_412_480)

        let response = HTTP.Response(
            status: .ok,
            headers: []
        )

        let staleDate = HTTP.Freshness.staleDate(
            response: response,
            responseTime: responseTime
        )

        #expect(staleDate == nil)
    }

    @Test
    func `calculateHeuristicFreshness - with Last-Modified`() async throws {
        let now = HTTP.Date(secondsSinceEpoch: 1_445_412_480)
        let lastModified = now.adding(-864000)  // 10 days ago

        let response = HTTP.Response(
            status: .ok,
            headers: [
                try .init(name: "Date", value: httpDate(now)),
                try .init(name: "Last-Modified", value: httpDate(lastModified)),
            ]
        )

        let heuristicFreshness = HTTP.Freshness.calculateHeuristicFreshness(response: response)

        // Should be 10% of 10 days = 1 day = 86400 seconds
        #expect(heuristicFreshness > 86300)
        #expect(heuristicFreshness <= 86400)  // Capped at 24 hours
    }

    @Test
    func `calculateHeuristicFreshness - without Last-Modified`() async throws {
        let response = HTTP.Response(
            status: .ok,
            headers: [
                try .init(
                    name: "Date",
                    value: httpDate(HTTP.Date(secondsSinceEpoch: 1_445_412_480))
                )
            ]
        )

        let heuristicFreshness = HTTP.Freshness.calculateHeuristicFreshness(response: response)

        #expect(heuristicFreshness == 0)
    }

    @Test
    func `calculateHeuristicFreshness - capped at 24 hours`() async throws {
        let now = HTTP.Date(secondsSinceEpoch: 1_445_412_480)
        let lastModified = now.adding(-8_640_000)  // 100 days ago

        let response = HTTP.Response(
            status: .ok,
            headers: [
                try .init(name: "Date", value: httpDate(now)),
                try .init(name: "Last-Modified", value: httpDate(lastModified)),
            ]
        )

        let heuristicFreshness = HTTP.Freshness.calculateHeuristicFreshness(response: response)

        // Should be capped at 24 hours = 86400 seconds
        #expect(heuristicFreshness == 86400)
    }

    @Test
    func `Freshness with heuristics allowed`() async throws {
        let now = HTTP.Date(secondsSinceEpoch: 1_445_412_480)
        let lastModified = now.adding(-864000)  // 10 days ago

        let response = HTTP.Response(
            status: .ok,
            headers: [
                try .init(name: "Date", value: httpDate(now)),
                try .init(name: "Last-Modified", value: httpDate(lastModified)),
            ]
        )

        let lifetime = HTTP.Freshness.calculateFreshnessLifetime(
            response: response,
            allowHeuristics: true
        )

        #expect(lifetime > 0)
        #expect(lifetime <= 86400)  // Heuristic capped at 24 hours
    }
}
