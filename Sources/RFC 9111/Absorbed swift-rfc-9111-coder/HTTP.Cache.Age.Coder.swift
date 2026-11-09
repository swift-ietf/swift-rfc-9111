#if Coder
    public import Byte
    import Cardinal
    public import Coder
    public import Cursor
    import Parser
    public import RFC_9110
    import Serializer

    extension RFC_9110.Cache.Age {

        public struct Coder<
            Input: Cursor.`Protocol`<Byte, Never>,
            Buffer: RangeReplaceableCollection<Byte>
        >: Coding {

            public typealias Output = RFC_9110.Cache.Age

            public typealias Failure = RFC_9110.Cache.Age.Error

            public init() {}

            public borrowing func parse(_ input: inout Input) throws(Failure) -> RFC_9110.Cache.Age {
                let digits = Scanning.take(&input) { (0x30...0x39).contains($0.bitPattern) }

                guard !digits.isEmpty else {
                    throw .empty
                }

                let text = Scanning.text(digits)

                return RFC_9110.Cache.Age(seconds: Cardinal(UInt(text) ?? 2_147_483_648))
            }

            public borrowing func serialize(
                _ output: RFC_9110.Cache.Age,
                into buffer: inout Buffer
            ) throws(Failure) {
                buffer.append(contentsOf: Scanning.bytes(String(output.seconds.rawValue)))
            }
        }

        public static var coder: Coder<ArraySlice<Byte>, [Byte]> { .init() }

        public enum Error: Swift::Error, Equatable {

            case empty

            case overflow(String)
        }
    }
#endif
