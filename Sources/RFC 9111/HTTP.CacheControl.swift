// HTTP.CacheControl.swift
// swift-rfc-9111
//
// RFC 9111 Section 5.2: Cache-Control
// https://www.rfc-editor.org/rfc/rfc9111.html#section-5.2
//
// Cache directives for request and response caching behavior

import RFC_9110

extension RFC_9110 {
    /// HTTP Cache-Control directives (RFC 9111 Section 5.2)
    ///
    /// The Cache-Control header field is used to specify directives for
    /// caching mechanisms in both requests and responses.
    ///
    /// ## Example Usage
    ///
    /// ```swift
    /// // Response caching
    /// var cacheControl = HTTP.CacheControl()
    /// cacheControl.maxAge = 3600
    /// cacheControl.isPublic = true
    /// print(cacheControl.headerValue)
    /// // "public, max-age=3600"
    ///
    /// // Request caching
    /// var requestCache = HTTP.CacheControl()
    /// requestCache.noCache = true
    /// requestCache.maxAge = 0
    /// // "no-cache, max-age=0"
    ///
    /// // Parsing
    /// let parsed = HTTP.CacheControl.parse("public, max-age=3600, must-revalidate")
    /// // parsed.isPublic == true
    /// // parsed.maxAge == 3600
    /// // parsed.mustRevalidate == true
    /// ```
    ///
    /// ## RFC 9111 Reference
    ///
    /// From RFC 9111 Section 5.2:
    /// ```
    /// Cache-Control   = #cache-directive
    /// cache-directive = token [ "=" ( token / quoted-string ) ]
    /// ```
    ///
    /// ## Reference
    ///
    /// - [RFC 9111 Section 5.2: Cache-Control](https://www.rfc-editor.org/rfc/rfc9111.html#section-5.2)
    public struct CacheControl: Sendable, Equatable, Hashable, Codable {
        // MARK: - Request Directives (RFC 9111 Section 5.2.1)

        /// max-age (request): Prefer response with age ≤ specified seconds
        public var maxAge: Int?

        /// max-stale (request): Accept responses exceeding freshness lifetime
        ///
        /// - nil: Not specified
        /// - .some(nil): Accept any stale response
        /// - .some(.some(seconds)): Accept responses stale by ≤ specified seconds
        public var maxStale: Int??

        /// min-fresh (request): Want response fresh for at least specified seconds
        public var minFresh: Int?

        /// no-cache: Require validation without using stored response
        public var noCache: Bool

        /// no-store: Prohibit caching of request or response
        public var noStore: Bool

        /// no-transform: Request intermediaries avoid content transformation
        public var noTransform: Bool

        /// only-if-cached (request): Only return stored responses or 504
        public var onlyIfCached: Bool

        // MARK: - Response Directives (RFC 9111 Section 5.2.2)

        /// must-revalidate: Cannot reuse stale response without origin validation
        public var mustRevalidate: Bool

        /// must-understand: Limits caching to compliant caches understanding status code
        public var mustUnderstand: Bool

        /// private: Response intended for single user only
        ///
        /// - nil: Not private
        /// - .some(nil): Entire response is private
        /// - .some(.some(fieldNames)): Only specified fields are private
        public var `private`: [String]??

        /// proxy-revalidate: Shared caches must revalidate when stale
        public var proxyRevalidate: Bool

        /// public: Response is cacheable despite normal restrictions
        public var isPublic: Bool

        /// s-maxage (response): Overrides max-age for shared caches
        public var sMaxage: Int?

        /// immutable: Response body will not change over time
        public var immutable: Bool

        /// stale-while-revalidate: Serve stale response while revalidating
        public var staleWhileRevalidate: Int?

        /// stale-if-error: Serve stale response if error occurs during revalidation
        public var staleIfError: Int?

        /// Creates an empty Cache-Control header
        public init() {
            self.maxAge = nil
            self.maxStale = nil
            self.minFresh = nil
            self.noCache = false
            self.noStore = false
            self.noTransform = false
            self.onlyIfCached = false
            self.mustRevalidate = false
            self.mustUnderstand = false
            self.private = nil
            self.proxyRevalidate = false
            self.isPublic = false
            self.sMaxage = nil
            self.immutable = false
            self.staleWhileRevalidate = nil
            self.staleIfError = nil
        }

