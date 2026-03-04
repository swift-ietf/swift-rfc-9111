// HTTP.Vary.swift
// swift-rfc-9111
//
// RFC 9111 Section 4.1: Calculating Cache Keys with the Vary Header Field
// https://www.rfc-editor.org/rfc/rfc9111.html#section-4.1
//
// The Vary header field describes which request headers were used to
// select among multiple representations

import ASCII
import RFC_9110
import Standard_Library_Extensions

extension RFC_9110 {
    /// HTTP Vary header (RFC 9111 Section 4.1)
    ///
    /// The Vary header field in a response describes which request header fields
    /// were used to select the representation. This is critical for caches to
    /// determine whether a stored response can be reused for a subsequent request.
    ///
    /// ## Example Usage
    ///
    /// ```swift
    /// // Vary by Accept-Encoding and Accept-Language
    /// let vary = HTTP.Vary(fieldNames: ["Accept-Encoding", "Accept-Language"])
    /// print(vary.headerValue)
    /// // "Accept-Encoding, Accept-Language"
    ///
    /// // Vary: * means response varies on aspects not covered by headers
    /// let varyAll = HTTP.Vary.all
    /// print(varyAll.headerValue) // "*"
    ///
    /// // Parsing
    /// let parsed = HTTP.Vary.parse("Accept-Encoding, User-Agent")
    /// // parsed?.fieldNames == ["Accept-Encoding", "User-Agent"]
    /// ```
    ///
    /// ## RFC 9111 Reference
    ///
    /// From RFC 9111 Section 4.1:
    /// ```
    /// Vary = #field-name / "*"
    /// ```
    ///
    /// A Vary field value of "*" indicates that the representation varies on
    /// aspects beyond those reflected in request header fields, such as the
    /// client's network address.
    ///
    /// ## Reference
    ///
    /// - [RFC 9111 Section 4.1: Vary](https://www.rfc-editor.org/rfc/rfc9111.html#section-4.1)
    public struct Vary: Sendable, Equatable, Hashable, Codable {
        /// The field names that affect the response
        ///
        /// Empty array with `variesOnAllAspects = true` represents "*"
        public let fieldNames: [String]

        /// Whether the response varies on aspects not expressible via header fields
        ///
        /// When true, this corresponds to "Vary: *"
        public let variesOnAllAspects: Bool

        /// Creates a Vary header value with specific field names
        ///
        /// - Parameter fieldNames: The header field names that affect the response
        public init(fieldNames: [String]) {
            self.fieldNames = fieldNames.map { $0.lowercased() }
            self.variesOnAllAspects = false
        }

        /// Creates a Vary: * header (varies on all aspects)
        private init() {
            self.fieldNames = []
            self.variesOnAllAspects = true
        }

        /// Vary: * - Response varies on aspects beyond request headers
        ///
        /// This indicates that the response depends on factors not reflected
        /// in request headers (e.g., client IP address, time of day).
        ///
        /// ## Example
        ///
        /// ```swift
        /// let vary = HTTP.Vary.all
        /// print(vary.headerValue) // "*"
        /// ```
        public static let all = Vary()

        /// The header value representation
        ///
        /// - Returns: The Vary value formatted for HTTP headers
        ///
        /// ## Example
        ///
        /// ```swift
        /// Vary(fieldNames: ["Accept", "Accept-Encoding"]).headerValue
        /// // "Accept, Accept-Encoding"
        ///
        /// Vary.all.headerValue
        /// // "*"
        /// ```
        public var headerValue: String {
            if variesOnAllAspects {
                return "*"
            }
            return fieldNames.joined(separator: ", ")
        }

        /// Parses a Vary header value
        ///
        /// - Parameter headerValue: The Vary header value to parse
        /// - Returns: A Vary if parsing succeeds, nil otherwise
        ///
        /// ## Example
        ///
        /// ```swift
        /// Vary.parse("Accept-Encoding, User-Agent")
        /// // Vary(fieldNames: ["accept-encoding", "user-agent"])
        ///
        /// Vary.parse("*")
        /// // Vary.all
        ///
        /// Vary.parse("")
        /// // nil
        /// ```
        public static func parse(_ headerValue: String) -> Vary? {
            let trimmed = headerValue.trimming(.ascii.whitespaces)

            if trimmed == "*" {
                return .all
            }

            let names = HTTP.Parse.tokens(in: headerValue)

            guard !names.isEmpty else {
                return nil
            }

            return Vary(fieldNames: names)
        }

        /// Returns true if the response varies on the specified header field
        ///
        /// - Parameter fieldName: The header field name to check
        /// - Returns: True if the response varies on this field
        ///
        /// ## Example
        ///
        /// ```swift
        /// let vary = Vary(fieldNames: ["Accept-Encoding", "User-Agent"])
        /// vary.includes("Accept-Encoding") // true
        /// vary.includes("accept-encoding") // true (case-insensitive)
        /// vary.includes("Cookie") // false
        ///
        /// Vary.all.includes("anything") // true (varies on everything)
        /// ```
        public func includes(_ fieldName: String) -> Bool {
            if variesOnAllAspects {
                return true
            }
            return fieldNames.contains(fieldName.lowercased())
        }

        /// Returns true if this response can match a request with the given headers
        ///
        /// - Parameters:
        ///   - requestHeaders: The headers from the new request
        ///   - cachedRequestHeaders: The headers from the cached request
        /// - Returns: True if the cached response matches the new request
        ///
        /// ## Example
        ///
        /// ```swift
        /// let vary = Vary(fieldNames: ["Accept-Encoding"])
        ///
        /// // Both requests have same Accept-Encoding
        /// vary.matches(
        ///     requestHeaders: ["Accept-Encoding": "gzip"],
        ///     cachedRequestHeaders: ["Accept-Encoding": "gzip"]
        /// ) // true
        ///
        /// // Different Accept-Encoding values
        /// vary.matches(
        ///     requestHeaders: ["Accept-Encoding": "br"],
        ///     cachedRequestHeaders: ["Accept-Encoding": "gzip"]
        /// ) // false
        /// ```
        public func matches(
            requestHeaders: [String: String],
            cachedRequestHeaders: [String: String]
        ) -> Bool {
            if variesOnAllAspects {
                return false  // Vary: * never matches
            }

            // Check that all varied fields match
            for fieldName in fieldNames {
                let requestValue = requestHeaders[fieldName]
                let cachedValue = cachedRequestHeaders[fieldName]

                if requestValue != cachedValue {
                    return false
                }
            }

            return true
        }
    }
}

// MARK: - CustomStringConvertible

extension RFC_9110.Vary: CustomStringConvertible {
    public var description: String {
        headerValue
    }
}

// MARK: - LosslessStringConvertible

extension RFC_9110.Vary: LosslessStringConvertible {
    /// Creates a Vary from a string description
    ///
    /// - Parameter description: The Vary string
    /// - Returns: A Vary instance, or nil if parsing fails
    ///
    /// # Example
    ///
    /// ```swift
    /// let vary = HTTP.Vary("Accept-Encoding, User-Agent")
    /// let str = String(vary)  // Round-trip
    /// ```
    public init?(_ description: String) {
        guard let parsed = Self.parse(description) else { return nil }
        self = parsed
    }
}

// MARK: - ExpressibleByArrayLiteral

extension RFC_9110.Vary: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: String...) {
        self.init(fieldNames: elements)
    }
}
