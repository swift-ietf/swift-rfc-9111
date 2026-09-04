import RFC_9110
import RFC_9111
import Testing

@Suite
struct `HTTP.Cache.Age Tests` {

    @Test
    func `An age carries a number of seconds`() {
        #expect(HTTP.Cache.Age(seconds: 120).seconds == 120)
        #expect(HTTP.Cache.Age(seconds: 0).seconds == 0)
    }

    @Test
    func `An age is written as an integer literal`() {
        let age: HTTP.Cache.Age = 120

        #expect(age == HTTP.Cache.Age(seconds: 120))
    }

    @Test
    func `Ages order by seconds`() {
        #expect(HTTP.Cache.Age(seconds: 100) < HTTP.Cache.Age(seconds: 200))
    }

    @Test
    func `Equal ages hash alike`() {
        let set: Set<HTTP.Cache.Age> = [120, 120, 121]

        #expect(set.count == 2)
    }
}
