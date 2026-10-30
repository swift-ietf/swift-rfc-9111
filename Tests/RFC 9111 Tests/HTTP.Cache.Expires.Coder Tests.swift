#if Coder
    import Byte
    import Coder
    import Cursor
    import RFC_5322
    import RFC_9110
    import RFC_9111
    import Testing

    @Suite
    struct `HTTP.Cache.Expires.Coder Tests` {

        @Test
        func `An expiration round-trips through IMF-fixdate`() throws {
            let expires = HTTP.Cache.Expires(date: HTTP.Date(secondsSinceEpoch: 784_111_777))

            var bytes: [Byte] = []
            try HTTP.Cache.Expires.coder.serialize(expires, into: &bytes)
            #expect(String(decoding: bytes, as: UTF8.self) == "Sun, 06 Nov 1994 08:49:37 GMT")

            var input = bytes[...]
            #expect(try HTTP.Cache.Expires.coder.parse(&input) == expires)
        }

        @Test
        func `A malformed date is refused`() {
            var input = [Byte](utf8: "2024-11-16")[...]

            #expect(throws: HTTP.Cache.Expires.Error.invalidDate("2024-11-16")) {
                try HTTP.Cache.Expires.coder.parse(&input)
            }
        }

        @Test
        func `An empty value is refused`() {
            var input = [Byte](utf8: "")[...]

            #expect(throws: HTTP.Cache.Expires.Error.empty) {
                try HTTP.Cache.Expires.coder.parse(&input)
            }
        }
    }
#endif
