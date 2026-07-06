// HTTP.Freshness.swift
// swift-rfc-9111
//
// RFC 9111 Section 4.2: Freshness
// https://www.rfc-editor.org/rfc/rfc9111.html#section-4.2
//
// Freshness calculation utilities for determining if cached responses are fresh

public import RFC_5322
import RFC_9110

extension RFC_9110 {
    /// Freshness calculation utilities (RFC 9111 Section 4.2)
    ///
    /// A cached response is "fresh" if its age has not yet exceeded its freshness lifetime.
    /// This type provides utilities for calculating freshness per RFC 9111.
    ///
    /// ## Example Usage
    ///
    /// ```swift
    /// let response = HTTP.Response(
    ///     status: .ok,
    ///     headers: [
    ///         .init(name: "Cache-Control", value: "max-age=3600"),
    ///         .init(name: "Date", value: "Wed, 21 Oct 2015 07:28:00 GMT")
    ///     ]
    /// )
    ///
    /// let age = HTTP.Freshness.calculateAge(response: response)
    /// let lifetime = HTTP.Freshness.calculateFreshnessLifetime(response: response)
    /// let isFresh = age < lifetime
    /// ```
    ///
    /// ## Reference
    ///
    /// - [RFC 9111 Section 4.2: Freshness](https://www.rfc-editor.org/rfc/rfc9111.html#section-4.2)
    /// - [RFC 9111 Section 4.2.1: Freshness Lifetime](https://www.rfc-editor.org/rfc/rfc9111.html#section-4.2.1)
    /// - [RFC 9111 Section 4.2.3: Age Calculations](https://www.rfc-editor.org/rfc/rfc9111.html#section-4.2.3)
    public enum Freshness {
        /// Calculates the freshness lifetime of a response (RFC 9111 Section 4.2.1)
        ///
        /// The freshness lifetime is the length of time between the generation of a
        /// response and when it becomes stale.
        ///
        /// Priority order:
        /// 1. s-maxage directive (for shared caches)
        /// 2. max-age directive
        /// 3. Expires header
        /// 4. Heuristic freshness (if heuristics are allowed)
        ///
        /// - Parameters:
        ///   - response: The HTTP response
        ///   - isSharedCache: Whether this is a shared cache (affects s-maxage)
        ///   - allowHeuristics: Whether to use heuristic freshness
        /// - Returns: The freshness lifetime in seconds
        ///
        /// ## Example
        ///
        /// ```swift
        /// let response = HTTP.Response(
        ///     status: .ok,
        ///     headers: [.init(name: "Cache-Control", value: "max-age=3600")]
        /// )
        /// let lifetime = Freshness.calculateFreshnessLifetime(response: response)
        /// // lifetime == 3600
        /// ```
        public static func calculateFreshnessLifetime(
            response: RFC_9110.Response,
            isSharedCache: Bool = false,
            allowHeuristics: Bool = false
        ) -> Double {
            // Parse Cache-Control header
            if let ccHeader = response.headers["Cache-Control"]?.first?.rawValue {
                let cacheControl = CacheControl.parse(ccHeader)

                // s-maxage takes precedence for shared caches
                if isSharedCache, let sMaxage = cacheControl.sMaxage {
                    return Double(sMaxage)
                }

                // max-age takes precedence over Expires
                if let maxAge = cacheControl.maxAge {
                    return Double(maxAge)
                }
            }

            // Expires header
            if let expiresHeader = response.headers["Expires"]?.first?.rawValue,
                let expires = Expires.parse(expiresHeader),
                let dateHeader = response.headers["Date"]?.first?.rawValue,
                let date = RFC_5322.DateTime(RFC_9110.Header.Field.Value(unchecked: dateHeader)) {
                let lifetime = expires.date.timeIntervalSince(date)
                return max(0, lifetime)
            }

            // Heuristic freshness (RFC 9111 Section 4.2.2)
            if allowHeuristics {
                return calculateHeuristicFreshness(response: response)
            }

            return 0
        }

        /// Calculates heuristic freshness (RFC 9111 Section 4.2.2)
        ///
        /// When no explicit freshness information is available, caches MAY use
        /// heuristic freshness. A common heuristic is 10% of the time since
        /// Last-Modified.
        ///
        /// - Parameter response: The HTTP response
        /// - Returns: The heuristic freshness lifetime in seconds
        ///
        /// ## Example
        ///
        /// ```swift
        /// // Response modified 10 days ago
        /// // Heuristic: 10% of 10 days = 1 day fresh
        /// ```
        public static func calculateHeuristicFreshness(response: RFC_9110.Response) -> Double {
            guard let dateHeader = response.headers["Date"]?.first?.rawValue,
                let date = RFC_5322.DateTime(RFC_9110.Header.Field.Value(unchecked: dateHeader)),
                let lastModifiedHeader = response.headers["Last-Modified"]?.first?.rawValue,
                let lastModified = RFC_5322.DateTime(RFC_9110.Header.Field.Value(unchecked: lastModifiedHeader))
            else {
                return 0
            }

            let timeSinceModification = date.timeIntervalSince(lastModified)

            // Heuristic: 10% of time since last modification
            // Limited to 24 hours maximum per common practice
            return min(timeSinceModification * 0.1, 86400)
        }

