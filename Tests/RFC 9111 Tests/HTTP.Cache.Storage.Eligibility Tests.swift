import RFC_9110
import RFC_9111
import Testing

@Suite
struct `HTTP.Cache.Storage.Eligibility Tests` {

    @Test
    func `A cacheable status with max-age is storable`() {
        var control = HTTP.Cache.Control()
        control.maxAge = 3600

        #expect(
            HTTP.Cache.Storage.Eligibility.isStorable(
                method: .get,
                status: 200,
                control: control
            ) == .eligible
        )
    }

    @Test
    func `An unknown method is not storable`() {
        let result = HTTP.Cache.Storage.Eligibility.isStorable(
            method: .put,
            status: 200,
            control: nil
        )

        #expect(result == .ineligible(reason: .methodNotUnderstood(.put)))
        #expect(!result.isEligible)
    }

    @Test
    func `no-store refuses storage`() {
        var control = HTTP.Cache.Control()
        control.noStore = true

        #expect(
            HTTP.Cache.Storage.Eligibility.isStorable(
                method: .get,
                status: 200,
                control: control
            ) == .ineligible(reason: .noStoreDirective)
        )
    }

    @Test
    func `A private response is refused by a shared cache`() {
        var control = HTTP.Cache.Control()
        control.private = .some(nil)

        #expect(
            HTTP.Cache.Storage.Eligibility.isStorable(
                method: .get,
                status: 200,
                control: control,
                isSharedCache: true
            ) == .ineligible(reason: .privateDirectiveInSharedCache)
        )

        #expect(
            HTTP.Cache.Storage.Eligibility.isStorable(
                method: .get,
                status: 200,
                control: control,
                isSharedCache: false
            ) == .eligible
        )
    }

    @Test
    func `An authorized request needs explicit sharing permission`() {
        #expect(
            HTTP.Cache.Storage.Eligibility.isStorable(
                method: .get,
                status: 200,
                control: nil,
                isAuthorized: true,
                isSharedCache: true
            ) == .ineligible(reason: .authorizedRequestWithoutSharingPermission)
        )
    }

    @Test
    func `A status without a cacheability indicator is refused`() {
        #expect(
            HTTP.Cache.Storage.Eligibility.isStorable(
                method: .get,
                status: 418,
                control: nil
            ) == .ineligible(reason: .noCacheabilityIndicator)
        )
    }

    @Test
    func `An Expires field is a cacheability indicator`() {
        #expect(
            HTTP.Cache.Storage.Eligibility.isStorable(
                method: .get,
                status: 418,
                control: nil,
                hasExpires: true
            ) == .eligible
        )
    }
}
