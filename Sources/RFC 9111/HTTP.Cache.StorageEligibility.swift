// HTTP.Cache.StorageEligibility.swift
// swift-rfc-9111

extension RFC_9110.Cache {
    /// Storage eligibility checker implementing RFC 9111 Section 3
    public enum StorageEligibility {

        // MARK: - Storage Evaluation

        /// Determine if a response is eligible for storage in a cache
        /// RFC 9111 Section 3: Storing Responses in Caches
        ///
        /// - Parameters:
        ///   - request: The request that generated the response
        ///   - response: The response to evaluate
        ///   - isSharedCache: Whether this is a shared cache (vs private cache)
        /// - Returns: Eligibility result with reason
        public static func isStorable(
            request: RFC_9110.Request,
            response: RFC_9110.Response,
            isSharedCache: Bool = true
        ) -> Result {
            // RFC 9111 Section 3: A cache MUST NOT store a response to a request
            // unless the request method is understood by the cache
            guard isMethodUnderstood(request.method) else {
                return .ineligible(reason: .methodNotUnderstood(request.method))
            }

            // RFC 9111: the response status code is final (see Section 15 of [HTTP]
            guard response.status.isFinal else {
                return .ineligible(reason: .statusNotFinal(response.status.code))
            }

            // RFC 9111: if the no-store cache directive is present, the response MUST NOT be stored
            if let cacheControl = getCacheControl(from: response) {
                if cacheControl.noStore {
                    return .ineligible(reason: .noStoreDirective)
                }

                // RFC 9111: if the cache is shared, the private response directive MUST be respected
                if isSharedCache && cacheControl.private != nil {
                    return .ineligible(reason: .privateDirectiveInSharedCache)
                }
            }

            // RFC 9111: if the request included the Authorization header field and the response contains
            // no directives that allow shared caching, the response MUST NOT be stored by a shared cache
            if isSharedCache && hasAuthorization(request) {
                guard hasExplicitSharingPermission(response) else {
                    return .ineligible(reason: .authorizedRequestWithoutSharingPermission)
                }
            }

            // RFC 9111: the response either contains one of the following...
            if !hasCacheabilityIndicator(response) {
                return .ineligible(reason: .noCacheabilityIndicator)
            }

            return .eligible
        }

        // MARK: - Helper Methods

        /// Check if method is understood by cache
        /// RFC 9111: Typically GET and HEAD
        private static func isMethodUnderstood(_ method: RFC_9110.Method) -> Bool {
            switch method {
            case .get, .head:
                return true
            case .post:
                // POST can be cached with explicit directives
                return true
            default:
                return false
            }
        }

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

        /// Check if request has Authorization header
        private static func hasAuthorization(_ request: RFC_9110.Request) -> Bool {
            request.headers.contains { $0.name.rawValue.lowercased() == "authorization" }
        }

        /// Check if response has explicit sharing permission for authorized requests
        /// RFC 9111 Section 3.5: must-revalidate, public, or s-maxage directive
        private static func hasExplicitSharingPermission(_ response: RFC_9110.Response) -> Bool {
            guard let cacheControl = getCacheControl(from: response) else {
                return false
            }

            return cacheControl.isPublic || cacheControl.mustRevalidate
                || cacheControl.sMaxage != nil
        }

        /// Check if response has a cacheability indicator
        /// RFC 9111 Section 3: at least one of:
        /// - public response directive
        /// - private response directive (if cache is not shared)
        /// - Expires header field
        /// - max-age response directive
        /// - if the cache is shared: an s-maxage response directive
        /// - a cache extension that allows it to be cached
        /// - a status code that is defined as heuristically cacheable
        private static func hasCacheabilityIndicator(_ response: RFC_9110.Response) -> Bool {
            // Check for cache directives
            if let cacheControl = getCacheControl(from: response) {
                if cacheControl.isPublic || cacheControl.private != nil
                    || cacheControl.maxAge != nil || cacheControl.sMaxage != nil
                {
                    return true
                }
            }

            // Check for Expires header
            if response.headers.contains(where: { $0.name.rawValue.lowercased() == "expires" }) {
                return true
            }

            // Check for heuristically cacheable status codes
            // RFC 9111 Section 4.2.2: 200, 203, 204, 206, 300, 301, 308, 404, 405, 410, 414, 501
            if isHeuristicallyCacheable(response.status.code) {
                return true
            }

            return false
        }

        /// Check if status code is heuristically cacheable
        /// RFC 9111 Section 4.2.2
        private static func isHeuristicallyCacheable(_ code: Int) -> Bool {
            switch code {
            case 200, 203, 204, 206, 300, 301, 308, 404, 405, 410, 414, 501:
                return true
            default:
                return false
            }
        }

        // MARK: - Result Types

        /// Storage eligibility result
        public enum Result: Sendable, Equatable {
            case eligible
            case ineligible(reason: IneligibilityReason)

            public var isEligible: Bool {
                if case .eligible = self {
                    return true
                }
                return false
            }
        }

        /// Reason for storage ineligibility
        public enum IneligibilityReason: Sendable, Equatable {
            case methodNotUnderstood(RFC_9110.Method)
            case statusNotFinal(Int)
            case noStoreDirective
            case privateDirectiveInSharedCache
            case authorizedRequestWithoutSharingPermission
            case noCacheabilityIndicator
        }
    }
}
