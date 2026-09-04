public import RFC_9110

extension RFC_9110.Cache.Storage {

    public enum Eligibility {}
}

extension RFC_9110.Cache.Storage.Eligibility {

    public static func isStorable(
        method: RFC_9110.Method,
        status: RFC_9110.Status,
        control: RFC_9110.Cache.Control?,
        isAuthorized: Bool = false,
        hasExpires: Bool = false,
        isSharedCache: Bool = true
    ) -> Result {

        guard Self.isUnderstood(method) else {
            return .ineligible(reason: .methodNotUnderstood(method))
        }

        guard status.isFinal else {
            return .ineligible(reason: .statusNotFinal(status))
        }

        if let control {
            if control.noStore {
                return .ineligible(reason: .noStoreDirective)
            }

            if isSharedCache && control.private != nil {
                return .ineligible(reason: .privateDirectiveInSharedCache)
            }
        }

        if isSharedCache && isAuthorized {
            guard Self.permitsSharing(control) else {
                return .ineligible(reason: .authorizedRequestWithoutSharingPermission)
            }
        }

        guard Self.isCacheable(control: control, hasExpires: hasExpires, status: status) else {
            return .ineligible(reason: .noCacheabilityIndicator)
        }

        return .eligible
    }

    private static func isUnderstood(_ method: RFC_9110.Method) -> Bool {
        switch method {
        case .get, .head, .post:
            return true

        default:
            return false
        }
    }

    private static func permitsSharing(_ control: RFC_9110.Cache.Control?) -> Bool {
        guard let control else {
            return false
        }

        return control.isPublic || control.mustRevalidate || control.sMaxage != nil
    }

    private static func isCacheable(
        control: RFC_9110.Cache.Control?,
        hasExpires: Bool,
        status: RFC_9110.Status
    ) -> Bool {

        if let control {
            if control.isPublic || control.private != nil
                || control.maxAge != nil || control.sMaxage != nil
            {
                return true
            }
        }

        if hasExpires {
            return true
        }

        return Self.isHeuristicallyCacheable(status)
    }

    private static func isHeuristicallyCacheable(_ status: RFC_9110.Status) -> Bool {
        switch status.code {
        case 200, 203, 204, 206, 300, 301, 308, 404, 405, 410, 414, 501:
            return true

        default:
            return false
        }
    }

    public enum Result: Equatable {
        case eligible
        case ineligible(reason: Reason)
    }

    public enum Reason: Equatable {
        case methodNotUnderstood(RFC_9110.Method)
        case statusNotFinal(RFC_9110.Status)
        case noStoreDirective
        case privateDirectiveInSharedCache
        case authorizedRequestWithoutSharingPermission
        case noCacheabilityIndicator
    }
}

extension RFC_9110.Cache.Storage.Eligibility.Result {
    public var isEligible: Bool {
        if case .eligible = self {
            return true
        }
        return false
    }
}
