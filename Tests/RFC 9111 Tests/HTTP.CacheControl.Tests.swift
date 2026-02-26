// HTTP.CacheControl.Tests.swift
// swift-rfc-9111

import Testing

@testable import RFC_9111

@Suite
struct `HTTP.CacheControl Tests` {

    @Test
    func `CacheControl creation - empty`() async throws {
        let cc = HTTP.CacheControl()

        #expect(cc.maxAge == nil)
        #expect(cc.noCache == false)
        #expect(cc.noStore == false)
        #expect(cc.isPublic == false)
    }

    @Test
    func `Header value - maxAge`() async throws {
        var cc = HTTP.CacheControl()
        cc.maxAge = 3600

        #expect(cc.headerValue == "max-age=3600")
    }

    @Test
    func `Header value - multiple directives`() async throws {
        var cc = HTTP.CacheControl()
        cc.isPublic = true
        cc.maxAge = 3600
        cc.mustRevalidate = true

        let value = cc.headerValue

        #expect(value.contains("max-age=3600"))
        #expect(value.contains("public"))
        #expect(value.contains("must-revalidate"))
    }

    @Test
    func `Header value - noCache`() async throws {
        var cc = HTTP.CacheControl()
        cc.noCache = true

        #expect(cc.headerValue == "no-cache")
    }

    @Test
    func `Header value - noStore`() async throws {
        var cc = HTTP.CacheControl()
        cc.noStore = true

        #expect(cc.headerValue == "no-store")
    }

    @Test
    func `Header value - maxStale without value`() async throws {
        var cc = HTTP.CacheControl()
        cc.maxStale = .some(nil)

        #expect(cc.headerValue == "max-stale")
    }

    @Test
    func `Header value - maxStale with value`() async throws {
        var cc = HTTP.CacheControl()
        cc.maxStale = .some(.some(600))

        #expect(cc.headerValue == "max-stale=600")
    }

    @Test
    func `Header value - private without fields`() async throws {
        var cc = HTTP.CacheControl()
        cc.private = .some(nil)

        #expect(cc.headerValue == "private")
    }

    @Test
    func `Header value - private with fields`() async throws {
        var cc = HTTP.CacheControl()
        cc.private = .some(.some(["Set-Cookie", "Authorization"]))

        #expect(cc.headerValue.contains("private"))
        #expect(cc.headerValue.contains("Set-Cookie"))
        #expect(cc.headerValue.contains("Authorization"))
    }

    @Test
    func `Parse - maxAge`() async throws {
        let cc = HTTP.CacheControl.parse("max-age=3600")

        #expect(cc.maxAge == 3600)
    }

    @Test
    func `Parse - noCache`() async throws {
        let cc = HTTP.CacheControl.parse("no-cache")

        #expect(cc.noCache == true)
    }

    @Test
    func `Parse - noStore`() async throws {
        let cc = HTTP.CacheControl.parse("no-store")

        #expect(cc.noStore == true)
    }

    @Test
    func `Parse - public`() async throws {
        let cc = HTTP.CacheControl.parse("public")

        #expect(cc.isPublic == true)
    }

    @Test
    func `Parse - private`() async throws {
        let cc = HTTP.CacheControl.parse("private")

        #expect(cc.private != nil)
        #expect(cc.private! == nil)  // Double optional
    }

    @Test
    func `Parse - mustRevalidate`() async throws {
        let cc = HTTP.CacheControl.parse("must-revalidate")

        #expect(cc.mustRevalidate == true)
    }

    @Test
    func `Parse - mustUnderstand`() async throws {
        let cc = HTTP.CacheControl.parse("must-understand")

        #expect(cc.mustUnderstand == true)
    }

    @Test
    func `Parse - sMaxage`() async throws {
        let cc = HTTP.CacheControl.parse("s-maxage=7200")

        #expect(cc.sMaxage == 7200)
    }

    @Test
    func `Parse - immutable`() async throws {
        let cc = HTTP.CacheControl.parse("immutable")

        #expect(cc.immutable == true)
    }

    @Test
    func `Parse - staleWhileRevalidate`() async throws {
        let cc = HTTP.CacheControl.parse("stale-while-revalidate=120")

        #expect(cc.staleWhileRevalidate == 120)
    }