        /// The header value representation
        ///
        /// - Returns: The Cache-Control value formatted for HTTP headers
        ///
        /// ## Example
        ///
        /// ```swift
        /// var cc = CacheControl()
        /// cc.maxAge = 3600
        /// cc.isPublic = true
        /// cc.headerValue // "public, max-age=3600"
        /// ```
        public var headerValue: String {
            var directives: [String] = []

            if let maxAge = maxAge {
                directives.append("max-age=\(maxAge)")
            }

            if let maxStale = maxStale {
                if let seconds = maxStale {
                    directives.append("max-stale=\(seconds)")
                } else {
                    directives.append("max-stale")
                }
            }

            if let minFresh = minFresh {
                directives.append("min-fresh=\(minFresh)")
            }

            if noCache {
                directives.append("no-cache")
            }

            if noStore {
                directives.append("no-store")
            }

            if noTransform {
                directives.append("no-transform")
            }

            if onlyIfCached {
                directives.append("only-if-cached")
            }

            if mustRevalidate {
                directives.append("must-revalidate")
            }

            if mustUnderstand {
                directives.append("must-understand")
            }

            if let `private` = `private` {
                if let fieldNames = `private`, !fieldNames.isEmpty {
                    directives.append("private=\"\(fieldNames.joined(separator: ", "))\"")
                } else {
                    directives.append("private")
                }
            }

            if proxyRevalidate {
                directives.append("proxy-revalidate")
            }

            if isPublic {
                directives.append("public")
            }

            if let sMaxage = sMaxage {
                directives.append("s-maxage=\(sMaxage)")
            }

            if immutable {
                directives.append("immutable")
            }

            if let staleWhileRevalidate = staleWhileRevalidate {
                directives.append("stale-while-revalidate=\(staleWhileRevalidate)")
            }

            if let staleIfError = staleIfError {
                directives.append("stale-if-error=\(staleIfError)")
            }

            return directives.joined(separator: ", ")
        }

        /// Parses a Cache-Control header value
        ///
        /// - Parameter headerValue: The Cache-Control header value to parse
        /// - Returns: A CacheControl with parsed directives
        ///
        /// ## Example
        ///
        /// ```swift
        /// let cc = CacheControl.parse("public, max-age=3600, must-revalidate")
        /// // cc.isPublic == true
        /// // cc.maxAge == 3600
        /// // cc.mustRevalidate == true
        /// ```
        public static func parse(_ headerValue: String) -> CacheControl {
            var cacheControl = CacheControl()

            let directives =
                headerValue
                .components(separatedBy: ",")
                .map { $0.trimming(.ascii.whitespaces) }

            for directive in directives {
                let parts = directive.components(separatedBy: "=")
                let name = parts[0].trimming(.ascii.whitespaces).lowercased()

                switch name {
                case "max-age":
                    if parts.count > 1, let value = Int(parts[1].trimming(.ascii.whitespaces)) {
                        cacheControl.maxAge = value
                    }

                case "max-stale":
                    if parts.count > 1, let value = Int(parts[1].trimming(.ascii.whitespaces)) {
                        cacheControl.maxStale = .some(.some(value))
                    } else {
                        cacheControl.maxStale = .some(nil)
                    }

                case "min-fresh":
                    if parts.count > 1, let value = Int(parts[1].trimming(.ascii.whitespaces)) {
                        cacheControl.minFresh = value
                    }

                case "no-cache":
                    cacheControl.noCache = true

                case "no-store":
                    cacheControl.noStore = true

                case "no-transform":
                    cacheControl.noTransform = true

                case "only-if-cached":
                    cacheControl.onlyIfCached = true

                case "must-revalidate":
                    cacheControl.mustRevalidate = true

                case "must-understand":
                    cacheControl.mustUnderstand = true

                case "private":
                    if parts.count > 1 {
                        var fieldValue = parts[1].trimming(.ascii.whitespaces)
                        if fieldValue.hasPrefix("\"") && fieldValue.hasSuffix("\"") {
                            fieldValue = String(fieldValue.dropFirst().dropLast())
                        }
                        let fieldNames = fieldValue
                            .components(separatedBy: ",")
                            .map { $0.trimming(.ascii.whitespaces) }
                        cacheControl.private = .some(.some(fieldNames))
                    } else {
                        cacheControl.private = .some(nil)
                    }

                case "proxy-revalidate":
                    cacheControl.proxyRevalidate = true

                case "public":
                    cacheControl.isPublic = true

                case "s-maxage":
                    if parts.count > 1, let value = Int(parts[1].trimming(.ascii.whitespaces)) {
                        cacheControl.sMaxage = value
                    }

                case "immutable":
                    cacheControl.immutable = true

                case "stale-while-revalidate":
                    if parts.count > 1, let value = Int(parts[1].trimming(.ascii.whitespaces)) {
                        cacheControl.staleWhileRevalidate = value
                    }

                case "stale-if-error":
                    if parts.count > 1, let value = Int(parts[1].trimming(.ascii.whitespaces)) {
                        cacheControl.staleIfError = value
                    }

                default:
                    // Unknown directive, ignore per RFC 9111 Section 5.2.3
                    break
                }
            }

            return cacheControl
        }
    }
}

// MARK: - CustomStringConvertible

extension RFC_9110.CacheControl: CustomStringConvertible {
    public var description: String {
        headerValue
    }
}
