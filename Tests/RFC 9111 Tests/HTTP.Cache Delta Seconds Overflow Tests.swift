#if Coder
    import Byte
    import Coder
    import Cursor
    import RFC_9110
    import RFC_9111
    import Testing

    @Suite
    struct `Delta seconds overflow` {
        @Test
        func `an age too large to represent is read as two to the thirty-first`() throws {
            var input = [Byte](utf8: "99999999999999999999")[...]
            #expect(try HTTP.Cache.Age.coder.parse(&input) == HTTP.Cache.Age(seconds: 2_147_483_648))
        }

        @Test
        func `a max-age too large to represent is read as two to the thirty-first`() throws {
            var input = [Byte](utf8: "max-age=99999999999999999999, s-maxage=99999999999999999999")[...]
            let control = HTTP.Cache.Control.coder.parse(&input)
            #expect(control.maxAge == 2_147_483_648)
            #expect(control.sMaxage == 2_147_483_648)
        }

        @Test
        func `a signed delta-seconds value is ignored`() throws {
            var input = [Byte](utf8: "max-age=-5, min-fresh=+5")[...]
            let control = HTTP.Cache.Control.coder.parse(&input)
            #expect(control.maxAge == nil)
            #expect(control.minFresh == nil)
        }
    }
#endif