    @Test
    func `Parse - staleIfError`() async throws {
        let cc = HTTP.CacheControl.parse("stale-if-error=86400")

        #expect(cc.staleIfError == 86400)
    }

    @Test
    func `Parse - multiple directives`() async throws {
        let cc = HTTP.CacheControl.parse("public, max-age=3600, must-revalidate")

        #expect(cc.isPublic == true)
        #expect(cc.maxAge == 3600)
        #expect(cc.mustRevalidate == true)
    }

    @Test
    func `Parse - case insensitive`() async throws {
        let cc = HTTP.CacheControl.parse("PUBLIC, MAX-AGE=3600")

        #expect(cc.isPublic == true)
        #expect(cc.maxAge == 3600)
    }

    @Test
    func `Parse - whitespace handling`() async throws {
        let cc = HTTP.CacheControl.parse("  public  ,  max-age = 3600  ")

        #expect(cc.isPublic == true)
        #expect(cc.maxAge == 3600)
    }

    @Test
    func `Parse - unknown directive ignored`() async throws {
        let cc = HTTP.CacheControl.parse("public, unknown-directive=value, max-age=3600")

        #expect(cc.isPublic == true)
        #expect(cc.maxAge == 3600)
        // Unknown directive should be ignored per RFC 9111
    }

    @Test
    func `Equality`() async throws {
        var cc1 = HTTP.CacheControl()
        cc1.maxAge = 3600
        cc1.isPublic = true

        var cc2 = HTTP.CacheControl()
        cc2.maxAge = 3600
        cc2.isPublic = true

        var cc3 = HTTP.CacheControl()
        cc3.maxAge = 7200

        #expect(cc1 == cc2)
        #expect(cc1 != cc3)
    }

    @Test
    func `Hashable`() async throws {
        var set: Set<HTTP.CacheControl> = []

        var cc1 = HTTP.CacheControl()
        cc1.maxAge = 3600

        var cc2 = HTTP.CacheControl()
        cc2.maxAge = 3600

        var cc3 = HTTP.CacheControl()
        cc3.maxAge = 7200

        set.insert(cc1)
        set.insert(cc2)  // Duplicate
        set.insert(cc3)

        #expect(set.count == 2)
    }

    @Test
    func `Codable`() async throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        var cc = HTTP.CacheControl()
        cc.maxAge = 3600
        cc.isPublic = true

        let encoded = try encoder.encode(cc)
        let decoded = try decoder.decode(HTTP.CacheControl.self, from: encoded)

        #expect(decoded == cc)
    }

    @Test
    func `Description`() async throws {
        var cc = HTTP.CacheControl()
        cc.maxAge = 3600
        cc.isPublic = true

        let description = cc.description

        #expect(description.contains("max-age=3600"))
        #expect(description.contains("public"))
    }

    @Test
    func `Round trip - format and parse`() async throws {
        var original = HTTP.CacheControl()
        original.isPublic = true
        original.maxAge = 3600
        original.mustRevalidate = true
        original.immutable = true

        let headerValue = original.headerValue
        let parsed = HTTP.CacheControl.parse(headerValue)

        #expect(parsed.isPublic == original.isPublic)
        #expect(parsed.maxAge == original.maxAge)
        #expect(parsed.mustRevalidate == original.mustRevalidate)
        #expect(parsed.immutable == original.immutable)
    }

    @Test
    func `Request directives`() async throws {
        var cc = HTTP.CacheControl()
        cc.maxAge = 600
        cc.minFresh = 120
        cc.onlyIfCached = true

        let value = cc.headerValue

        #expect(value.contains("max-age=600"))
        #expect(value.contains("min-fresh=120"))
        #expect(value.contains("only-if-cached"))
    }

    @Test
    func `Response directives`() async throws {
        var cc = HTTP.CacheControl()
        cc.isPublic = true
        cc.sMaxage = 7200
        cc.proxyRevalidate = true

        let value = cc.headerValue

        #expect(value.contains("public"))
        #expect(value.contains("s-maxage=7200"))
        #expect(value.contains("proxy-revalidate"))
    }
}
