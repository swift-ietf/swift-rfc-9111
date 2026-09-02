import INCITS_4_1986
import RFC_9110
import RFC_9110_Coder
import Standard_Library_Extensions

extension RFC_9110 {

    public struct CacheControl: Sendable, Equatable, Hashable, Codable {

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

extension RFC_9110.CacheControl {

    public var headerValue: String {
        var directives: [String] = []

        if let maxAge {
            directives.append("max-age=\(maxAge)")
        }

        if let maxStale {
            if let seconds = maxStale {
                directives.append("max-stale=\(seconds)")
            } else {
                directives.append("max-stale")
            }
        }

        if let minFresh {
            directives.append("min-fresh=\(minFresh)")
        }

        if noCache {
            directives.append("no-cache")
        }

        if noStore {
            directives.append("no-store")
        }

        if noTransform {
            directives.append("no-transform")
        }

        if onlyIfCached {
            directives.append("only-if-cached")
        }

        if mustRevalidate {
            directives.append("must-revalidate")
        }

        if mustUnderstand {
            directives.append("must-understand")
        }

        if let `private` {
            if let fieldNames = `private`, !fieldNames.isEmpty {
                directives.append("private=\"\(fieldNames.joined(separator: ", "))\"")
            } else {
                directives.append("private")
            }
        }

        if proxyRevalidate {
            directives.append("proxy-revalidate")
        }

        if isPublic {
            directives.append("public")
        }

        if let sMaxage {
            directives.append("s-maxage=\(sMaxage)")
        }

        if immutable {
            directives.append("immutable")
        }

        if let staleWhileRevalidate {
            directives.append("stale-while-revalidate=\(staleWhileRevalidate)")
        }

        if let staleIfError {
            directives.append("stale-if-error=\(staleIfError)")
        }

        return directives.joined(separator: ", ")
    }

    public static func parse(_ headerValue: String) -> RFC_9110.CacheControl {
        var cacheControl = RFC_9110.CacheControl()

        for (name, value) in RFC_9110.Field.Value.directives(in: headerValue) {
            let name = name.lowercased()

            switch name {
            case "max-age":
                if let v = value, let seconds = Int(v) {
                    cacheControl.maxAge = seconds
                }

            case "max-stale":
                if let v = value, let seconds = Int(v) {
                    cacheControl.maxStale = .some(.some(seconds))
                } else {
                    cacheControl.maxStale = .some(nil)
                }

            case "min-fresh":
                if let v = value, let seconds = Int(v) {
                    cacheControl.minFresh = seconds
                }

            case "no-cache":
                cacheControl.noCache = true

            case "no-store":
                cacheControl.noStore = true

            case "no-transform":
                cacheControl.noTransform = true

            case "only-if-cached":
                cacheControl.onlyIfCached = true

            case "must-revalidate":
                cacheControl.mustRevalidate = true

            case "must-understand":
                cacheControl.mustUnderstand = true

            case "private":
                if let v = value {
                    let fieldNames = v.split(separator: ",")
                        .map { String($0).trimming(.ascii.whitespaces) }
                    cacheControl.private = .some(.some(fieldNames))
                } else {
                    cacheControl.private = .some(nil)
                }

            case "proxy-revalidate":
                cacheControl.proxyRevalidate = true

            case "public":
                cacheControl.isPublic = true

            case "s-maxage":
                if let v = value, let seconds = Int(v) {
                    cacheControl.sMaxage = seconds
                }

            case "immutable":
                cacheControl.immutable = true

            case "stale-while-revalidate":
                if let v = value, let seconds = Int(v) {
                    cacheControl.staleWhileRevalidate = seconds
                }

            case "stale-if-error":
                if let v = value, let seconds = Int(v) {
                    cacheControl.staleIfError = seconds
                }

            default:

                break
            }
        }

        return cacheControl
    }
}

extension RFC_9110.CacheControl: CustomStringConvertible {
    public var description: String {
        headerValue
    }
}
