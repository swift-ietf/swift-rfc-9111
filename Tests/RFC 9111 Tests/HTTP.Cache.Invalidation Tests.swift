import RFC_3986
import RFC_9110
import RFC_9111
import Testing

@Suite
struct `HTTP.Cache.Invalidation Tests` {

    @Test
    func `A safe method invalidates nothing`() throws {
        let target = HTTP.Target.resource(try RFC_3986.URI("https://example.com/a"))

        #expect(
            HTTP.Cache.Invalidation.targets(method: .get, status: 200, target: target).isEmpty
        )
    }

    @Test
    func `An unsafe method invalidates its own target`() throws {
        let target = HTTP.Target.resource(try RFC_3986.URI("https://example.com/a"))

        let targets = HTTP.Cache.Invalidation.targets(
            method: .post,
            status: 200,
            target: target
        )

        #expect(targets == [.requestTarget(target)])
        #expect(targets.first?.isMandatory == true)
    }

    @Test
    func `A same-origin Location is invalidated too`() throws {
        let target = HTTP.Target.resource(try RFC_3986.URI("https://example.com/a"))
        let location = try RFC_3986.URI("https://example.com/b")

        let targets = HTTP.Cache.Invalidation.targets(
            method: .post,
            status: 201,
            target: target,
            location: location
        )

        #expect(targets == [.requestTarget(target), .location(location)])
    }

    @Test
    func `A cross-origin Location is left alone`() throws {
        let target = HTTP.Target.resource(try RFC_3986.URI("https://example.com/a"))
        let location = try RFC_3986.URI("https://elsewhere.example/b")

        #expect(
            HTTP.Cache.Invalidation.targets(
                method: .post,
                status: 201,
                target: target,
                location: location
            ) == [.requestTarget(target)]
        )
    }

    @Test
    func `A failed request invalidates nothing`() throws {
        let target = HTTP.Target.resource(try RFC_3986.URI("https://example.com/a"))

        #expect(
            HTTP.Cache.Invalidation.targets(method: .post, status: 404, target: target).isEmpty
        )
    }
}
