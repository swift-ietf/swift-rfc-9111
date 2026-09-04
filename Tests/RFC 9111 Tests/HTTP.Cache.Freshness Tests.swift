import RFC_5322
import RFC_9110
import RFC_9111
import Testing

@Suite
struct `HTTP.Cache.Freshness Tests` {

    static let date = HTTP.Date(secondsSinceEpoch: 1_445_412_480)

    @Test
    func `max-age gives the freshness lifetime`() {
        var control = HTTP.Cache.Control()
        control.maxAge = 3600

        #expect(
            HTTP.Cache.Freshness.lifetime(
                control: control,
                expires: nil,
                date: Self.date
            ) == 3600
        )
    }

    @Test
    func `s-maxage overrides max-age for a shared cache`() {
        var control = HTTP.Cache.Control()
        control.maxAge = 60
        control.sMaxage = 600

        #expect(
            HTTP.Cache.Freshness.lifetime(
                control: control,
                expires: nil,
                date: Self.date,
                isSharedCache: true
            ) == 600
        )

        #expect(
            HTTP.Cache.Freshness.lifetime(
                control: control,
                expires: nil,
                date: Self.date
            ) == 60
        )
    }

    @Test
    func `Expires is the lifetime when no directive applies`() {
        let expires = HTTP.Cache.Expires(
            date: HTTP.Date(secondsSinceEpoch: Self.date.secondsSinceEpoch + 120)
        )

        #expect(
            HTTP.Cache.Freshness.lifetime(
                control: nil,
                expires: expires,
                date: Self.date
            ) == 120
        )
    }

    @Test
    func `Heuristics take a tenth of the time since last modification`() {
        let lastModified = HTTP.Date(secondsSinceEpoch: Self.date.secondsSinceEpoch - 1000)

        #expect(
            HTTP.Cache.Freshness.lifetime(
                control: nil,
                expires: nil,
                date: Self.date,
                lastModified: lastModified,
                allowHeuristics: true
            ) == 100
        )
    }

    @Test
    func `Without any indicator the lifetime is zero`() {
        #expect(
            HTTP.Cache.Freshness.lifetime(
                control: nil,
                expires: nil,
                date: Self.date
            ) == 0
        )
    }

    @Test
    func `Age adds the carried age to the time resident in the cache`() {
        let responseTime = HTTP.Date(secondsSinceEpoch: Self.date.secondsSinceEpoch + 10)
        let now = HTTP.Date(secondsSinceEpoch: Self.date.secondsSinceEpoch + 100)

        #expect(
            HTTP.Cache.Freshness.age(
                carried: HTTP.Cache.Age(seconds: 5),
                date: Self.date,
                now: now,
                requestTime: Self.date,
                responseTime: responseTime
            ) == 105
        )
    }

    @Test
    func `A response younger than its lifetime is fresh`() {
        var control = HTTP.Cache.Control()
        control.maxAge = 3600

        #expect(
            HTTP.Cache.Freshness.isFresh(
                control: control,
                expires: nil,
                carried: nil,
                date: Self.date,
                now: HTTP.Date(secondsSinceEpoch: Self.date.secondsSinceEpoch + 60),
                responseTime: Self.date
            )
        )
    }

    @Test
    func `A stale date exists only for a positive lifetime`() {
        var control = HTTP.Cache.Control()
        control.maxAge = 60

        #expect(
            HTTP.Cache.Freshness.staleDate(
                control: control,
                expires: nil,
                date: Self.date,
                responseTime: Self.date
            ) == HTTP.Date(secondsSinceEpoch: Self.date.secondsSinceEpoch + 60)
        )

        #expect(
            HTTP.Cache.Freshness.staleDate(
                control: nil,
                expires: nil,
                date: Self.date,
                responseTime: Self.date
            ) == nil
        )
    }
}
