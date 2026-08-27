public import RFC_9110

extension RFC_9110.Cache {

    public enum Validation {}
}

extension RFC_9110.Cache.Validation {

    public static func generateValidationRequest<Stored, Content>(
        for storedResponse: RFC_9110.Message.Response<Stored>,
        originalRequest: RFC_9110.Message.Request<Content>
    ) -> RFC_9110.Message.Request<Content> {
        var headers = Array(originalRequest.headers)

        if let etag = getETag(from: storedResponse) {

            headers.removeAll { $0.name.rawValue.lowercased() == "if-none-match" }

            do throws(RFC_9110.Field.Error) {
                headers.append(try RFC_9110.Field(name: "If-None-Match", value: etag))
            } catch {

            }
        }

        if let lastModified = getLastModified(from: storedResponse) {

            if getETag(from: storedResponse) == nil {

                headers.removeAll { $0.name.rawValue.lowercased() == "if-modified-since" }

                do throws(RFC_9110.Field.Error) {
                    headers.append(
                        try RFC_9110.Field(
                            name: "If-Modified-Since",
                            value: lastModified
                        )
                    )
                } catch {

                }
            }
        }

        return RFC_9110.Message.Request(
            method: originalRequest.method,
            target: originalRequest.target,
            headers: RFC_9110.Message.Headers(headers),
            content: originalRequest.content,
            trailers: originalRequest.trailers
        )
    }

    public static func processValidationResponse<Content>(
        _ validationResponse: RFC_9110.Message.Response<Content>,
        storedResponse: RFC_9110.Message.Response<Content>
    ) -> Result<Content> {

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

    private static func updateStoredResponse<Content>(
        _ stored: RFC_9110.Message.Response<Content>,
        with notModified: RFC_9110.Message.Response<Content>
    ) -> RFC_9110.Message.Response<Content> {
        var updatedHeaders = Array(stored.headers)

        for newHeader in notModified.headers {
            let headerName = newHeader.name.rawValue.lowercased()

            updatedHeaders.removeAll { $0.name.rawValue.lowercased() == headerName }

            updatedHeaders.append(newHeader)
        }

        return RFC_9110.Message.Response(
            status: stored.status,
            reason: stored.reason,
            headers: RFC_9110.Message.Headers(updatedHeaders),
            content: stored.content,
            trailers: stored.trailers
        )
    }

    private static func getETag<Content>(
        from response: RFC_9110.Message.Response<Content>
    ) -> String? {
        response.headers.first { $0.name.rawValue.lowercased() == "etag" }?.value.rawValue
    }

    private static func getLastModified<Content>(
        from response: RFC_9110.Message.Response<Content>
    ) -> String? {
        response.headers.first { $0.name.rawValue.lowercased() == "last-modified" }?.value
            .rawValue
    }

    public enum Result<Content> {

        case notModified(updatedResponse: RFC_9110.Message.Response<Content>)

        case modified(newResponse: RFC_9110.Message.Response<Content>)

        case serverError(canServeStale: Bool)

        case clientError(errorResponse: RFC_9110.Message.Response<Content>)
    }
}

extension RFC_9110.Cache.Validation.Result: Equatable where Content: Equatable {}

extension RFC_9110.Cache.Validation.Result {

    public var canUseStoredResponse: Bool {
        switch self {
        case .notModified, .serverError(canServeStale: true):
            return true

        case .modified, .clientError, .serverError(canServeStale: false):
            return false
        }
    }
}
