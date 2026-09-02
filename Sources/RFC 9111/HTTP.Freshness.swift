public import RFC_5322
public import RFC_9110
import RFC_9110_Coder

extension RFC_9110 {

    public enum Freshness {}
}

extension RFC_9110.Freshness {

    public static func calculateFreshnessLifetime<Content>(
        response: RFC_9110.Message.Response<Content>,
        isSharedCache: Bool = false,
        allowHeuristics: Bool = false
    ) -> Double {

        if let ccHeader = response.headers[.cacheControl].first?.rawValue {
            let cacheControl = RFC_9110.CacheControl.parse(ccHeader)

            if isSharedCache, let sMaxage = cacheControl.sMaxage {
                return Double(sMaxage)
            }

            if let maxAge = cacheControl.maxAge {
                return Double(maxAge)
            }
        }

        if let expiresHeader = response.headers[.expires].first?.rawValue,
            let expires = RFC_9110.Expires.parse(expiresHeader),
            let dateHeader = response.headers[.date].first?.rawValue,
            let date = RFC_5322.DateTime(RFC_9110.Field.Value(unchecked: dateHeader))
        {
            let lifetime = expires.date.timeIntervalSince(date)
            return max(0, lifetime)
        }

        if allowHeuristics {
            return calculateHeuristicFreshness(response: response)
        }

        return 0
    }

    public static func calculateHeuristicFreshness<Content>(
        response: RFC_9110.Message.Response<Content>
    ) -> Double {
        guard let dateHeader = response.headers[.date].first?.rawValue,
            let date = RFC_5322.DateTime(RFC_9110.Field.Value(unchecked: dateHeader)),
            let lastModifiedHeader = response.headers[.lastModified].first?.rawValue,
            let lastModified = RFC_5322.DateTime(
                RFC_9110.Field.Value(unchecked: lastModifiedHeader)
            )
        else {
            return 0
        }

        let timeSinceModification = date.timeIntervalSince(lastModified)

        return min(timeSinceModification * 0.1, 86400)
    }

    public static func calculateAge<Content>(
        response: RFC_9110.Message.Response<Content>,
        now: RFC_5322.DateTime,
        requestTime: RFC_5322.DateTime? = nil,
        responseTime: RFC_5322.DateTime? = nil
    ) -> Double {

        var ageValue: Double = 0
        if let ageHeader = response.headers[.age].first?.rawValue,
            let age = RFC_9110.Age.parse(ageHeader)
        {
            ageValue = Double(age.seconds)
        }

        guard let dateHeader = response.headers[.date].first?.rawValue,
            let date = RFC_5322.DateTime(RFC_9110.Field.Value(unchecked: dateHeader))
        else {
            return ageValue
        }

        var apparentAge: Double = 0
        if let responseTime {
            apparentAge = max(0, responseTime.timeIntervalSince(date))
        }

        var responseDelay: Double = 0
        if let requestTime, let responseTime {
            responseDelay = responseTime.timeIntervalSince(requestTime)
        }

        let correctedAgeValue = ageValue + responseDelay

        let correctedInitialAge = max(apparentAge, correctedAgeValue)

        var residentTime: Double = 0
        if let responseTime {
            residentTime = now.timeIntervalSince(responseTime)
        }

        return correctedInitialAge + residentTime
    }

    public static func isFresh<Content>(
        response: RFC_9110.Message.Response<Content>,
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

    public static func staleDate<Content>(
        response: RFC_9110.Message.Response<Content>,
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
