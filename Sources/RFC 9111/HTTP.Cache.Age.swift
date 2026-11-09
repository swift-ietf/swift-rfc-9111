public import Cardinal
public import RFC_9110

extension RFC_9110.Cache {

    public struct Age: Sendable, Equatable, Hashable {

        public let seconds: Cardinal

        public init(seconds: Cardinal) {
            self.seconds = seconds
        }
    }
}

extension RFC_9110.Cache.Age: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: UInt) {
        self.init(seconds: Cardinal(value))
    }
}

extension RFC_9110.Cache.Age: Comparable {
    public static func < (lhs: RFC_9110.Cache.Age, rhs: RFC_9110.Cache.Age) -> Bool {
        lhs.seconds < rhs.seconds
    }
}
