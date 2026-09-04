public import RFC_9110

extension RFC_9110.Cache {

    public enum ReuseConditions {}
}

extension RFC_9110.Cache.ReuseConditions {

    public static func canReuse(
        response: RFC_9110.Cache.Control?,
        request: RFC_9110.Cache.Control?,
        age: Double,
        freshnessLifetime: Double
    ) -> Decision {

        let isFresh = age < freshnessLifetime

        if let request, request.noCache {
            return .mustValidate(reason: .requestNoCacheDirective)
        }

        if let response, response.noCache {
            return .mustValidate(reason: .responseNoCacheDirective)
        }

        if isFresh {

            if let request {

                if let requestMaxAge = request.maxAge, age > Double(requestMaxAge) {
                    return .mustValidate(reason: .exceedsRequestMaxAge)
                }

                if let minFresh = request.minFresh {
                    let remainingFreshness = freshnessLifetime - age
                    if remainingFreshness < Double(minFresh) {
                        return .mustValidate(reason: .insufficientRemainingFreshness)
                    }
                }
            }

            return .canReuse(fresh: true)
        }

        if let response, response.mustRevalidate {
            return .mustValidate(reason: .mustRevalidateDirective)
        }

        if let response, response.proxyRevalidate {
            return .mustValidate(reason: .proxyRevalidateDirective)
        }

        if let request, let maxStale = request.maxStale {
            let staleness = age - freshnessLifetime

            if maxStale == nil {
                return .canReuse(fresh: false)
            }

            if let maxStaleSeconds = maxStale, staleness <= Double(maxStaleSeconds) {
                return .canReuse(fresh: false)
            }

            return .mustValidate(reason: .exceedsMaxStale)
        }

        if let response, let staleWhileRevalidate = response.staleWhileRevalidate {
            let staleness = age - freshnessLifetime
            if staleness <= Double(staleWhileRevalidate) {
                return .canReuseStaleWhileRevalidating
            }
        }

        return .mustValidate(reason: .staleWithoutPermission)
    }

    public enum Decision: Sendable, Equatable {

        case canReuse(fresh: Bool)

        case canReuseStaleWhileRevalidating

        case mustValidate(reason: Reason)
    }

    public enum Reason: Sendable, Equatable {
        case requestNoCacheDirective
        case responseNoCacheDirective
        case exceedsRequestMaxAge
        case insufficientRemainingFreshness
        case mustRevalidateDirective
        case proxyRevalidateDirective
        case exceedsMaxStale
        case staleWithoutPermission
    }
}

extension RFC_9110.Cache.ReuseConditions.Decision {
    public var allowsReuse: Bool {
        switch self {
        case .canReuse, .canReuseStaleWhileRevalidating:
            return true

        case .mustValidate:
            return false
        }
    }

    public var requiresValidation: Bool {
        switch self {
        case .mustValidate, .canReuseStaleWhileRevalidating:
            return true

        case .canReuse:
            return false
        }
    }
}
