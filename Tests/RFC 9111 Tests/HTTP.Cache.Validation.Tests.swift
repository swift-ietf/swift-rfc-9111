// HTTP.Cache.Validation.Tests.swift
// swift-rfc-9111

import RFC_3986
import Testing

@testable import RFC_9111

@Suite
struct `HTTP.Cache.Validation Tests` {

    @Test
    func `Generate validation request with ETag`() async throws {
        let storedResponse = RFC_9110.Response(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Header.Field(name: "ETag", value: "\"abc123\""),
                try RFC_9110.Header.Field(name: "Content-Type", value: "text/plain"),
            ],
            body: Data("test".utf8)
        )

        let originalRequest = try RFC_9110.Request(
            method: .get,
            scheme: RFC_3986.URI.Scheme("http"),
            host: RFC_3986.URI.Host("example.com"),
            path: RFC_3986.URI.Path("/resource"),
            headers: []
        )

        let validationRequest = RFC_9110.Cache.Validation.generateValidationRequest(
            for: storedResponse,
            originalRequest: originalRequest
        )

        let ifNoneMatch = validationRequest.headers.first {
            $0.name.rawValue.lowercased() == "if-none-match"
        }
        #expect(ifNoneMatch?.value.rawValue == "\"abc123\"")
    }

    @Test
    func `Generate validation request with Last-Modified`() async throws {
        let storedResponse = RFC_9110.Response(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Header.Field(
                    name: "Last-Modified",
                    value: "Wed, 21 Oct 2015 07:28:00 GMT"
                ),
                try RFC_9110.Header.Field(name: "Content-Type", value: "text/plain"),
            ],
            body: Data("test".utf8)
        )

        let originalRequest = try RFC_9110.Request(
            method: .get,
            scheme: RFC_3986.URI.Scheme("http"),
            host: RFC_3986.URI.Host("example.com"),
            path: RFC_3986.URI.Path("/resource"),
            headers: []
        )

        let validationRequest = RFC_9110.Cache.Validation.generateValidationRequest(
            for: storedResponse,
            originalRequest: originalRequest
        )

        let ifModifiedSince = validationRequest.headers.first {
            $0.name.rawValue.lowercased() == "if-modified-since"
        }
        #expect(ifModifiedSince?.value.rawValue == "Wed, 21 Oct 2015 07:28:00 GMT")
    }

    @Test
    func `Generate validation request prefers ETag over Last-Modified`() async throws {
        let storedResponse = RFC_9110.Response(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Header.Field(name: "ETag", value: "\"abc123\""),
                try RFC_9110.Header.Field(
                    name: "Last-Modified",
                    value: "Wed, 21 Oct 2015 07:28:00 GMT"
                ),
            ],
            body: Data("test".utf8)
        )

        let originalRequest = try RFC_9110.Request(
            method: .get,
            scheme: RFC_3986.URI.Scheme("http"),
            host: RFC_3986.URI.Host("example.com"),
            path: RFC_3986.URI.Path("/resource"),
            headers: []
        )

        let validationRequest = RFC_9110.Cache.Validation.generateValidationRequest(
            for: storedResponse,
            originalRequest: originalRequest
        )

        let ifNoneMatch = validationRequest.headers.first {
            $0.name.rawValue.lowercased() == "if-none-match"
        }
        let ifModifiedSince = validationRequest.headers.first {
            $0.name.rawValue.lowercased() == "if-modified-since"
        }

        #expect(ifNoneMatch?.value.rawValue == "\"abc123\"")
        #expect(ifModifiedSince == nil)  // Should not include If-Modified-Since when ETag is present
    }

    @Test
    func `Process 304 Not Modified response`() async throws {
        let storedResponse = RFC_9110.Response(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Header.Field(name: "ETag", value: "\"abc123\""),
                try RFC_9110.Header.Field(name: "Content-Type", value: "text/plain"),
                try RFC_9110.Header.Field(name: "Date", value: "Wed, 21 Oct 2015 07:28:00 GMT"),
            ],
            body: Data("original body".utf8)
        )

        let notModifiedResponse = RFC_9110.Response(
            status: RFC_9110.Status(304),
            headers: [
                try RFC_9110.Header.Field(name: "ETag", value: "\"abc123\""),
                try RFC_9110.Header.Field(name: "Date", value: "Thu, 22 Oct 2015 07:28:00 GMT"),
                try RFC_9110.Header.Field(name: "Cache-Control", value: "max-age=7200"),
            ],
            body: nil
        )

        let result = RFC_9110.Cache.Validation.processValidationResponse(
            notModifiedResponse,
            storedResponse: storedResponse
        )

        switch result {
        case .notModified(let updatedResponse):
            // Should preserve original body
            #expect(updatedResponse.body == Data("original body".utf8))

            // Should have updated Date header
            let date = updatedResponse.headers.first { $0.name.rawValue.lowercased() == "date" }
            #expect(date?.value.rawValue == "Thu, 22 Oct 2015 07:28:00 GMT")

            // Should have new Cache-Control
            let cacheControl = updatedResponse.headers.first {
                $0.name.rawValue.lowercased() == "cache-control"
            }
            #expect(cacheControl?.value.rawValue == "max-age=7200")

        default:
            Issue.record("Expected .notModified result")
        }
    }

    @Test
    func `Process full response`() async throws {
        let storedResponse = RFC_9110.Response(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Header.Field(name: "ETag", value: "\"abc123\"")
            ],
            body: Data("old body".utf8)
        )

        let newResponse = RFC_9110.Response(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Header.Field(name: "ETag", value: "\"def456\""),
                try RFC_9110.Header.Field(name: "Content-Type", value: "text/plain"),
            ],
            body: Data("new body".utf8)
        )

        let result = RFC_9110.Cache.Validation.processValidationResponse(
            newResponse,
            storedResponse: storedResponse
        )

        switch result {
        case .modified(let response):
            #expect(response.body == Data("new body".utf8))
            let etag = response.headers.first { $0.name.rawValue.lowercased() == "etag" }
            #expect(etag?.value.rawValue == "\"def456\"")

        default:
            Issue.record("Expected .modified result")
        }
    }

    @Test
    func `Process server error response`() async throws {
        let storedResponse = RFC_9110.Response(
            status: RFC_9110.Status(200),
            headers: [],
            body: Data("test".utf8)
        )

        let errorResponse = RFC_9110.Response(
            status: RFC_9110.Status(502),
            headers: [],
            body: nil
        )

        let result = RFC_9110.Cache.Validation.processValidationResponse(
            errorResponse,
            storedResponse: storedResponse
        )

        switch result {
        case .serverError(let canServeStale):
            #expect(canServeStale == true)

        default:
            Issue.record("Expected .serverError result")
        }
    }

    @Test
    func `Process client error response`() async throws {
        let storedResponse = RFC_9110.Response(
            status: RFC_9110.Status(200),
            headers: [],
            body: Data("test".utf8)
        )

        let errorResponse = RFC_9110.Response(
            status: RFC_9110.Status(404),
            headers: [],
            body: Data("Not Found".utf8)
        )

        let result = RFC_9110.Cache.Validation.processValidationResponse(
            errorResponse,
            storedResponse: storedResponse
        )

        switch result {
        case .clientError(let response):
            #expect(response.status.code == 404)

        default:
            Issue.record("Expected .clientError result")
        }
    }
}
