public import RFC_5322
public import RFC_9110

extension RFC_9110.Cache {

    public enum Freshness {}
}

extension RFC_9110.Cache.Freshness {

    public static func lifetime(
        control: RFC_9110.Cache.Control?,
        expires: RFC_9110.Cache.Expires?,
        date: RFC_5322.DateTime?,
        lastModified: RFC_5322.DateTime? = nil,
        isSharedCache: Bool = false,
        allowHeuristics: Bool = false
    ) -> Double {

        if let control {
            if isSharedCache, let sMaxage = control.sMaxage {
                return Double(sMaxage)
            }

            if let maxAge = control.maxAge {
                return Double(maxAge)
            }
        }

        if let expires, let date {
            return max(0, expires.date.timeIntervalSince(date))
        }

        if allowHeuristics {
            return Self.heuristicLifetime(date: date, lastModified: lastModified)
        }

        return 0
    }

    public static func heuristicLifetime(
        date: RFC_5322.DateTime?,
        lastModified: RFC_5322.DateTime?
    ) -> Double {
        guard let date, let lastModified else {
            return 0
        }

        return min(date.timeIntervalSince(lastModified) * 0.1, 86400)
    }

    public static func age(
        carried: RFC_9110.Cache.Age?,
        date: RFC_5322.DateTime?,
        now: RFC_5322.DateTime,
        requestTime: RFC_5322.DateTime? = nil,
        responseTime: RFC_5322.DateTime? = nil
    ) -> Double {

        let carriedAge = carried.map { Double($0.seconds) } ?? 0

        guard let date else {
            return carriedAge
        }

        var apparentAge: Double = 0
        if let responseTime {
            apparentAge = max(0, responseTime.timeIntervalSince(date))
        }

        var responseDelay: Double = 0
        if let requestTime, let responseTime {
            responseDelay = responseTime.timeIntervalSince(requestTime)
        }

        let correctedInitialAge = max(apparentAge, carriedAge + responseDelay)

        var residentTime: Double = 0
        if let responseTime {
            residentTime = now.timeIntervalSince(responseTime)
        }

        return correctedInitialAge + residentTime
    }

    public static func isFresh(
        control: RFC_9110.Cache.Control?,
        expires: RFC_9110.Cache.Expires?,
        carried: RFC_9110.Cache.Age?,
        date: RFC_5322.DateTime?,
        lastModified: RFC_5322.DateTime? = nil,
        now: RFC_5322.DateTime,
        requestTime: RFC_5322.DateTime? = nil,
        responseTime: RFC_5322.DateTime? = nil,
        isSharedCache: Bool = false,
        allowHeuristics: Bool = false
    ) -> Bool {

        let elapsed = Self.age(
            carried: carried,
            date: date,
            now: now,
            requestTime: requestTime,
            responseTime: responseTime
        )

        let freshnessLifetime = Self.lifetime(
            control: control,
            expires: expires,
            date: date,
            lastModified: lastModified,
            isSharedCache: isSharedCache,
            allowHeuristics: allowHeuristics
        )

        return elapsed < freshnessLifetime
    }

    public static func staleDate(
        control: RFC_9110.Cache.Control?,
        expires: RFC_9110.Cache.Expires?,
        date: RFC_5322.DateTime?,
        lastModified: RFC_5322.DateTime? = nil,
        responseTime: RFC_5322.DateTime,
        isSharedCache: Bool = false,
        allowHeuristics: Bool = false
    ) -> RFC_5322.DateTime? {

        let freshnessLifetime = Self.lifetime(
            control: control,
            expires: expires,
            date: date,
            lastModified: lastModified,
            isSharedCache: isSharedCache,
            allowHeuristics: allowHeuristics
        )

        guard freshnessLifetime > 0 else {
            return nil
        }

        return responseTime.adding(freshnessLifetime)
    }
}
