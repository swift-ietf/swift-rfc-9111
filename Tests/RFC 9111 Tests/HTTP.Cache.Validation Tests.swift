import RFC_9110
import RFC_9111
import Testing

@Suite
struct `HTTP.Cache.Validation Tests` {

    @Test
    func `A stored entity tag becomes If-None-Match`() {
        let stored = HTTP.Message.Response<String>(
            status: 200,
            headers: [HTTP.Field(name: .etag, value: .init(unchecked: "\"abc\""))]
        )
        let original = HTTP.Message.Request<String>(method: .get, target: .asterisk)

        let request = HTTP.Cache.Validation.request(for: stored, from: original)

        #expect(request.headers[.ifNoneMatch].map(\.rawValue) == ["\"abc\""])
        #expect(request.headers[.ifModifiedSince].isEmpty)
    }

    @Test
    func `Last-Modified becomes If-Modified-Since when no entity tag is stored`() {
        let stored = HTTP.Message.Response<String>(
            status: 200,
            headers: [
                HTTP.Field(
                    name: .lastModified,
                    value: .init(unchecked: "Sun, 06 Nov 1994 08:49:37 GMT")
                )
            ]
        )
        let original = HTTP.Message.Request<String>(method: .get, target: .asterisk)

        let request = HTTP.Cache.Validation.request(for: stored, from: original)

        #expect(
            request.headers[.ifModifiedSince].map(\.rawValue)
                == ["Sun, 06 Nov 1994 08:49:37 GMT"]
        )
    }

    @Test
    func `A 304 updates the stored headers`() {
        let stored = HTTP.Message.Response<String>(
            status: 200,
            headers: [HTTP.Field(name: .etag, value: .init(unchecked: "\"abc\""))],
            content: "cached"
        )
        let validation = HTTP.Message.Response<String>(
            status: 304,
            headers: [HTTP.Field(name: .etag, value: .init(unchecked: "\"def\""))]
        )

        let outcome = HTTP.Cache.Validation.outcome(of: validation, storedResponse: stored)

        guard case .notModified(let updated) = outcome else {
            Issue.record("expected a not-modified outcome")
            return
        }

        #expect(updated.content == "cached")
        #expect(updated.headers[.etag].map(\.rawValue) == ["\"def\""])
        #expect(outcome.canUseStoredResponse)
    }

    @Test
    func `A 200 replaces the stored response`() {
        let stored = HTTP.Message.Response<String>(status: 200, content: "old")
        let validation = HTTP.Message.Response<String>(status: 200, content: "new")

        #expect(
            HTTP.Cache.Validation.outcome(of: validation, storedResponse: stored)
                == .modified(newResponse: validation)
        )
    }

    @Test
    func `A server error may serve the stale response`() {
        let stored = HTTP.Message.Response<String>(status: 200, content: "old")
        let validation = HTTP.Message.Response<String>(status: 500)

        #expect(
            HTTP.Cache.Validation.outcome(of: validation, storedResponse: stored)
                == .serverError(canServeStale: true)
        )
    }
}
