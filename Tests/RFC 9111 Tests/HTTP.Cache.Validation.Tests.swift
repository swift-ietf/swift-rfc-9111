import Byte
import RFC_3986
import Testing

@testable import RFC_9111

@Suite
struct `HTTP.Cache.Validation Tests` {

    @Test
    func `Generate validation request with ETag`() async throws {
        let storedResponse = RFC_9110.Message.Response<[Byte]>(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Field(name: "ETag", value: "\"abc123\""),
                try RFC_9110.Field(name: "Content-Type", value: "text/plain"),
            ],
            content: Array("test".utf8).map { Byte(bitPattern: $0) }
        )

        let originalRequest = RFC_9110.Message.Request<[Byte]>(
            method: .get,
            target: .resource(try RFC_3986.URI("http://example.com/resource")),
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
        let storedResponse = RFC_9110.Message.Response<[Byte]>(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Field(
                    name: "Last-Modified",
                    value: "Wed, 21 Oct 2015 07:28:00 GMT"
                ),
                try RFC_9110.Field(name: "Content-Type", value: "text/plain"),
            ],
            content: Array("test".utf8).map { Byte(bitPattern: $0) }
        )

        let originalRequest = RFC_9110.Message.Request<[Byte]>(
            method: .get,
            target: .resource(try RFC_3986.URI("http://example.com/resource")),
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
        let storedResponse = RFC_9110.Message.Response<[Byte]>(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Field(name: "ETag", value: "\"abc123\""),
                try RFC_9110.Field(
                    name: "Last-Modified",
                    value: "Wed, 21 Oct 2015 07:28:00 GMT"
                ),
            ],
            content: Array("test".utf8).map { Byte(bitPattern: $0) }
        )

        let originalRequest = RFC_9110.Message.Request<[Byte]>(
            method: .get,
            target: .resource(try RFC_3986.URI("http://example.com/resource")),
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

        #expect(ifModifiedSince == nil)
    }

    @Test
    func `Process 304 Not Modified response`() async throws {
        let storedResponse = RFC_9110.Message.Response<[Byte]>(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Field(name: "ETag", value: "\"abc123\""),
                try RFC_9110.Field(name: "Content-Type", value: "text/plain"),
                try RFC_9110.Field(name: "Date", value: "Wed, 21 Oct 2015 07:28:00 GMT"),
            ],
            content: Array("original body".utf8).map { Byte(bitPattern: $0) }
        )

        let notModifiedResponse = RFC_9110.Message.Response<[Byte]>(
            status: RFC_9110.Status(304),
            headers: [
                try RFC_9110.Field(name: "ETag", value: "\"abc123\""),
                try RFC_9110.Field(name: "Date", value: "Thu, 22 Oct 2015 07:28:00 GMT"),
                try RFC_9110.Field(name: "Cache-Control", value: "max-age=7200"),
            ],
            content: nil
        )

        let result = RFC_9110.Cache.Validation.processValidationResponse(
            notModifiedResponse,
            storedResponse: storedResponse
        )

        switch result {
        case .notModified(let updatedResponse):

            #expect(updatedResponse.content == Array("original body".utf8).map { Byte(bitPattern: $0) })

            let date = updatedResponse.headers.first { $0.name.rawValue.lowercased() == "date" }
            #expect(date?.value.rawValue == "Thu, 22 Oct 2015 07:28:00 GMT")

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
        let storedResponse = RFC_9110.Message.Response<[Byte]>(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Field(name: "ETag", value: "\"abc123\"")
            ],
            content: Array("old body".utf8).map { Byte(bitPattern: $0) }
        )

        let newResponse = RFC_9110.Message.Response<[Byte]>(
            status: RFC_9110.Status(200),
            headers: [
                try RFC_9110.Field(name: "ETag", value: "\"def456\""),
                try RFC_9110.Field(name: "Content-Type", value: "text/plain"),
            ],
            content: Array("new body".utf8).map { Byte(bitPattern: $0) }
        )

        let result = RFC_9110.Cache.Validation.processValidationResponse(
            newResponse,
            storedResponse: storedResponse
        )

        switch result {
        case .modified(let response):
            #expect(response.content == Array("new body".utf8).map { Byte(bitPattern: $0) })
            let etag = response.headers.first { $0.name.rawValue.lowercased() == "etag" }
            #expect(etag?.value.rawValue == "\"def456\"")

        default:
            Issue.record("Expected .modified result")
        }
    }

    @Test
    func `Process server error response`() async throws {
        let storedResponse = RFC_9110.Message.Response<[Byte]>(
            status: RFC_9110.Status(200),
            headers: [],
            content: Array("test".utf8).map { Byte(bitPattern: $0) }
        )

        let errorResponse = RFC_9110.Message.Response<[Byte]>(
            status: RFC_9110.Status(502),
            headers: [],
            content: nil
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
        let storedResponse = RFC_9110.Message.Response<[Byte]>(
            status: RFC_9110.Status(200),
            headers: [],
            content: Array("test".utf8).map { Byte(bitPattern: $0) }
        )

        let errorResponse = RFC_9110.Message.Response<[Byte]>(
            status: RFC_9110.Status(404),
            headers: [],
            content: Array("Not Found".utf8).map { Byte(bitPattern: $0) }
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
