extension RFC_9110.Cache {

    public enum Validation {}
}

extension RFC_9110.Cache.Validation {

    public static func generateValidationRequest(
        for storedResponse: RFC_9110.Response,
        originalRequest: RFC_9110.Request
    ) -> RFC_9110.Request {
        var headers = Array(originalRequest.headers)

        if let etag = getETag(from: storedResponse) {

            headers.removeAll { $0.name.rawValue.lowercased() == "if-none-match" }

            do throws(RFC_9110.Header.Field.Error) {
                headers.append(try RFC_9110.Header.Field(name: "If-None-Match", value: etag))
            } catch {

            }
        }

        if let lastModified = getLastModified(from: storedResponse) {

            if getETag(from: storedResponse) == nil {

                headers.removeAll { $0.name.rawValue.lowercased() == "if-modified-since" }

                do throws(RFC_9110.Header.Field.Error) {
                    headers.append(
                        try RFC_9110.Header.Field(
                            name: "If-Modified-Since",
                            value: lastModified
                        )
                    )
                } catch {

                }
            }
        }

        return RFC_9110.Request(
            method: originalRequest.method,
            target: originalRequest.target,
            headers: RFC_9110.Headers(headers),
            body: originalRequest.body
        )
    }

    public static func processValidationResponse(
        _ validationResponse: RFC_9110.Response,
        storedResponse: RFC_9110.Response
    ) -> ValidationResult {

        if validationResponse.status.code == 304 {
            let updatedResponse = updateStoredResponse(storedResponse, with: validationResponse)
            return .notModified(updatedResponse: updatedResponse)
        }

        if validationResponse.status.isSuccessful {
            return .modified(newResponse: validationResponse)
        }

        if validationResponse.status.isServerError {
            return .serverError(canServeStale: true)
        }

        return .clientError(errorResponse: validationResponse)
    }

    private static func updateStoredResponse(
        _ stored: RFC_9110.Response,
        with notModified: RFC_9110.Response
    ) -> RFC_9110.Response {
        var updatedHeaders = Array(stored.headers)

        for newHeader in notModified.headers {
            let headerName = newHeader.name.rawValue.lowercased()

            updatedHeaders.removeAll { $0.name.rawValue.lowercased() == headerName }

            updatedHeaders.append(newHeader)
        }

        return RFC_9110.Response(
            status: stored.status,
            headers: RFC_9110.Headers(updatedHeaders),
            body: stored.body
        )
    }

    private static func getETag(from response: RFC_9110.Response) -> String? {
        response.headers.first { $0.name.rawValue.lowercased() == "etag" }?.value.rawValue
    }

    private static func getLastModified(from response: RFC_9110.Response) -> String? {
        response.headers.first { $0.name.rawValue.lowercased() == "last-modified" }?.value
            .rawValue
    }

    public enum ValidationResult: Sendable, Equatable {

        case notModified(updatedResponse: RFC_9110.Response)

        case modified(newResponse: RFC_9110.Response)

        case serverError(canServeStale: Bool)

        case clientError(errorResponse: RFC_9110.Response)
    }
}

extension RFC_9110.Cache.Validation.ValidationResult {

    public var canUseStoredResponse: Bool {
        switch self {
        case .notModified, .serverError(canServeStale: true):
            return true

        case .modified, .clientError, .serverError(canServeStale: false):
            return false
        }
    }
}
