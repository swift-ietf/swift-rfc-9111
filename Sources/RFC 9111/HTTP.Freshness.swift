public import RFC_5322
import RFC_9110

extension RFC_9110 {

    public enum Freshness {}
}

extension RFC_9110.Freshness {

    public static func calculateFreshnessLifetime(
        response: RFC_9110.Response,
        isSharedCache: Bool = false,
        allowHeuristics: Bool = false
    ) -> Double {

        if let ccHeader = response.headers["Cache-Control"]?.first?.rawValue {
            let cacheControl = RFC_9110.CacheControl.parse(ccHeader)

            if isSharedCache, let sMaxage = cacheControl.sMaxage {
                return Double(sMaxage)
            }

            if let maxAge = cacheControl.maxAge {
                return Double(maxAge)
            }
        }

        if let expiresHeader = response.headers["Expires"]?.first?.rawValue,
            let expires = RFC_9110.Expires.parse(expiresHeader),
            let dateHeader = response.headers["Date"]?.first?.rawValue,
            let date = RFC_5322.DateTime(RFC_9110.Header.Field.Value(unchecked: dateHeader))
        {
            let lifetime = expires.date.timeIntervalSince(date)
            return max(0, lifetime)
        }

        if allowHeuristics {
            return calculateHeuristicFreshness(response: response)
        }

        return 0
    }

    public static func calculateHeuristicFreshness(response: RFC_9110.Response) -> Double {
        guard let dateHeader = response.headers["Date"]?.first?.rawValue,
            let date = RFC_5322.DateTime(RFC_9110.Header.Field.Value(unchecked: dateHeader)),
            let lastModifiedHeader = response.headers["Last-Modified"]?.first?.rawValue,
            let lastModified = RFC_5322.DateTime(
                RFC_9110.Header.Field.Value(unchecked: lastModifiedHeader)
            )
        else {
            return 0
        }

        let timeSinceModification = date.timeIntervalSince(lastModified)

        return min(timeSinceModification * 0.1, 86400)
    }

    public static func calculateAge(
        response: RFC_9110.Response,
        now: RFC_5322.DateTime,
        requestTime: RFC_5322.DateTime? = nil,
        responseTime: RFC_5322.DateTime? = nil
    ) -> Double {

        var ageValue: Double = 0
        if let ageHeader = response.headers["Age"]?.first?.rawValue,
            let age = RFC_9110.Age.parse(ageHeader)
        {
            ageValue = Double(age.seconds)
        }

        guard let dateHeader = response.headers["Date"]?.first?.rawValue,
            let date = RFC_5322.DateTime(RFC_9110.Header.Field.Value(unchecked: dateHeader))
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
