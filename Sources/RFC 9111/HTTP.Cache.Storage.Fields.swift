public import RFC_9110

extension RFC_9110.Cache.Storage {

    public enum Fields {}
}

extension RFC_9110.Cache.Storage.Fields {

    public static var hopByHop: [RFC_9110.Field.Name] {
        [
            .connection,
            .keepAlive,
            .proxyAuthenticate,
            .proxyAuthorization,
            .te,
            .trailer,
            .transferEncoding,
            .upgrade,
        ]
    }

    public static func headersToStore(
        from headers: RFC_9110.Message.Headers,
        connectionOptions: [RFC_9110.Field.Name] = []
    ) -> RFC_9110.Message.Headers {

        RFC_9110.Message.Headers(
            headers.filter { field in
                !Self.hopByHop.contains(field.name)
                    && !connectionOptions.contains(field.name)
            }
        )
    }

    public static func matchesVary(
        _ vary: RFC_9110.Negotiation.Vary?,
        stored: RFC_9110.Message.Headers,
        current: RFC_9110.Message.Headers
    ) -> Bool {

        guard let vary else {
            return true
        }

        if vary.variesOnAllAspects {
            return false
        }

        for fieldName in vary.fieldNames {
            let name: RFC_9110.Field.Name
            do throws(RFC_9110.Field.Name.Error) {
                name = try RFC_9110.Field.Name(fieldName)
            } catch {
                return false
            }

            if stored[name] != current[name] {
                return false
            }
        }

        return true
    }

    public static func updateHeaders(
        stored: RFC_9110.Message.Headers,
        with notModified: RFC_9110.Message.Headers
    ) -> RFC_9110.Message.Headers {
        var result = stored

        for field in notModified {
            result.remove(field.name)
            result.append(field)
        }

        return result
    }

    public static func shouldRecalculateAge(
        in headers: RFC_9110.Message.Headers
    ) -> Bool {
        !headers[.age].isEmpty
    }

    public static func updateAge(
        in headers: RFC_9110.Message.Headers,
        to age: RFC_9110.Cache.Age
    ) -> RFC_9110.Message.Headers {
        var result = headers

        result.remove(.age)
        result.append(
            RFC_9110.Field(name: .age, value: .init(unchecked: String(age.seconds)))
        )

        return result
    }
}
