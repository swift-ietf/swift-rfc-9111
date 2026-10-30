#if Coder
    import Byte
    import Coder
    import Cursor
    import RFC_9110
    import RFC_9111
    import Testing

    @Suite
    struct `HTTP.Cache.Control.Coder Tests` {

        @Test
        func `Directives round-trip through bytes`() throws {
            var control = HTTP.Cache.Control()
            control.maxAge = 3600
            control.noStore = true
            control.isPublic = true

            var bytes: [Byte] = []
            HTTP.Cache.Control.coder.serialize(control, into: &bytes)
            #expect(String(decoding: bytes, as: UTF8.self) == "max-age=3600, no-store, public")

            var input = bytes[...]
            #expect(HTTP.Cache.Control.coder.parse(&input) == control)
        }

        @Test
        func `A valueless directive parses as present`() {
            var input = [Byte](utf8: "no-cache, max-stale")[...]
            let control = HTTP.Cache.Control.coder.parse(&input)

            #expect(control.noCache)
            #expect(control.maxStale == .some(nil))
        }

        @Test
        func `A quoted private directive carries field names`() {
            var input = [Byte](utf8: "private=\"set-cookie, authorization\"")[...]
            let control = HTTP.Cache.Control.coder.parse(&input)

            #expect(control.private == .some(["set-cookie", "authorization"]))
        }

        @Test
        func `An unknown directive is ignored`() {
            var input = [Byte](utf8: "max-age=60, surrogate-control=none")[...]
            let control = HTTP.Cache.Control.coder.parse(&input)

            #expect(control.maxAge == 60)
        }
    }
#endif
