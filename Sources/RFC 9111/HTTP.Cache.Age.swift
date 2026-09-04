public import RFC_9110

extension RFC_9110.Cache {

    public struct Age: Sendable, Equatable, Hashable {

        public let seconds: Int

        public init(seconds: Int) {
            precondition(seconds >= 0, "Age must be non-negative")
            self.seconds = seconds
        }
    }
}

extension RFC_9110.Cache.Age: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self.init(seconds: value)
    }
}

extension RFC_9110.Cache.Age: Comparable {
    public static func < (lhs: RFC_9110.Cache.Age, rhs: RFC_9110.Cache.Age) -> Bool {
        lhs.seconds < rhs.seconds
    }
}