        /// Calculates the current age of a response (RFC 9111 Section 4.2.3)
        ///
        /// The age is how long the response has been stored in the cache.
        ///
        /// - Parameters:
        ///   - response: The HTTP response
        ///   - now: The current time (defaults to Date())
        ///   - requestTime: When the request was initiated
        ///   - responseTime: When the response was received
        /// - Returns: The age in seconds
        ///
        /// ## Example
        ///
        /// ```swift
        /// let now = RFC_5322.DateTime(secondsSinceEpoch: Date().timeIntervalSince1970)
        /// let age = Freshness.calculateAge(
        ///     response: response,
        ///     requestTime: now.adding(-10),
        ///     responseTime: now.adding(-5)
        /// )
        /// ```
        public static func calculateAge(
            response: RFC_9110.Response,
            now: RFC_5322.DateTime,
            requestTime: RFC_5322.DateTime? = nil,
            responseTime: RFC_5322.DateTime? = nil
        ) -> Double {
            // Age from Age header
            var ageValue: Double = 0
            if let ageHeader = response.headers["Age"]?.first?.rawValue,
                let age = Age.parse(ageHeader) {
                ageValue = Double(age.seconds)
            }

            // Date header value
            guard let dateHeader = response.headers["Date"]?.first?.rawValue,
                let date = RFC_5322.DateTime(RFC_9110.Header.Field.Value(unchecked: dateHeader))
            else {
                return ageValue
            }

            // Apparent age = max(0, response_time - date_value)
            var apparentAge: Double = 0
            if let responseTime = responseTime {
                apparentAge = max(0, responseTime.timeIntervalSince(date))
            }

            // Response delay = response_time - request_time
            var responseDelay: Double = 0
            if let requestTime = requestTime, let responseTime = responseTime {
                responseDelay = responseTime.timeIntervalSince(requestTime)
            }

            // Corrected age_value = age_value + response_delay
            let correctedAgeValue = ageValue + responseDelay

            // Corrected initial age = max(apparent_age, corrected_age_value)
            let correctedInitialAge = max(apparentAge, correctedAgeValue)

            // Resident time = now - response_time
            var residentTime: Double = 0
            if let responseTime = responseTime {
                residentTime = now.timeIntervalSince(responseTime)
            }

            // Current age = corrected_initial_age + resident_time
            return correctedInitialAge + residentTime
        }

        /// Checks if a response is fresh (RFC 9111 Section 4.2)
        ///
        /// A response is fresh if its age has not exceeded its freshness lifetime.
        ///
        /// - Parameters:
        ///   - response: The HTTP response
        ///   - now: The current time (defaults to Date())
        ///   - requestTime: When the request was initiated
        ///   - responseTime: When the response was received
        ///   - isSharedCache: Whether this is a shared cache
        ///   - allowHeuristics: Whether to use heuristic freshness
        /// - Returns: True if the response is fresh
        ///
        /// ## Example
        ///
        /// ```swift
        /// if Freshness.isFresh(response: cachedResponse) {
        ///     // Can serve from cache
        /// } else {
        ///     // Must revalidate or fetch new response
        /// }
        /// ```
        public static func isFresh(
            response: RFC_9110.Response,
            now: RFC_5322.DateTime,
            requestTime: RFC_5322.DateTime? = nil,
            responseTime: RFC_5322.DateTime? = nil,
            isSharedCache: Bool = false,
            allowHeuristics: Bool = false
        ) -> Bool {
            let age = calculateAge(
                response: response,
                now: now,
                requestTime: requestTime,
                responseTime: responseTime
            )

            let lifetime = calculateFreshnessLifetime(
                response: response,
                isSharedCache: isSharedCache,
                allowHeuristics: allowHeuristics
            )

            return age < lifetime
        }

        /// Calculates when a response will become stale
        ///
        /// - Parameters:
        ///   - response: The HTTP response
        ///   - responseTime: When the response was received
        ///   - isSharedCache: Whether this is a shared cache
        ///   - allowHeuristics: Whether to use heuristic freshness
        /// - Returns: The date when the response becomes stale, or nil if already stale
        ///
        /// ## Example
        ///
        /// ```swift
        /// let now = RFC_5322.DateTime(secondsSinceEpoch: Date().timeIntervalSince1970)
        /// if let staleDate = Freshness.staleDate(response: response, responseTime: now) {
        ///     print("Response will be stale at: \(staleDate)")
        /// }
        /// ```
        public static func staleDate(
            response: RFC_9110.Response,
            responseTime: RFC_5322.DateTime,
            isSharedCache: Bool = false,
            allowHeuristics: Bool = false
        ) -> RFC_5322.DateTime? {
            let lifetime = calculateFreshnessLifetime(
                response: response,
                isSharedCache: isSharedCache,
                allowHeuristics: allowHeuristics
            )

            guard lifetime > 0 else {
                return nil
            }

            return responseTime.adding(lifetime)
        }
    }
}
