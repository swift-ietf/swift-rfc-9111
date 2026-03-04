// HTTP.Age.swift
// swift-rfc-9111
//
// RFC 9111 Section 5.1: Age
// https://www.rfc-editor.org/rfc/rfc9111.html#section-5.1
//
// The Age header field conveys the sender's estimate of the amount of time
// since the response was generated or validated

import ASCII
import RFC_9110
import Standard_Library_Extensions

extension RFC_9110 {
    /// HTTP Age header (RFC 9111 Section 5.1)
    ///
    /// The Age header field conveys the sender's estimate of the time since
    /// the response was generated or successfully validated at the origin server.
    ///
    /// ## Example Usage
    ///
    /// ```swift
    /// // Response is 120 seconds old
    /// let age = HTTP.Age(seconds: 120)
    /// print(age.headerValue) // "120"
    ///
    /// // Parsing
    /// let parsed = HTTP.Age.parse("120")
    /// // parsed?.seconds == 120
    /// ```
    ///
    /// ## RFC 9111 Reference
    ///
    /// From RFC 9111 Section 5.1:
    /// ```
    /// Age = delta-seconds
    /// ```
    ///
    /// The Age value is a non-negative integer representing time in seconds.
    ///
    /// ## Reference
    ///
    /// - [RFC 9111 Section 5.1: Age](https://www.rfc-editor.org/rfc/rfc9111.html#section-5.1)
    /// - [RFC 9111 Section 4.2.3: Calculating Age](https://www.rfc-editor.org/rfc/rfc9111.html#section-4.2.3)
    public struct Age: Sendable, Equatable, Hashable, Codable {
        /// The age in seconds
        ///
        /// A non-negative integer representing the time in seconds since
        /// the response was generated or validated at the origin.
        public let seconds: Int

        /// Creates an Age header value
        ///
        /// - Parameter seconds: The age in seconds (must be non-negative)
        public init(seconds: Int) {
            precondition(seconds >= 0, "Age must be non-negative")
            self.seconds = seconds
        }

        /// The header value representation
        ///
        /// - Returns: The Age value formatted for HTTP headers
        ///
        /// ## Example
        ///
        /// ```swift
        /// Age(seconds: 120).headerValue  // "120"
        /// ```
        public var headerValue: String {
            String(seconds)
        }

        /// Parses an Age header value
        ///
        /// - Parameter headerValue: The Age header value to parse
        /// - Returns: An Age if parsing succeeds, nil otherwise
        ///
        /// ## Example
        ///
        /// ```swift
        /// Age.parse("120")        // Age(seconds: 120)
        /// Age.parse("invalid")    // nil
        /// Age.parse("-5")         // nil (negative ages invalid)
        /// ```
        public static func parse(_ headerValue: String) -> Age? {
            let trimmed = headerValue.trimming(.ascii.whitespaces)
            guard let seconds = Int(trimmed), seconds >= 0 else {
                return nil
            }
            return Age(seconds: seconds)
        }
    }
}

// MARK: - CustomStringConvertible

extension RFC_9110.Age: CustomStringConvertible {
    public var description: String {
        headerValue
    }
}

// MARK: - LosslessStringConvertible

extension RFC_9110.Age: LosslessStringConvertible {
    /// Creates an Age from a string description
    ///
    /// - Parameter description: The Age string (e.g., "120")
    /// - Returns: An Age instance, or nil if parsing fails
    ///
    /// # Example
    ///
    /// ```swift
    /// let age = HTTP.Age("120")
    /// let str = String(age)  // "120" - perfect round-trip
    /// ```
    public init?(_ description: String) {
        guard let parsed = Self.parse(description) else { return nil }
        self = parsed
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension RFC_9110.Age: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self.init(seconds: value)
    }
}

// MARK: - Comparable

extension RFC_9110.Age: Comparable {
    public static func < (lhs: RFC_9110.Age, rhs: RFC_9110.Age) -> Bool {
        lhs.seconds < rhs.seconds
    }
}
