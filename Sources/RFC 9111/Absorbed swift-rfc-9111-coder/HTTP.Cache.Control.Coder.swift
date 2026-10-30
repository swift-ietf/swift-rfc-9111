#if Coder
    public import Byte
    public import Coder
    public import Cursor
    import Parser
    public import RFC_9110
    import Serializer

    extension RFC_9110.Cache.Control {

        public struct Coder<
            Input: Cursor.`Protocol`<Byte, Never>,
            Buffer: RangeReplaceableCollection<Byte>
        >: Coding {

            public typealias Output = RFC_9110.Cache.Control

            public typealias Failure = Never

            public init() {}

            public borrowing func parse(_ input: inout Input) -> RFC_9110.Cache.Control {
                RFC_9110.Cache.Control(
                    directives: RFC_9110.Field.Value.directives(
                        in: Scanning.text(Scanning.line(&input))
                    )
                )
            }

            public borrowing func serialize(
                _ output: RFC_9110.Cache.Control,
                into buffer: inout Buffer
            ) {
                buffer.append(contentsOf: Scanning.bytes(output.directives.joined(separator: ", ")))
            }
        }

        public static var coder: Coder<ArraySlice<Byte>, [Byte]> { .init() }
    }

    extension RFC_9110.Cache.Control {

        init(directives: [(name: String, value: String?)]) {
            self.init()

            for (name, value) in directives {
                switch name.lowercased() {
                case "max-age":
                    if let value, let seconds = Self.deltaSeconds(value) {
                        self.maxAge = seconds
                    }

                case "max-stale":
                    if let value, let seconds = Self.deltaSeconds(value) {
                        self.maxStale = .some(.some(seconds))
                    } else {
                        self.maxStale = .some(nil)
                    }

                case "min-fresh":
                    if let value, let seconds = Self.deltaSeconds(value) {
                        self.minFresh = seconds
                    }

                case "no-cache":
                    self.noCache = true

                case "no-store":
                    self.noStore = true

                case "no-transform":
                    self.noTransform = true

                case "only-if-cached":
                    self.onlyIfCached = true

                case "must-revalidate":
                    self.mustRevalidate = true

                case "must-understand":
                    self.mustUnderstand = true

                case "private":
                    if let value {
                        self.private = .some(
                            value.split(separator: ",").map {
                                Scanning.trimmed(String($0))
                            }
                        )
                    } else {
                        self.private = .some(nil)
                    }

                case "proxy-revalidate":
                    self.proxyRevalidate = true

                case "public":
                    self.isPublic = true

                case "s-maxage":
                    if let value, let seconds = Self.deltaSeconds(value) {
                        self.sMaxage = seconds
                    }

                case "immutable":
                    self.immutable = true

                case "stale-while-revalidate":
                    if let value, let seconds = Self.deltaSeconds(value) {
                        self.staleWhileRevalidate = seconds
                    }

                case "stale-if-error":
                    if let value, let seconds = Self.deltaSeconds(value) {
                        self.staleIfError = seconds
                    }

                default:
                    break
                }
            }
        }

        var directives: [String] {
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

            return directives
        }
    }

    extension RFC_9110.Cache.Control {

        fileprivate static func deltaSeconds(_ value: String) -> Int? {
            guard !value.isEmpty, value.utf8.allSatisfy({ (0x30...0x39).contains($0) }) else { return nil }
            return Int(value) ?? 2_147_483_648
        }
    }
#endif
