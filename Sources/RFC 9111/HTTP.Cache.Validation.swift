// HTTP.Cache.Validation.swift
// swift-rfc-9111

extension RFC_9110.Cache {
    /// Cache validation implementing RFC 9111 Section 4.3
    public enum Validation {}
}

extension RFC_9110.Cache.Validation {

        // MARK: - Validation Request Generation

        /// Generate a conditional validation request for a stored response
        /// RFC 9111 Section 4.3.1: Sending a Validation Request
        ///
        /// - Parameters:
        ///   - storedResponse: The stored response to revalidate
        ///   - request: The original request (or synthesized request)
        /// - Returns: A conditional request with If-None-Match or If-Modified-Since headers
        public static func generateValidationRequest(
            for storedResponse: RFC_9110.Response,
            originalRequest: RFC_9110.Request
        ) -> RFC_9110.Request {
            var headers = Array(originalRequest.headers)

            // RFC 9111 Section 4.3.1: "A cache MUST use the entity tag in any
            // ETag field of the stored response to generate an If-None-Match header field"
            if let etag = getETag(from: storedResponse) {
                // Remove any existing If-None-Match headers
                headers.removeAll { $0.name.rawValue.lowercased() == "if-none-match" }

                // Add If-None-Match with the stored ETag
                if let field = try? RFC_9110.Header.Field(name: "If-None-Match", value: etag) {
                    headers.append(field)
                }
            }

            // RFC 9111 Section 4.3.1: "A cache MUST use the Last-Modified value of the
            // stored response to generate an If-Modified-Since header field"
            if let lastModified = getLastModified(from: storedResponse) {
                // Only add If-Modified-Since if we don't have ETag (ETag is preferred)
                if getETag(from: storedResponse) == nil {
                    // Remove any existing If-Modified-Since headers
                    headers.removeAll { $0.name.rawValue.lowercased() == "if-modified-since" }

                    // Add If-Modified-Since
                    if let field = try? RFC_9110.Header.Field(
                        name: "If-Modified-Since",
                        value: lastModified
                    ) {
                        headers.append(field)
                    }
                }
            }

            // Create new request with conditional headers
            return RFC_9110.Request(
                method: originalRequest.method,
                target: originalRequest.target,
                headers: RFC_9110.Headers(headers),
                body: originalRequest.body
            )
        }

        // MARK: - Validation Response Handling

        /// Process a validation response and update the stored response
        /// RFC 9111 Section 4.3.3: Handling a Received Validation Response
        ///
        /// - Parameters:
        ///   - validationResponse: The 304 Not Modified or full response
        ///   - storedResponse: The stored response being revalidated
        /// - Returns: Updated response result
        public static func processValidationResponse(
            _ validationResponse: RFC_9110.Response,
            storedResponse: RFC_9110.Response
        ) -> ValidationResult {
            // RFC 9111 Section 4.3.3: "If a cache receives a 304 (Not Modified) response,
            // the cache MUST update the stored response with the new header fields"
            if validationResponse.status.code == 304 {
                let updatedResponse = updateStoredResponse(storedResponse, with: validationResponse)
                return .notModified(updatedResponse: updatedResponse)
            }

            // RFC 9111 Section 4.3.3: "If the status code is anything other than 304,
            // the cache MUST use the full response"
            if validationResponse.status.isSuccessful {
                return .modified(newResponse: validationResponse)
            }

            // RFC 9111 Section 4.3.4: "If a cache receives a 5xx response while revalidating,
            // it MAY serve the stale response"
            if validationResponse.status.isServerError {
                return .serverError(canServeStale: true)
            }

            // For client errors, use the error response
            return .clientError(errorResponse: validationResponse)
        }

        /// Update stored response with headers from 304 Not Modified response
        /// RFC 9111 Section 4.3.3
        private static func updateStoredResponse(
            _ stored: RFC_9110.Response,
            with notModified: RFC_9110.Response
        ) -> RFC_9110.Response {
            var updatedHeaders = Array(stored.headers)

            // RFC 9111 Section 4.3.3: Update headers from 304 response
            // Remove headers that should be replaced
            for newHeader in notModified.headers {
                let headerName = newHeader.name.rawValue.lowercased()

                // Remove existing header with same name
                updatedHeaders.removeAll { $0.name.rawValue.lowercased() == headerName }

                // Add new header
                updatedHeaders.append(newHeader)
            }

            // Keep the stored response body
            return RFC_9110.Response(
                status: stored.status,  // Use original status, not 304
                headers: RFC_9110.Headers(updatedHeaders),
                body: stored.body
            )
        }

        // MARK: - Helper Methods

        /// Extract ETag from response
        private static func getETag(from response: RFC_9110.Response) -> String? {
            response.headers.first { $0.name.rawValue.lowercased() == "etag" }?.value.rawValue
        }

        /// Extract Last-Modified from response
        private static func getLastModified(from response: RFC_9110.Response) -> String? {
            response.headers.first { $0.name.rawValue.lowercased() == "last-modified" }?.value
                .rawValue
        }

        // MARK: - Result Types

        /// Result of validation response processing
        public enum ValidationResult: Sendable, Equatable {
            /// 304 Not Modified - stored response is still fresh
            case notModified(updatedResponse: RFC_9110.Response)

            /// Full response received - stored response has changed
            case modified(newResponse: RFC_9110.Response)

            /// 5xx server error during revalidation
            case serverError(canServeStale: Bool)

            /// Client error (4xx) response
            case clientError(errorResponse: RFC_9110.Response)
        }
}

extension RFC_9110.Cache.Validation.ValidationResult {
    /// Whether the stored response can still be used
    public var canUseStoredResponse: Bool {
        switch self {
        case .notModified, .serverError(canServeStale: true):
            return true
        case .modified, .clientError, .serverError(canServeStale: false):
            return false
        }
    }
}
