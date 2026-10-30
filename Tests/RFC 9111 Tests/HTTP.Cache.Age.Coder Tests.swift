#if Coder
    import Byte
    import Coder
    import Cursor
    import RFC_9110
    import RFC_9111
    import Testing

    @Suite
    struct `HTTP.Cache.Age.Coder Tests` {

        @Test
        func `An age round-trips through bytes`() throws {
            let age = HTTP.Cache.Age(seconds: 120)

            var bytes: [Byte] = []
            try HTTP.Cache.Age.coder.serialize(age, into: &bytes)
            #expect(bytes == [Byte](utf8: "120"))

            var input = bytes[...]
            #expect(try HTTP.Cache.Age.coder.parse(&input) == age)
            #expect(input.isEmpty)
        }

        @Test
        func `An age stops at the first non-digit`() throws {
            var input = [Byte](utf8: "120, 30")[...]

            #expect(try HTTP.Cache.Age.coder.parse(&input) == HTTP.Cache.Age(seconds: 120))
            #expect(input.first?.bitPattern == 0x2C)
        }

        @Test
        func `An empty age is refused`() {
            var input = [Byte](utf8: "invalid")[...]

            #expect(throws: HTTP.Cache.Age.Error.empty) {
                try HTTP.Cache.Age.coder.parse(&input)
            }
        }

        @Test
        func `A negative age is not a number of seconds`() {
            var input = [Byte](utf8: "-5")[...]

            #expect(throws: HTTP.Cache.Age.Error.empty) {
                try HTTP.Cache.Age.coder.parse(&input)
            }
        }
    }
#endif
