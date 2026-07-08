// HTTP.Expires.swift
// swift-rfc-9111
//
// RFC 9111 Section 5.3: Expires
// https://www.rfc-editor.org/rfc/rfc9111.html#section-5.3
//
// The Expires header field gives the date/time after which the response
// is considered stale

public import RFC_5322
import RFC_9110

extension RFC_9110 {
    /// HTTP Expires header (RFC 9111 Section 5.3)
    ///
    /// The Expires header field gives the date/time after which the response
    /// is considered stale. A cache recipient must not serve a stored response
    /// with an Expires date in the past without validation.
    ///
    /// ## Example Usage
    ///
    /// ```swift
    /// // Response expires in 1 hour
    /// let now = RFC_5322.DateTime(secondsSinceEpoch: 1445412480)
    /// let expirationDate = now.adding(3600)
    /// let expires = HTTP.Expires(date: expirationDate)
    /// print(expires.headerValue)
    /// // "Wed, 21 Oct 2015 07:28:00 GMT"
    ///
    /// // Parsing
    /// let parsed = HTTP.Expires.parse("Wed, 21 Oct 2015 07:28:00 GMT")
    /// // parsed?.date
    /// ```
    ///
    /// ## RFC 9111 Reference
    ///
    /// From RFC 9111 Section 5.3:
    /// ```
    /// Expires = HTTP-date
    /// ```
    ///
    /// An invalid date (e.g., a date that cannot be parsed) should be
    /// treated as representing a time in the past (i.e., already expired).
    ///
    /// ## Interaction with Cache-Control
    ///
    /// If a response includes both Expires and Cache-Control max-age,
    /// the max-age directive takes precedence.
    ///
    /// ## Reference
    ///
    /// - [RFC 9111 Section 5.3: Expires](https://www.rfc-editor.org/rfc/rfc9111.html#section-5.3)
    /// - [RFC 9111 Section 4.2: Freshness](https://www.rfc-editor.org/rfc/rfc9111.html#section-4.2)
    public struct Expires: Sendable, Equatable, Hashable, Codable {
        /// The expiration date
        ///
        /// The date/time after which the response is considered stale.
        public let date: RFC_5322.DateTime

        /// Creates an Expires header value
        ///
        /// - Parameter date: The expiration date
        public init(date: RFC_5322.DateTime) {
            self.date = date
        }
    }
}

extension RFC_9110.Expires {
        /// The header value representation (IMF-fixdate format)
        ///
        /// - Returns: The Expires value formatted for HTTP headers
        ///
        /// ## Example
        ///
        /// ```swift
        /// let date = RFC_5322.DateTime(secondsSinceEpoch: 1445412480)
        /// Expires(date: date).headerValue
        /// // "Wed, 21 Oct 2015 07:28:00 GMT"
        /// ```
        public var headerValue: String {
            RFC_9110.Header.Field(dateTime: date).value.rawValue
        }

        /// Parses an Expires header value
        ///
        /// - Parameter headerValue: The Expires header value to parse
        /// - Returns: An Expires if parsing succeeds, nil otherwise
        ///
        /// ## Example
        ///
        /// ```swift
        /// Expires.parse("Wed, 21 Oct 2015 07:28:00 GMT")
        /// // Expires(date: ...)
        ///
        /// Expires.parse("invalid")
        /// // nil
        /// ```
        public static func parse(_ headerValue: String) -> RFC_9110.Expires? {
            guard let date = RFC_5322.DateTime(RFC_9110.Header.Field.Value(unchecked: headerValue))
            else {
                return nil
            }
            return RFC_9110.Expires(date: date)
        }

        /// Returns true if this expiration date is in the past
        ///
        /// - Parameter now: The current date
        /// - Returns: True if the response has expired
        ///
        /// ## Example
        ///
        /// ```swift
        /// let now = RFC_5322.DateTime(secondsSinceEpoch: 1445412480)
        /// let expires = Expires(date: now.adding(-3600))
        /// expires.isExpired(at: now) // true (1 hour ago)
        ///
        /// let future = Expires(date: now.adding(3600))
        /// future.isExpired(at: now) // false (1 hour from now)
        /// ```
        public func isExpired(at now: RFC_5322.DateTime) -> Bool {
            date.secondsSinceEpoch < now.secondsSinceEpoch
        }

        /// Returns the time remaining until expiration
        ///
        /// - Parameter now: The current date
        /// - Returns: Seconds until expiration (negative if already expired)
        ///
        /// ## Example
        ///
        /// ```swift
        /// let now = RFC_5322.DateTime(secondsSinceEpoch: 1445412480)
        /// let expires = Expires(date: now.adding(3600))
        /// expires.timeRemaining(from: now) // 3600 seconds
        /// ```
        public func timeRemaining(from now: RFC_5322.DateTime) -> Double {
            date.timeIntervalSince(now)
        }
}

// MARK: - CustomStringConvertible

extension RFC_9110.Expires: CustomStringConvertible {
    public var description: String {
        headerValue
    }
}

// MARK: - LosslessStringConvertible

extension RFC_9110.Expires: LosslessStringConvertible {
    /// Creates an Expires from a string description
    ///
    /// - Parameter description: The Expires string (HTTP-date format)
    /// - Returns: An Expires instance, or nil if parsing fails
    ///
    /// # Example
    ///
    /// ```swift
    /// let expires = HTTP.Expires("Wed, 21 Oct 2015 07:28:00 GMT")
    /// let str = String(expires)  // Round-trip
    /// ```
    public init?(_ description: String) {
        guard let parsed = Self.parse(description) else { return nil }
        self = parsed
    }
}

// MARK: - Comparable

extension RFC_9110.Expires: Comparable {
    public static func < (lhs: RFC_9110.Expires, rhs: RFC_9110.Expires) -> Bool {
        lhs.date.secondsSinceEpoch < rhs.date.secondsSinceEpoch
    }
}
