import RFC_9110
import RFC_9111
import Testing

@Suite
struct `HTTP.Cache.ReuseConditions Tests` {

    @Test
    func `A fresh response is reused`() {
        let decision = HTTP.Cache.ReuseConditions.canReuse(
            response: nil,
            request: nil,
            age: 10,
            freshnessLifetime: 60
        )

        #expect(decision == .canReuse(fresh: true))
        #expect(decision.allowsReuse)
    }

    @Test
    func `no-cache on the request forces validation`() {
        var request = HTTP.Cache.Control()
        request.noCache = true

        #expect(
            HTTP.Cache.ReuseConditions.canReuse(
                response: nil,
                request: request,
                age: 10,
                freshnessLifetime: 60
            ) == .mustValidate(reason: .requestNoCacheDirective)
        )
    }

    @Test
    func `max-stale permits a stale response`() {
        var request = HTTP.Cache.Control()
        request.maxStale = .some(.some(30))

        #expect(
            HTTP.Cache.ReuseConditions.canReuse(
                response: nil,
                request: request,
                age: 80,
                freshnessLifetime: 60
            ) == .canReuse(fresh: false)
        )
    }

    @Test
    func `must-revalidate refuses a stale response`() {
        var response = HTTP.Cache.Control()
        response.mustRevalidate = true

        #expect(
            HTTP.Cache.ReuseConditions.canReuse(
                response: response,
                request: nil,
                age: 80,
                freshnessLifetime: 60
            ) == .mustValidate(reason: .mustRevalidateDirective)
        )
    }

    @Test
    func `stale-while-revalidate serves the stale response`() {
        var response = HTTP.Cache.Control()
        response.staleWhileRevalidate = 30

        let decision = HTTP.Cache.ReuseConditions.canReuse(
            response: response,
            request: nil,
            age: 80,
            freshnessLifetime: 60
        )

        #expect(decision == .canReuseStaleWhileRevalidating)
        #expect(decision.requiresValidation)
    }
}
