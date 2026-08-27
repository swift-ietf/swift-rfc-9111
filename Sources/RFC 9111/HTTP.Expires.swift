public import RFC_5322
public import RFC_9110

extension RFC_9110 {

    public struct Expires: Sendable, Equatable, Hashable, Codable {

        public let date: RFC_5322.DateTime

        public init(date: RFC_5322.DateTime) {
            self.date = date
        }
    }
}

extension RFC_9110.Expires {

    public var headerValue: String {
        RFC_9110.Field(dateTime: date).value.rawValue
    }

    public static func parse(_ headerValue: String) -> RFC_9110.Expires? {
        guard let date = RFC_5322.DateTime(RFC_9110.Field.Value(unchecked: headerValue))
        else {
            return nil
        }
        return RFC_9110.Expires(date: date)
    }

    public func isExpired(at now: RFC_5322.DateTime) -> Bool {
        date.secondsSinceEpoch < now.secondsSinceEpoch
    }

    public func timeRemaining(from now: RFC_5322.DateTime) -> Double {
        date.timeIntervalSince(now)
    }
}

extension RFC_9110.Expires: CustomStringConvertible {
    public var description: String {
        headerValue
    }
}

extension RFC_9110.Expires: LosslessStringConvertible {

    public init?(_ description: String) {
        guard let parsed = Self.parse(description) else { return nil }
        self = parsed
    }
}

extension RFC_9110.Expires: Comparable {
    public static func < (lhs: RFC_9110.Expires, rhs: RFC_9110.Expires) -> Bool {
        lhs.date.secondsSinceEpoch < rhs.date.secondsSinceEpoch
    }
}
