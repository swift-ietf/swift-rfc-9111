public import RFC_9110

extension RFC_9110.Cache {

    public struct Control: Sendable, Equatable, Hashable {

        public var maxAge: Int?

        public var maxStale: Int??

        public var minFresh: Int?

        public var noCache: Bool

        public var noStore: Bool

        public var noTransform: Bool

        public var onlyIfCached: Bool

        public var mustRevalidate: Bool

        public var mustUnderstand: Bool

        public var `private`: [String]??

        public var proxyRevalidate: Bool

        public var isPublic: Bool

        public var sMaxage: Int?

        public var immutable: Bool

        public var staleWhileRevalidate: Int?

        public var staleIfError: Int?

        public init() {
            self.maxAge = nil
            self.maxStale = nil
            self.minFresh = nil
            self.noCache = false
            self.noStore = false
            self.noTransform = false
            self.onlyIfCached = false
            self.mustRevalidate = false
            self.mustUnderstand = false
            self.private = nil
            self.proxyRevalidate = false
            self.isPublic = false
            self.sMaxage = nil
            self.immutable = false
            self.staleWhileRevalidate = nil
            self.staleIfError = nil
        }
    }
}
