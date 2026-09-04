import RFC_9110
import RFC_9111
import Testing

@Suite
struct `HTTP.Cache.Control Tests` {

    @Test
    func `A new control carries no directives`() {
        let control = HTTP.Cache.Control()

        #expect(control.maxAge == nil)
        #expect(control.maxStale == nil)
        #expect(control.private == nil)
        #expect(!control.noStore)
        #expect(!control.isPublic)
    }

    @Test
    func `A present directive without a value is distinct from an absent one`() {
        var control = HTTP.Cache.Control()
        control.maxStale = .some(nil)

        #expect(control.maxStale != nil)
        #expect(control.maxStale == .some(nil))
    }

    @Test
    func `Controls with the same directives are equal`() {
        var one = HTTP.Cache.Control()
        one.maxAge = 60
        var other = HTTP.Cache.Control()
        other.maxAge = 60

        #expect(one == other)
    }
}
