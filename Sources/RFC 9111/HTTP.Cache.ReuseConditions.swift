extension RFC_9110.Cache {

    public enum ReuseConditions {}
}

extension RFC_9110.Cache.ReuseConditions {

    public static func canReuse(
        storedResponse: RFC_9110.Response,
        for request: RFC_9110.Request,
        age: Double,
        freshnessLifetime: Double
    ) -> ReuseDecision {

        let isFresh = age < freshnessLifetime

        let responseCacheControl = getCacheControl(from: storedResponse)
        let requestCacheControl = getCacheControl(from: request)

        if let reqCC = requestCacheControl, reqCC.noCache {
            return .mustValidate(reason: .requestNoCacheDirective)
        }

        if let respCC = responseCacheControl, respCC.noCache {
            return .mustValidate(reason: .responseNoCacheDirective)
        }

        if isFresh {

            if let reqCC = requestCacheControl {

                if let requestMaxAge = reqCC.maxAge, age > Double(requestMaxAge) {
                    return .mustValidate(reason: .exceedsRequestMaxAge)
                }

                if let minFresh = reqCC.minFresh {
                    let remainingFreshness = freshnessLifetime - age
                    if remainingFreshness < Double(minFresh) {
                        return .mustValidate(reason: .insufficientRemainingFreshness)
                    }
                }
            }

            return .canReuse(fresh: true)
        }

        if let respCC = responseCacheControl, respCC.mustRevalidate {
            return .mustValidate(reason: .mustRevalidateDirective)
        }

        if let respCC = responseCacheControl, respCC.proxyRevalidate {

            return .mustValidate(reason: .proxyRevalidateDirective)
        }

        if let reqCC = requestCacheControl, let maxStale = reqCC.maxStale {
            let staleness = age - freshnessLifetime

            if maxStale == nil {
                return .canReuse(fresh: false)
            }

            if let maxStaleSeconds = maxStale, staleness <= Double(maxStaleSeconds) {
                return .canReuse(fresh: false)
            }

            return .mustValidate(reason: .exceedsMaxStale)
        }

        if let respCC = responseCacheControl, let swr = respCC.staleWhileRevalidate {
            let staleness = age - freshnessLifetime
            if staleness <= Double(swr) {
                return .canReuseStaleWhileRevalidating
            }
        }

        return .mustValidate(reason: .staleWithoutPermission)
    }

    private static func getCacheControl(
        from response: RFC_9110.Response
    ) -> RFC_9110.CacheControl? {
        guard
            let header = response.headers.first(where: {
                $0.name.rawValue.lowercased() == "cache-control"
            })
        else {
            return nil
        }
        return RFC_9110.CacheControl.parse(header.value.rawValue)
    }

    private static func getCacheControl(
        from request: RFC_9110.Request
    ) -> RFC_9110.CacheControl? {
        guard
            let header = request.headers.first(where: {
                $0.name.rawValue.lowercased() == "cache-control"
            })
        else {
            return nil
        }
        return RFC_9110.CacheControl.parse(header.value.rawValue)
    }

    public enum ReuseDecision: Sendable, Equatable {

        case canReuse(fresh: Bool)

        case canReuseStaleWhileRevalidating

        case mustValidate(reason: ValidationReason)
    }

    public enum ValidationReason: Sendable, Equatable {
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

extension RFC_9110.Cache.ReuseConditions.ReuseDecision {
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
