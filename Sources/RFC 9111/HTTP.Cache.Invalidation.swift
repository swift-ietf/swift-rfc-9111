// HTTP.Cache.Invalidation.swift
// swift-rfc-9111

import RFC_3986

extension RFC_9110.Cache {
    /// Cache invalidation implementing RFC 9111 Section 4.4
    public enum Invalidation {

        // MARK: - Invalidation Rules

        /// Determine if a request/response pair should trigger cache invalidation
        /// RFC 9111 Section 4.4: Invalidating Stored Responses
        ///
        /// - Parameters:
        ///   - request: The request
        ///   - response: The response
        /// - Returns: URIs that should be invalidated
        public static func getInvalidationTargets(
            request: RFC_9110.Request,
            response: RFC_9110.Response
        ) -> [InvalidationTarget] {
            // RFC 9111 Section 4.4: "A cache MUST invalidate the target URI when it receives
            // a non-error status code in response to an unsafe request method"
            guard isUnsafeMethod(request.method) else {
                return []
            }

            // RFC 9111: Only invalidate on non-error responses
            guard !response.status.isClientError && !response.status.isServerError else {
                return []
            }

            var targets: [InvalidationTarget] = []

            // RFC 9111 Section 4.4: Always invalidate the request target URI
            targets.append(.requestTarget(uri: getRequestTargetURI(request)))

            // RFC 9111 Section 4.4: "A cache MAY invalidate the URI(s) in the Location
            // and Content-Location response header fields (if present) when the origin
            // of that URI is the same as the request URI"
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

        /// Check if method is unsafe and can trigger invalidation
        /// RFC 9111 Section 4.4: PUT, DELETE, POST
        private static func isUnsafeMethod(_ method: RFC_9110.Method) -> Bool {
            switch method {
            case .put, .delete, .post:
                return true
            default:
                return false
            }
        }

        /// Extract request target URI
        private static func getRequestTargetURI(_ request: RFC_9110.Request) -> String {
            switch request.target {
            case .origin(let path, let query):
                if let query = query {
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

        /// Extract Location header URI
        private static func getLocationURI(from response: RFC_9110.Response) -> String? {
            response.headers.first { $0.name.rawValue.lowercased() == "location" }?.value.rawValue
        }

        /// Extract Content-Location header URI
        private static func getContentLocationURI(from response: RFC_9110.Response) -> String? {
            response.headers.first { $0.name.rawValue.lowercased() == "content-location" }?.value
                .rawValue
        }

        /// Check if URI is same origin as request
        /// RFC 9111 Section 4.4: Only invalidate same-origin URIs
        private static func isSameOrigin(_ uriString: String, as request: RFC_9110.Request) -> Bool
        {
            // Parse the URI
            guard let uri = try? RFC_3986.URI(uriString) else {
                return false
            }

            // Extract request origin
            let requestScheme: RFC_3986.URI.Scheme?
            let requestHost: RFC_3986.URI.Host?
            let requestPort: RFC_3986.URI.Port?

            switch request.target {
            case .absolute(let requestURI):
                requestScheme = requestURI.scheme
                requestHost = requestURI.host
                requestPort = requestURI.port

            case .origin, .authority, .asterisk:
                // For origin-form, we'd need to get scheme/host/port from request headers
                // For simplicity, treat relative URIs as same-origin
                return true
            }

            // Compare origins
            guard let reqScheme = requestScheme, let reqHost = requestHost else {
                // Cannot determine origin, be conservative
                return false
            }

            // Scheme and host must match
            guard uri.scheme == reqScheme, uri.host == reqHost else {
                return false
            }

            // Port must match (or both be default for scheme)
            let uriPort = uri.port.map { Int($0.value) } ?? defaultPort(for: uri.scheme)
            let requestPortValue = requestPort.map { Int($0.value) } ?? defaultPort(for: reqScheme)

            return uriPort == requestPortValue
        }

        /// Get default port for scheme
        private static func defaultPort(for scheme: RFC_3986.URI.Scheme?) -> Int {
            guard let scheme = scheme else { return 80 }

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

        // MARK: - Invalidation Target

        /// Target URI for cache invalidation
        public enum InvalidationTarget: Sendable, Equatable {
            /// The request target URI (mandatory)
            case requestTarget(uri: String)

            /// Location header URI (optional, if same origin)
            case location(uri: String)

            /// Content-Location header URI (optional, if same origin)
            case contentLocation(uri: String)

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
    }
}
