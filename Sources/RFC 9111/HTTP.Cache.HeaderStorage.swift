// HTTP.Cache.HeaderStorage.swift
// swift-rfc-9111

import INCITS_4_1986
import Standard_Library_Extensions

extension RFC_9110.Cache {
    /// Header storage rules implementing RFC 9111 Section 3
    public enum HeaderStorage {}
}

extension RFC_9110.Cache.HeaderStorage {

    // MARK: - Header Selection

    /// Determine which headers should be stored with a cached response
    /// RFC 9111 Section 3: Storing Partial Content
    ///
    /// - Parameter response: The response to cache
    /// - Returns: Headers that should be stored
    public static func headersToStore(
        from response: RFC_9110.Response
    ) -> [RFC_9110.Header.Field] {
        var headers = Array(response.headers)

        // RFC 9111 Section 3.2: Remove hop-by-hop headers
        headers = removeHopByHopHeaders(headers)

        // RFC 9111 Section 5.2: Warning header special handling
        headers = removeWarningsWith1xxCodes(headers)

        return headers
    }

    /// Remove hop-by-hop headers that must not be cached
    /// RFC 9110 Section 7.6.1: Connection-specific header fields
    private static func removeHopByHopHeaders(
        _ headers: [RFC_9110.Header.Field]
    ) -> [RFC_9110.Header.Field] {
        // RFC 9110 Section 7.6.1: Hop-by-hop headers
        let hopByHopHeaders = [
            "connection",
            "keep-alive",
            "proxy-authenticate",
            "proxy-authorization",
            "te",
            "trailer",
            "transfer-encoding",
            "upgrade",
        ]

        // Also check Connection header for additional hop-by-hop headers
        var additionalHopByHop: Set<String> = []
        for header in headers where header.name.rawValue.lowercased() == "connection" {
            let values = header.value.rawValue.split(separator: ",")
            for value in values {
                let trimmed = value.trimming(.ascii.whitespaces).lowercased()
                additionalHopByHop.insert(trimmed)
            }
        }

        return headers.filter { header in
            let headerName = header.name.rawValue.lowercased()
            return !hopByHopHeaders.contains(headerName)
                && !additionalHopByHop.contains(headerName)
        }
    }

    /// Remove Warning headers with 1xx warn-codes
    /// RFC 9111 Section 5.5: Warning
    private static func removeWarningsWith1xxCodes(
        _ headers: [RFC_9110.Header.Field]
    ) -> [RFC_9110.Header.Field] {
        // RFC 9111 Section 5.5: "A cache MUST delete any Warning header fields
        // that have a warn-code of 1xx"
        return headers.filter { header in
            guard header.name.rawValue.lowercased() == "warning" else {
                return true  // Keep non-Warning headers
            }

            // Parse warn-code (first token in Warning header)
            let value = header.value.rawValue
            let components = value.split(separator: " ", maxSplits: 1)
            guard let warnCodeStr = components.first,
                let warnCode = Int(warnCodeStr)
            else {
                return true  // Keep if can't parse
            }

            // Remove 1xx warn-codes
            return warnCode < 100 || warnCode >= 200
        }
    }

    // MARK: - Vary Header Handling

    /// Check if a stored response matches request based on Vary header
    /// RFC 9111 Section 4.1: Calculating Cache Keys with the Vary Header Field
    ///
    /// - Parameters:
    ///   - storedResponse: The cached response
    ///   - storedRequest: The request that generated the cached response
    ///   - currentRequest: The current incoming request
    /// - Returns: Whether the stored response matches the current request
    public static func matchesVary(
        storedResponse: RFC_9110.Response,
        storedRequest: RFC_9110.Request,
        currentRequest: RFC_9110.Request
    ) -> Bool {
        // Get Vary header from stored response
        guard
            let varyHeader = storedResponse.headers.first(where: {
                $0.name.rawValue.lowercased() == "vary"
            })
        else {
            // No Vary header - any request matches
            return true
        }

        let varyValue = varyHeader.value.rawValue

        // RFC 9111 Section 4.1: "Vary: *" means never match
        if varyValue.trimming(.ascii.whitespaces) == "*" {
            return false
        }

        // Parse Vary field names
        let varyFields = varyValue.split(separator: ",").map {
            $0.trimming(.ascii.whitespaces).lowercased()
        }

        // Check each varied field
        for fieldName in varyFields {
            let storedValues = getHeaderValues(fieldName, from: storedRequest)
            let currentValues = getHeaderValues(fieldName, from: currentRequest)

            // RFC 9111 Section 4.1: Header field values must match exactly
            if storedValues != currentValues {
                return false
            }
        }

        return true
    }

    /// Get all values for a header field name
    private static func getHeaderValues(
        _ name: String,
        from request: RFC_9110.Request
    ) -> [String] {
        let lowerName = name.lowercased()
        return request.headers
            .filter { $0.name.rawValue.lowercased() == lowerName }
            .map { $0.value.rawValue }
    }

    // MARK: - Header Updating

    /// Update stored response headers with headers from 304 Not Modified
    /// RFC 9111 Section 4.3.3: Handling a Received Validation Response
    ///
    /// - Parameters:
    ///   - storedHeaders: The currently stored headers
    ///   - notModifiedHeaders: Headers from 304 Not Modified response
    /// - Returns: Updated headers
    public static func updateHeaders(
        stored storedHeaders: [RFC_9110.Header.Field],
        with notModifiedHeaders: [RFC_9110.Header.Field]
    ) -> [RFC_9110.Header.Field] {
        var result = storedHeaders

        // RFC 9111 Section 4.3.3: "the cache MUST update its entry with
        // any new header fields in the 304 response"
        for newHeader in notModifiedHeaders {
            let headerName = newHeader.name.rawValue.lowercased()

            // Remove old header with same name
            result.removeAll { $0.name.rawValue.lowercased() == headerName }

            // Add new header
            result.append(newHeader)
        }

        return result
    }

    // MARK: - Age Calculation Support

    /// Check if Age header should be recalculated
    /// RFC 9111 Section 5.1: Age
    public static func shouldRecalculateAge(for response: RFC_9110.Response) -> Bool {
        // Age should be recalculated when serving from cache
        return response.headers.contains { $0.name.rawValue.lowercased() == "age" }
    }

    /// Update Age header in response
    /// RFC 9111 Section 5.1
    public static func updateAge(
        in headers: [RFC_9110.Header.Field],
        age: Double
    ) -> [RFC_9110.Header.Field] {
        var result = headers

        // Remove existing Age header
        result.removeAll { $0.name.rawValue.lowercased() == "age" }

        // Add updated Age header
        let ageSeconds = Int(age.rounded())
        do throws(RFC_9110.Header.Field.Error) {
            result.append(try RFC_9110.Header.Field(name: "Age", value: "\(ageSeconds)"))
        } catch {
            // A computed Age value that fails field-value validation cannot become a
            // header; omit the Age header rather than fail response processing.
        }

        return result
    }
}
