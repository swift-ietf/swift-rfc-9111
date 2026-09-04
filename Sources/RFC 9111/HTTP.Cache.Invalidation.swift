public import RFC_3986
public import RFC_9110

extension RFC_9110.Cache {

    public enum Invalidation {}
}

extension RFC_9110.Cache.Invalidation {

    public static func targets(
        method: RFC_9110.Method,
        status: RFC_9110.Status,
        target: RFC_9110.Target,
        location: RFC_3986.URI? = nil,
        contentLocation: RFC_3986.URI? = nil
    ) -> [Target] {

        guard Self.isUnsafe(method) else {
            return []
        }

        guard !status.isClientError && !status.isServerError else {
            return []
        }

        var targets: [Target] = [.requestTarget(target)]

        if let location, Self.isSameOrigin(location, as: target) {
            targets.append(.location(location))
        }

        if let contentLocation, Self.isSameOrigin(contentLocation, as: target) {
            targets.append(.contentLocation(contentLocation))
        }

        return targets
    }

    private static func isUnsafe(_ method: RFC_9110.Method) -> Bool {
        switch method {
        case .put, .delete, .post:
            return true

        default:
            return false
        }
    }

    private static func isSameOrigin(
        _ uri: RFC_3986.URI,
        as target: RFC_9110.Target
    ) -> Bool {

        guard case .resource(let resource) = target else {
            return true
        }

        guard let scheme = resource.scheme, let host = resource.host else {
            return true
        }

        guard uri.scheme == scheme, uri.host == host else {
            return false
        }

        return Self.port(uri.port, for: uri.scheme) == Self.port(resource.port, for: scheme)
    }

    private static func port(
        _ port: RFC_3986.URI.Port?,
        for scheme: RFC_3986.URI.Scheme?
    ) -> UInt16 {
        if let port {
            return port.value
        }

        return scheme?.defaultPort ?? 80
    }

    public enum Target: Equatable {

        case requestTarget(RFC_9110.Target)

        case location(RFC_3986.URI)

        case contentLocation(RFC_3986.URI)
    }
}

extension RFC_9110.Cache.Invalidation.Target {

    public var isMandatory: Bool {
        if case .requestTarget = self {
            return true
        }
        return false
    }
}
