public import RFC_9110

extension RFC_9110.Cache {

    public enum Validation {}
}

extension RFC_9110.Cache.Validation {

    public static func request<Content>(
        for storedResponse: RFC_9110.Message.Response<Content>,
        from originalRequest: RFC_9110.Message.Request<Content>
    ) -> RFC_9110.Message.Request<Content> {

        var headers = originalRequest.headers

        let etag = storedResponse.headers[.etag].first
        let lastModified = storedResponse.headers[.lastModified].first

        if let etag {
            headers.remove(.ifNoneMatch)
            headers.append(RFC_9110.Field(name: .ifNoneMatch, value: etag))
        }

        if etag == nil, let lastModified {
            headers.remove(.ifModifiedSince)
            headers.append(RFC_9110.Field(name: .ifModifiedSince, value: lastModified))
        }

        return RFC_9110.Message.Request(
            method: originalRequest.method,
            target: originalRequest.target,
            headers: headers,
            content: originalRequest.content,
            trailers: originalRequest.trailers
        )
    }

    public static func outcome<Content>(
        of validationResponse: RFC_9110.Message.Response<Content>,
        storedResponse: RFC_9110.Message.Response<Content>
    ) -> Result<Content> {

        if validationResponse.status.code == 304 {
            return .notModified(
                updatedResponse: Self.updated(storedResponse, with: validationResponse)
            )
        }

        if validationResponse.status.isSuccessful {
            return .modified(newResponse: validationResponse)
        }

        if validationResponse.status.isServerError {
            return .serverError(canServeStale: true)
        }

        return .clientError(errorResponse: validationResponse)
    }

    private static func updated<Content>(
        _ stored: RFC_9110.Message.Response<Content>,
        with notModified: RFC_9110.Message.Response<Content>
    ) -> RFC_9110.Message.Response<Content> {

        var headers = stored.headers

        for field in notModified.headers {
            headers.remove(field.name)
            headers.append(field)
        }

        return RFC_9110.Message.Response(
            status: stored.status,
            reason: stored.reason,
            headers: headers,
            content: stored.content,
            trailers: stored.trailers
        )
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
