import RFC_5322
import RFC_9110
import RFC_9111
import Testing

@Suite
struct `HTTP.Cache.Expires Tests` {

    @Test
    func `An expiration in the past has expired`() {
        let now = HTTP.Date(secondsSinceEpoch: 1_445_412_480)
        let expires = HTTP.Cache.Expires(
            date: HTTP.Date(secondsSinceEpoch: now.secondsSinceEpoch - 3600)
        )

        #expect(expires.isExpired(at: now))
        #expect(expires.timeRemaining(from: now) == -3600)
    }

    @Test
    func `An expiration in the future has not expired`() {
        let now = HTTP.Date(secondsSinceEpoch: 1_445_412_480)
        let expires = HTTP.Cache.Expires(
            date: HTTP.Date(secondsSinceEpoch: now.secondsSinceEpoch + 3600)
        )

        #expect(!expires.isExpired(at: now))
        #expect(expires.timeRemaining(from: now) == 3600)
    }

    @Test
    func `Expirations order by date`() {
        let earlier = HTTP.Cache.Expires(date: HTTP.Date(secondsSinceEpoch: 1000))
        let later = HTTP.Cache.Expires(date: HTTP.Date(secondsSinceEpoch: 2000))

        #expect(earlier < later)
    }
}
