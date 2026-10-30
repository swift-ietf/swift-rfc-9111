#if Coder
    public import Byte
    public import Coder
    public import Cursor
    import Parser
    import RFC_5322
    public import RFC_9110
    import Serializer

    extension RFC_9110.Cache.Expires {

        public struct Coder<
            Input: Cursor.`Protocol`<Byte, Never>,
            Buffer: RangeReplaceableCollection<Byte>
        >: Coding {

            public typealias Output = RFC_9110.Cache.Expires

            public typealias Failure = RFC_9110.Cache.Expires.Error

            public init() {}

            public borrowing func parse(
                _ input: inout Input
            ) throws(Failure) -> RFC_9110.Cache.Expires {
                let text = Scanning.trimmed(Scanning.text(Scanning.line(&input)))

                guard !text.isEmpty else {
                    throw .empty
                }

                guard let date = RFC_5322.DateTime(RFC_9110.Field.Value(unchecked: text)) else {
                    throw .invalidDate(text)
                }

                return RFC_9110.Cache.Expires(date: date)
            }

            public borrowing func serialize(
                _ output: RFC_9110.Cache.Expires,
                into buffer: inout Buffer
            ) throws(Failure) {
                buffer.append(
                    contentsOf: Scanning.bytes(
                        RFC_9110.Field(dateTime: output.date).value.rawValue
                    )
                )
            }
        }

        public static var coder: Coder<ArraySlice<Byte>, [Byte]> { .init() }

        public enum Error: Swift::Error, Equatable {

            case empty

            case invalidDate(String)
        }
    }
#endif
