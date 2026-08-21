extension RFC_9110.Cache {

    public enum StorageEligibility {}
}

extension RFC_9110.Cache.StorageEligibility {

    public static func isStorable(
        request: RFC_9110.Request,
        response: RFC_9110.Response,
        isSharedCache: Bool = true
    ) -> Result {

        guard isMethodUnderstood(request.method) else {
            return .ineligible(reason: .methodNotUnderstood(request.method))
        }

        guard response.status.isFinal else {
            return .ineligible(reason: .statusNotFinal(response.status.code))
        }

        if let cacheControl = getCacheControl(from: response) {
            if cacheControl.noStore {
                return .ineligible(reason: .noStoreDirective)
            }

            if isSharedCache && cacheControl.private != nil {
                return .ineligible(reason: .privateDirectiveInSharedCache)
            }
        }

        if isSharedCache && hasAuthorization(request) {
            guard hasExplicitSharingPermission(response) else {
                return .ineligible(reason: .authorizedRequestWithoutSharingPermission)
            }
        }

        if !hasCacheabilityIndicator(response) {
            return .ineligible(reason: .noCacheabilityIndicator)
        }

        return .eligible
    }

    private static func isMethodUnderstood(_ method: RFC_9110.Method) -> Bool {
        switch method {
        case .get, .head:
            return true

        case .post:

            return true

        default:
            return false
        }
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

    private static func hasAuthorization(_ request: RFC_9110.Request) -> Bool {
        request.headers.contains { $0.name.rawValue.lowercased() == "authorization" }
    }

    private static func hasExplicitSharingPermission(_ response: RFC_9110.Response) -> Bool {
        guard let cacheControl = getCacheControl(from: response) else {
            return false
        }

        return cacheControl.isPublic || cacheControl.mustRevalidate
            || cacheControl.sMaxage != nil
    }

    private static func hasCacheabilityIndicator(_ response: RFC_9110.Response) -> Bool {

        if let cacheControl = getCacheControl(from: response) {
            if cacheControl.isPublic || cacheControl.private != nil
                || cacheControl.maxAge != nil || cacheControl.sMaxage != nil
            {
                return true
            }
        }

        if response.headers.contains(where: { $0.name.rawValue.lowercased() == "expires" }) {
            return true
        }

        if isHeuristicallyCacheable(response.status.code) {
            return true
        }

        return false
    }

    private static func isHeuristicallyCacheable(_ code: Int) -> Bool {
        switch code {
        case 200, 203, 204, 206, 300, 301, 308, 404, 405, 410, 414, 501:
            return true

        default:
            return false
        }
    }

    public enum Result: Sendable, Equatable {
        case eligible
        case ineligible(reason: IneligibilityReason)
    }

    public enum IneligibilityReason: Sendable, Equatable {
        case methodNotUnderstood(RFC_9110.Method)
        case statusNotFinal(Int)
        case noStoreDirective
        case privateDirectiveInSharedCache
        case authorizedRequestWithoutSharingPermission
        case noCacheabilityIndicator
    }
}

extension RFC_9110.Cache.StorageEligibility.Result {
    public var isEligible: Bool {
        if case .eligible = self {
            return true
        }
        return false
    }
}
