// HTTP.Cache.ReuseConditions.swift
// swift-rfc-9111

extension RFC_9110.Cache {
    /// Response reuse conditions implementing RFC 9111 Section 4
    public enum ReuseConditions {}
}

extension RFC_9110.Cache.ReuseConditions {

    // MARK: - Reuse Evaluation

    /// Determine if a stored response can be reused for a request
    /// RFC 9111 Section 4: Constructing Responses from Caches
    ///
    /// - Parameters:
    ///   - storedResponse: The stored response
    ///   - request: The incoming request
    ///   - age: The current age of the stored response
    ///   - freshnessLifetime: The freshness lifetime of the response
    /// - Returns: Reuse decision with reason
    public static func canReuse(
        storedResponse: RFC_9110.Response,
        for request: RFC_9110.Request,
        age: Double,
        freshnessLifetime: Double
    ) -> ReuseDecision {
        // RFC 9111 Section 4.2: Check freshness first
        let isFresh = age < freshnessLifetime

        // Get cache control directives
        let responseCacheControl = getCacheControl(from: storedResponse)
        let requestCacheControl = getCacheControl(from: request)

        // RFC 9111 Section 5.2.1.4: no-cache request directive
        // The client prefers to validate before using cached response
        if let reqCC = requestCacheControl, reqCC.noCache {
            return .mustValidate(reason: .requestNoCacheDirective)
        }

        // RFC 9111 Section 5.2.2.1: no-cache response directive
        // Must validate with origin before reusing
        if let respCC = responseCacheControl, respCC.noCache {
            return .mustValidate(reason: .responseNoCacheDirective)
        }

        // RFC 9111 Section 4.2.1: Fresh responses can be reused
        if isFresh {
            // Check request constraints even for fresh responses
            if let reqCC = requestCacheControl {
                // RFC 9111 Section 5.2.1.1: max-age request directive
                if let requestMaxAge = reqCC.maxAge, age > Double(requestMaxAge) {
                    return .mustValidate(reason: .exceedsRequestMaxAge)
                }

                // RFC 9111 Section 5.2.1.3: min-fresh request directive
                if let minFresh = reqCC.minFresh {
                    let remainingFreshness = freshnessLifetime - age
                    if remainingFreshness < Double(minFresh) {
                        return .mustValidate(reason: .insufficientRemainingFreshness)
                    }
                }
            }

            return .canReuse(fresh: true)
        }

        // Response is stale - check if stale reuse is allowed

        // RFC 9111 Section 5.2.2.1: must-revalidate prohibits stale reuse
        if let respCC = responseCacheControl, respCC.mustRevalidate {
            return .mustValidate(reason: .mustRevalidateDirective)
        }

        // RFC 9111 Section 5.2.2.7: proxy-revalidate for shared caches
        if let respCC = responseCacheControl, respCC.proxyRevalidate {
            // For shared caches, this acts like must-revalidate
            return .mustValidate(reason: .proxyRevalidateDirective)
        }

        // RFC 9111 Section 5.2.1.2: max-stale request directive
        if let reqCC = requestCacheControl, let maxStale = reqCC.maxStale {
            let staleness = age - freshnessLifetime

            // max-stale with no value: accept any staleness
            if maxStale == nil {
                return .canReuse(fresh: false)
            }

            // max-stale with value: accept if within limit
            if let maxStaleSeconds = maxStale, staleness <= Double(maxStaleSeconds) {
                return .canReuse(fresh: false)
            }

            // Exceeds max-stale limit
            return .mustValidate(reason: .exceedsMaxStale)
        }

        // RFC 9111 Section 5.2.2.8: stale-while-revalidate
        if let respCC = responseCacheControl, let swr = respCC.staleWhileRevalidate {
            let staleness = age - freshnessLifetime
            if staleness <= Double(swr) {
                return .canReuseStaleWhileRevalidating
            }
        }

        // RFC 9111 Section 5.2.2.9: stale-if-error
        // This is checked during error conditions, not regular reuse

        // Default: stale responses require validation unless explicitly allowed
        return .mustValidate(reason: .staleWithoutPermission)
    }

    // MARK: - Helper Methods

    /// Get Cache-Control from response
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

    /// Get Cache-Control from request
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

    // MARK: - Decision Types

    /// Cache reuse decision
    public enum ReuseDecision: Sendable, Equatable {
        /// Response can be reused without validation
        case canReuse(fresh: Bool)

        /// Response can be reused while revalidating in background
        case canReuseStaleWhileRevalidating

        /// Must validate with origin before reusing
        case mustValidate(reason: ValidationReason)
    }

    /// Reason validation is required
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
