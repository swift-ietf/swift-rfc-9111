// HTTP.Cache.StorageEligibility.Tests.swift
// swift-rfc-9111

import RFC_3986
import Testing

@testable import RFC_9111

@Suite
struct `HTTP.Cache.StorageEligibility Tests` {

    @Test
    func `Eligible - GET request with max-age`() async throws {
        let request = try RFC_9110.Request(
            method: .get,
            scheme: RFC_3986.URI.Scheme("http"),
            host: RFC_3986.URI.Host("example.com"),
            path: RFC_3986.URI.Path("/"),
            headers: []
        )

        let response = RFC_9110.Response(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Header.Field(name: "Cache-Control", value: "max-age=3600")
            ],
            body: Data("test".utf8)
        )

        let result = RFC_9110.Cache.StorageEligibility.isStorable(
            request: request,
            response: response
        )

        #expect(result.isEligible)
    }

    @Test
    func `Ineligible - no-store directive`() async throws {
        let request = try RFC_9110.Request(
            method: .get,
            scheme: RFC_3986.URI.Scheme("http"),
            host: RFC_3986.URI.Host("example.com"),
            path: RFC_3986.URI.Path("/"),
            headers: []
        )

        let response = RFC_9110.Response(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Header.Field(name: "Cache-Control", value: "no-store")
            ],
            body: Data("test".utf8)
        )

        let result = RFC_9110.Cache.StorageEligibility.isStorable(
            request: request,
            response: response
        )

        #expect(!result.isEligible)
    }

    @Test
    func `Ineligible - private in shared cache`() async throws {
        let request = try RFC_9110.Request(
            method: .get,
            scheme: RFC_3986.URI.Scheme("http"),
            host: RFC_3986.URI.Host("example.com"),
            path: RFC_3986.URI.Path("/"),
            headers: []
        )

        let response = RFC_9110.Response(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Header.Field(name: "Cache-Control", value: "private, max-age=3600")
            ],
            body: Data("test".utf8)
        )

        let result = RFC_9110.Cache.StorageEligibility.isStorable(
            request: request,
            response: response,
            isSharedCache: true
        )

        #expect(!result.isEligible)
    }

    @Test
    func `Eligible - private in private cache`() async throws {
        let request = try RFC_9110.Request(
            method: .get,
            scheme: RFC_3986.URI.Scheme("http"),
            host: RFC_3986.URI.Host("example.com"),
            path: RFC_3986.URI.Path("/"),
            headers: []
        )

        let response = RFC_9110.Response(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Header.Field(name: "Cache-Control", value: "private, max-age=3600")
            ],
            body: Data("test".utf8)
        )

        let result = RFC_9110.Cache.StorageEligibility.isStorable(
            request: request,
            response: response,
            isSharedCache: false
        )

        #expect(result.isEligible)
    }

    @Test
    func `Eligible - heuristically cacheable status`() async throws {
        let request = try RFC_9110.Request(
            method: .get,
            scheme: RFC_3986.URI.Scheme("http"),
            host: RFC_3986.URI.Host("example.com"),
            path: RFC_3986.URI.Path("/"),
            headers: []
        )

        // 200 OK is heuristically cacheable even without explicit directives
        let response = RFC_9110.Response(
            status: RFC_9110.Status(200),
            headers: [],
            body: Data("test".utf8)
        )

        let result = RFC_9110.Cache.StorageEligibility.isStorable(
            request: request,
            response: response
        )

        #expect(result.isEligible)
    }

    @Test
    func `Ineligible - informational status`() async throws {
        let request = try RFC_9110.Request(
            method: .get,
            scheme: RFC_3986.URI.Scheme("http"),
            host: RFC_3986.URI.Host("example.com"),
            path: RFC_3986.URI.Path("/"),
            headers: []
        )

        // 100 Continue is not final
        let response = RFC_9110.Response(
            status: RFC_9110.Status(100),
            headers: [],
            body: nil
        )

        let result = RFC_9110.Cache.StorageEligibility.isStorable(
            request: request,
            response: response
        )

        #expect(!result.isEligible)
    }

    @Test
    func `Eligible - authorized request with public directive`() async throws {
        let request = try RFC_9110.Request(
            method: .get,
            scheme: RFC_3986.URI.Scheme("http"),
            host: RFC_3986.URI.Host("example.com"),
            path: RFC_3986.URI.Path("/"),
            headers: [
                try RFC_9110.Header.Field(name: "Authorization", value: "Bearer token")
            ]
        )

        let response = RFC_9110.Response(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Header.Field(name: "Cache-Control", value: "public, max-age=3600")
            ],
            body: Data("test".utf8)
        )

        let result = RFC_9110.Cache.StorageEligibility.isStorable(
            request: request,
            response: response,
            isSharedCache: true
        )

        #expect(result.isEligible)
    }

    @Test
    func `Ineligible - authorized request without sharing permission`() async throws {
        let request = try RFC_9110.Request(
            method: .get,
            scheme: RFC_3986.URI.Scheme("http"),
            host: RFC_3986.URI.Host("example.com"),
            path: RFC_3986.URI.Path("/"),
            headers: [
                try RFC_9110.Header.Field(name: "Authorization", value: "Bearer token")
            ]
        )

        let response = RFC_9110.Response(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Header.Field(name: "Cache-Control", value: "max-age=3600")
            ],
            body: Data("test".utf8)
        )

        let result = RFC_9110.Cache.StorageEligibility.isStorable(
            request: request,
            response: response,
            isSharedCache: true
        )

        #expect(!result.isEligible)
    }
}
