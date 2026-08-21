import INCITS_4_1986
import RFC_9110
import Standard_Library_Extensions

extension RFC_9110 {

    public struct Age: Sendable, Equatable, Hashable, Codable {

        public let seconds: Int

        public init(seconds: Int) {
            precondition(seconds >= 0, "Age must be non-negative")
            self.seconds = seconds
        }
    }
}

extension RFC_9110.Age {

    public var headerValue: String {
        String(seconds)
    }

    public static func parse(_ headerValue: String) -> RFC_9110.Age? {
        let trimmed = headerValue.trimming(.ascii.whitespaces)
        guard let seconds = Int(trimmed), seconds >= 0 else {
            return nil
        }
        return RFC_9110.Age(seconds: seconds)
    }
}

extension RFC_9110.Age: CustomStringConvertible {
    public var description: String {
        headerValue
    }
}

extension RFC_9110.Age: LosslessStringConvertible {

    public init?(_ description: String) {
        guard let parsed = Self.parse(description) else { return nil }
        self = parsed
    }
}

extension RFC_9110.Age: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) {
        self.init(seconds: value)
    }
}

extension RFC_9110.Age: Comparable {
    public static func < (lhs: RFC_9110.Age, rhs: RFC_9110.Age) -> Bool {
        lhs.seconds < rhs.seconds
    }
}
