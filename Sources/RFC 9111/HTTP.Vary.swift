import INCITS_4_1986
import RFC_9110
import Standard_Library_Extensions

extension RFC_9110 {

    public struct Vary: Sendable, Equatable, Hashable, Codable {

        public let fieldNames: [String]

        public let variesOnAllAspects: Bool

        public init(fieldNames: [String]) {
            self.fieldNames = fieldNames.map { $0.lowercased() }
            self.variesOnAllAspects = false
        }

        private init() {
            self.fieldNames = []
            self.variesOnAllAspects = true
        }
    }
}

extension RFC_9110.Vary {

    public static let all = RFC_9110.Vary()

    public var headerValue: String {
        if variesOnAllAspects {
            return "*"
        }
        return fieldNames.joined(separator: ", ")
    }

    public static func parse(_ headerValue: String) -> RFC_9110.Vary? {
        let trimmed = headerValue.trimming(.ascii.whitespaces)

        if trimmed == "*" {
            return .all
        }

        let names = RFC_9110.Parse.tokens(in: headerValue)

        guard !names.isEmpty else {
            return nil
        }

        return RFC_9110.Vary(fieldNames: names)
    }

    public func includes(_ fieldName: String) -> Bool {
        if variesOnAllAspects {
            return true
        }
        return fieldNames.contains(fieldName.lowercased())
    }

    public func matches(
        requestHeaders: [String: String],
        cachedRequestHeaders: [String: String]
    ) -> Bool {
        if variesOnAllAspects {
            return false
        }

        for fieldName in fieldNames {
            let requestValue = requestHeaders[fieldName]
            let cachedValue = cachedRequestHeaders[fieldName]

            if requestValue != cachedValue {
                return false
            }
        }

        return true
    }
}

extension RFC_9110.Vary: CustomStringConvertible {
    public var description: String {
        headerValue
    }
}

extension RFC_9110.Vary: LosslessStringConvertible {

    public init?(_ description: String) {
        guard let parsed = Self.parse(description) else { return nil }
        self = parsed
    }
}

extension RFC_9110.Vary: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: String...) {
        self.init(fieldNames: elements)
    }
}
