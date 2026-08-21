import RFC_3986

extension RFC_9110.Cache {

    public enum Invalidation {}
}

extension RFC_9110.Cache.Invalidation {

    public static func getInvalidationTargets(
        request: RFC_9110.Request,
        response: RFC_9110.Response
    ) -> [InvalidationTarget] {

        guard isUnsafeMethod(request.method) else {
            return []
        }

        guard !response.status.isClientError && !response.status.isServerError else {
            return []
        }

        var targets: [InvalidationTarget] = []

        targets.append(.requestTarget(uri: getRequestTargetURI(request)))

        if let locationURI = getLocationURI(from: response),
            isSameOrigin(locationURI, as: request)
        {
            targets.append(.location(uri: locationURI))
        }

        if let contentLocationURI = getContentLocationURI(from: response),
            isSameOrigin(contentLocationURI, as: request)
        {
            targets.append(.contentLocation(uri: contentLocationURI))
        }

        return targets
    }

    private static func isUnsafeMethod(_ method: RFC_9110.Method) -> Bool {
        switch method {
        case .put, .delete, .post:
            return true

        default:
            return false
        }
    }

    private static func getRequestTargetURI(_ request: RFC_9110.Request) -> String {
        switch request.target {
        case .origin(let path, let query):
            if let query {
                return "\(path.description)?\(query.description)"
            }
            return path.description

        case .absolute(let uri):
            return uri.description

        case .authority(let authority):
            return authority.description

        case .asterisk:
            return "*"
        }
    }

    private static func getLocationURI(from response: RFC_9110.Response) -> String? {
        response.headers.first { $0.name.rawValue.lowercased() == "location" }?.value.rawValue
    }

    private static func getContentLocationURI(from response: RFC_9110.Response) -> String? {
        response.headers.first { $0.name.rawValue.lowercased() == "content-location" }?.value
            .rawValue
    }

    private static func isSameOrigin(_ uriString: String, as request: RFC_9110.Request) -> Bool {

        let uri: RFC_3986.URI
        do throws(RFC_3986.Error) {
            uri = try RFC_3986.URI(uriString)
        } catch {

            return false
        }

        let requestScheme: RFC_3986.URI.Scheme?
        let requestHost: RFC_3986.URI.Host?
        let requestPort: RFC_3986.URI.Port?

        switch request.target {
        case .absolute(let requestURI):
            requestScheme = requestURI.scheme
            requestHost = requestURI.host
            requestPort = requestURI.port

        case .origin, .authority, .asterisk:

            return true
        }

        guard let reqScheme = requestScheme, let reqHost = requestHost else {

            return false
        }

        guard uri.scheme == reqScheme, uri.host == reqHost else {
            return false
        }

        let uriPort = uri.port.map { Int($0.value) } ?? defaultPort(for: uri.scheme)
        let requestPortValue = requestPort.map { Int($0.value) } ?? defaultPort(for: reqScheme)

        return uriPort == requestPortValue
    }

    private static func defaultPort(for scheme: RFC_3986.URI.Scheme?) -> Int {
        guard let scheme else { return 80 }

        let schemeString = scheme.description.lowercased()
        switch schemeString {
        case "http":
            return 80

        case "https":
            return 443

        default:
            return 80
        }
    }

    public enum InvalidationTarget: Sendable, Equatable {

        case requestTarget(uri: String)

        case location(uri: String)

        case contentLocation(uri: String)
    }
}

extension RFC_9110.Cache.Invalidation.InvalidationTarget {
    public var uri: String {
        switch self {
        case .requestTarget(let uri),
            .location(let uri),
            .contentLocation(let uri):
            return uri
        }
    }

    public var isMandatory: Bool {
        if case .requestTarget = self {
            return true
        }
        return false
    }
}
