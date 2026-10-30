#if Coder
    import Byte
    import Cursor

    enum Scanning {

        static func take<Input: Cursor.`Protocol`<Byte, Never>>(
            _ input: inout Input,
            while predicate: (Byte) -> Bool
        ) -> [Byte] {
            var bytes: [Byte] = []
            while true {
                let mark = input.checkpoint
                guard let byte = input.next(), predicate(byte) else {
                    input.seek(to: mark)
                    return bytes
                }
                bytes.append(byte)
            }
        }

        static func line<Input: Cursor.`Protocol`<Byte, Never>>(_ input: inout Input) -> [Byte] {
            take(&input) { $0.bitPattern != 0x0D && $0.bitPattern != 0x0A }
        }

        static func text(_ bytes: [Byte]) -> String {
            String(decoding: bytes, as: UTF8.self)
        }

        static func bytes(_ text: String) -> [Byte] {
            text.utf8.map(Byte.init(bitPattern:))
        }

        static func trimmed(_ text: String) -> String {
            var slice = Substring(text)
            while let first = slice.first, first == " " || first == "\t" {
                slice = slice.dropFirst()
            }
            while let last = slice.last, last == " " || last == "\t" {
                slice = slice.dropLast()
            }
            return String(slice)
        }
    }
#endif
