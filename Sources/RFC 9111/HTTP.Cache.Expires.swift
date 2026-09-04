public import RFC_5322
public import RFC_9110

extension RFC_9110.Cache {

    public struct Expires: Sendable, Equatable, Hashable {

        public let date: RFC_5322.DateTime

        public init(date: RFC_5322.DateTime) {
            self.date = date
        }
    }
}

extension RFC_9110.Cache.Expires {

    public func isExpired(at now: RFC_5322.DateTime) -> Bool {
        date.secondsSinceEpoch < now.secondsSinceEpoch
    }

    public func timeRemaining(from now: RFC_5322.DateTime) -> Double {
        date.timeIntervalSince(now)
    }
}

extension RFC_9110.Cache.Expires: Comparable {
    public static func < (lhs: RFC_9110.Cache.Expires, rhs: RFC_9110.Cache.Expires) -> Bool {
        lhs.date.secondsSinceEpoch < rhs.date.secondsSinceEpoch
    }
}
