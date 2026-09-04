import RFC_9110
import RFC_9111
import Testing

@Suite
struct `HTTP.Cache.Storage.Fields Tests` {

    @Test
    func `Hop-by-hop fields are not stored`() {
        let headers: HTTP.Message.Headers = [
            HTTP.Field(name: .connection, value: .init(unchecked: "x-private")),
            HTTP.Field(name: .transferEncoding, value: .init(unchecked: "chunked")),
            HTTP.Field(name: .etag, value: .init(unchecked: "\"abc\"")),
        ]

        let stored = HTTP.Cache.Storage.Fields.headersToStore(from: headers)

        #expect(stored.count == 1)
        #expect(stored.first?.name == .etag)
    }

    @Test
    func `Connection options extend the hop-by-hop set`() throws {
        let name = try HTTP.Field.Name("X-Private")
        let headers: HTTP.Message.Headers = [
            HTTP.Field(name: name, value: .init(unchecked: "1")),
            HTTP.Field(name: .etag, value: .init(unchecked: "\"abc\"")),
        ]

        let stored = HTTP.Cache.Storage.Fields.headersToStore(
            from: headers,
            connectionOptions: [name]
        )

        #expect(stored.count == 1)
        #expect(stored.first?.name == .etag)
    }

    @Test
    func `Vary compares the named request fields`() {
        let stored: HTTP.Message.Headers = [
            HTTP.Field(name: .acceptEncoding, value: .init(unchecked: "gzip"))
        ]
        let same: HTTP.Message.Headers = [
            HTTP.Field(name: .acceptEncoding, value: .init(unchecked: "gzip"))
        ]
        let different: HTTP.Message.Headers = [
            HTTP.Field(name: .acceptEncoding, value: .init(unchecked: "br"))
        ]

        let vary = HTTP.Negotiation.Vary(fieldNames: ["Accept-Encoding"])

        #expect(HTTP.Cache.Storage.Fields.matchesVary(vary, stored: stored, current: same))
        #expect(!HTTP.Cache.Storage.Fields.matchesVary(vary, stored: stored, current: different))
    }

    @Test
    func `Vary on all aspects never matches`() {
        #expect(
            !HTTP.Cache.Storage.Fields.matchesVary(HTTP.Negotiation.Vary.all, stored: [], current: [])
        )
    }

    @Test
    func `No Vary field matches every request`() {
        #expect(HTTP.Cache.Storage.Fields.matchesVary(nil, stored: [], current: []))
    }

    @Test
    func `Updating replaces a stored field`() {
        let stored: HTTP.Message.Headers = [
            HTTP.Field(name: .etag, value: .init(unchecked: "\"abc\"")),
            HTTP.Field(name: .server, value: .init(unchecked: "swift")),
        ]
        let notModified: HTTP.Message.Headers = [
            HTTP.Field(name: .etag, value: .init(unchecked: "\"def\""))
        ]

        let updated = HTTP.Cache.Storage.Fields.updateHeaders(
            stored: stored,
            with: notModified
        )

        #expect(updated[.etag].map(\.rawValue) == ["\"def\""])
        #expect(updated.count == 2)
    }

    @Test
    func `The Age field is recalculated on the way out`() {
        let headers: HTTP.Message.Headers = [
            HTTP.Field(name: .age, value: .init(unchecked: "5"))
        ]

        #expect(HTTP.Cache.Storage.Fields.shouldRecalculateAge(in: headers))

        let updated = HTTP.Cache.Storage.Fields.updateAge(
            in: headers,
            to: HTTP.Cache.Age(seconds: 42)
        )

        #expect(updated[.age].map(\.rawValue) == ["42"])
    }
}
