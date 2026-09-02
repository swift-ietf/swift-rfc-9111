import Byte
import RFC_3986
import Testing

@testable import RFC_9111

@Suite
struct `HTTP.Cache.StorageEligibility Tests` {

    @Test
    func `Eligible - GET request with max-age`() async throws {
        let request = RFC_9110.Message.Request<[Byte]>(
            method: .get,
            target: .resource(try RFC_3986.URI("http://example.com/")),
            headers: []
        )

        let response = RFC_9110.Message.Response<[Byte]>(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Field(name: "Cache-Control", value: "max-age=3600")
            ],
            content: Array("test".utf8).map { Byte(bitPattern: $0) }
        )

        let result = RFC_9110.Cache.StorageEligibility.isStorable(
            request: request,
            response: response
        )

        #expect(result.isEligible)
    }

    @Test
    func `Ineligible - no-store directive`() async throws {
        let request = RFC_9110.Message.Request<[Byte]>(
            method: .get,
            target: .resource(try RFC_3986.URI("http://example.com/")),
            headers: []
        )

        let response = RFC_9110.Message.Response<[Byte]>(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Field(name: "Cache-Control", value: "no-store")
            ],
            content: Array("test".utf8).map { Byte(bitPattern: $0) }
        )

        let result = RFC_9110.Cache.StorageEligibility.isStorable(
            request: request,
            response: response
        )

        #expect(!result.isEligible)
    }

    @Test
    func `Ineligible - private in shared cache`() async throws {
        let request = RFC_9110.Message.Request<[Byte]>(
            method: .get,
            target: .resource(try RFC_3986.URI("http://example.com/")),
            headers: []
        )

        let response = RFC_9110.Message.Response<[Byte]>(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Field(name: "Cache-Control", value: "private, max-age=3600")
            ],
            content: Array("test".utf8).map { Byte(bitPattern: $0) }
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
        let request = RFC_9110.Message.Request<[Byte]>(
            method: .get,
            target: .resource(try RFC_3986.URI("http://example.com/")),
            headers: []
        )

        let response = RFC_9110.Message.Response<[Byte]>(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Field(name: "Cache-Control", value: "private, max-age=3600")
            ],
            content: Array("test".utf8).map { Byte(bitPattern: $0) }
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
        let request = RFC_9110.Message.Request<[Byte]>(
            method: .get,
            target: .resource(try RFC_3986.URI("http://example.com/")),
            headers: []
        )

        let response = RFC_9110.Message.Response<[Byte]>(
            status: RFC_9110.Status(200),
            headers: [],
            content: Array("test".utf8).map { Byte(bitPattern: $0) }
        )

        let result = RFC_9110.Cache.StorageEligibility.isStorable(
            request: request,
            response: response
        )

        #expect(result.isEligible)
    }

    @Test
    func `Ineligible - informational status`() async throws {
        let request = RFC_9110.Message.Request<[Byte]>(
            method: .get,
            target: .resource(try RFC_3986.URI("http://example.com/")),
            headers: []
        )

        let response = RFC_9110.Message.Response<[Byte]>(
            status: RFC_9110.Status(100),
            headers: [],
            content: nil
        )

        let result = RFC_9110.Cache.StorageEligibility.isStorable(
            request: request,
            response: response
        )

        #expect(!result.isEligible)
    }

    @Test
    func `Eligible - authorized request with public directive`() async throws {
        let request = RFC_9110.Message.Request<[Byte]>(
            method: .get,
            target: .resource(try RFC_3986.URI("http://example.com/")),
            headers: [
                try RFC_9110.Field(name: "Authorization", value: "Bearer token")
            ]
        )

        let response = RFC_9110.Message.Response<[Byte]>(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Field(name: "Cache-Control", value: "public, max-age=3600")
            ],
            content: Array("test".utf8).map { Byte(bitPattern: $0) }
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
        let request = RFC_9110.Message.Request<[Byte]>(
            method: .get,
            target: .resource(try RFC_3986.URI("http://example.com/")),
            headers: [
                try RFC_9110.Field(name: "Authorization", value: "Bearer token")
            ]
        )

        let response = RFC_9110.Message.Response<[Byte]>(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Field(name: "Cache-Control", value: "max-age=3600")
            ],
            content: Array("test".utf8).map { Byte(bitPattern: $0) }
        )

        let result = RFC_9110.Cache.StorageEligibility.isStorable(
            request: request,
            response: response,
            isSharedCache: true
        )

        #expect(!result.isEligible)
    }
}
