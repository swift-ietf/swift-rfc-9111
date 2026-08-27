import INCITS_4_1986
public import RFC_9110
import Standard_Library_Extensions

extension RFC_9110.Cache {

    public enum HeaderStorage {}
}

extension RFC_9110.Cache.HeaderStorage {

    public static func headersToStore<Content>(
        from response: RFC_9110.Message.Response<Content>
    ) -> [RFC_9110.Field] {
        var headers = Array(response.headers)

        headers = removeHopByHopHeaders(headers)

        headers = removeWarningsWith1xxCodes(headers)

        return headers
    }

    private static func removeHopByHopHeaders(
        _ headers: [RFC_9110.Field]
    ) -> [RFC_9110.Field] {

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

    private static func removeWarningsWith1xxCodes(
        _ headers: [RFC_9110.Field]
    ) -> [RFC_9110.Field] {

        return headers.filter { header in
            guard header.name.rawValue.lowercased() == "warning" else {
                return true
            }

            let value = header.value.rawValue
            let components = value.split(separator: " ", maxSplits: 1)
            guard let warnCodeStr = components.first,
                let warnCode = Int(warnCodeStr)
            else {
                return true
            }

            return warnCode < 100 || warnCode >= 200
        }
    }

    public static func matchesVary<Stored, Original, Current>(
        storedResponse: RFC_9110.Message.Response<Stored>,
        storedRequest: RFC_9110.Message.Request<Original>,
        currentRequest: RFC_9110.Message.Request<Current>
    ) -> Bool {

        guard
            let varyHeader = storedResponse.headers.first(where: {
                $0.name.rawValue.lowercased() == "vary"
            })
        else {

            return true
        }

        let varyValue = varyHeader.value.rawValue

        if varyValue.trimming(.ascii.whitespaces) == "*" {
            return false
        }

        let varyFields = varyValue.split(separator: ",").map {
            $0.trimming(.ascii.whitespaces).lowercased()
        }

        for fieldName in varyFields {
            let storedValues = getHeaderValues(fieldName, from: storedRequest)
            let currentValues = getHeaderValues(fieldName, from: currentRequest)

            if storedValues != currentValues {
                return false
            }
        }

        return true
    }

    private static func getHeaderValues<Content>(
        _ name: String,
        from request: RFC_9110.Message.Request<Content>
    ) -> [String] {
        let lowerName = name.lowercased()
        return request.headers
            .filter { $0.name.rawValue.lowercased() == lowerName }
            .map { $0.value.rawValue }
    }

    public static func updateHeaders(
        stored storedHeaders: [RFC_9110.Field],
        with notModifiedHeaders: [RFC_9110.Field]
    ) -> [RFC_9110.Field] {
        var result = storedHeaders

        for newHeader in notModifiedHeaders {
            let headerName = newHeader.name.rawValue.lowercased()

            result.removeAll { $0.name.rawValue.lowercased() == headerName }

            result.append(newHeader)
        }

        return result
    }

    public static func shouldRecalculateAge<Content>(
        for response: RFC_9110.Message.Response<Content>
    ) -> Bool {

        return response.headers.contains { $0.name.rawValue.lowercased() == "age" }
    }

    public static func updateAge(
        in headers: [RFC_9110.Field],
        age: Double
    ) -> [RFC_9110.Field] {
        var result = headers

        result.removeAll { $0.name.rawValue.lowercased() == "age" }

        let ageSeconds = Int(age.rounded())
        do throws(RFC_9110.Field.Error) {
            result.append(try RFC_9110.Field(name: "Age", value: "\(ageSeconds)"))
        } catch {

        }

        return result
    }
}
