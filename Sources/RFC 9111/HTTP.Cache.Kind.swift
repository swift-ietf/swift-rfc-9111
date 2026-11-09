public import RFC_9110

extension RFC_9110.Cache {

    public enum Kind: Sendable, Equatable, Hashable {

        case shared

        case `private`
    }
}
