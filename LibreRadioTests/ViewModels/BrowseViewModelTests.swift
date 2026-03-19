import XCTest
@testable import LibreRadio

@MainActor
final class BrowseViewModelTests: XCTestCase {

    private var discovery: ServerDiscoveryService!
    private var service: RadioBrowserService!
    private var suiteName: String!
    private var cache: StationCacheService!

    override func setUp() async throws {
        discovery = ServerDiscoveryService()
        await discovery.setServers(["mock.api.radio-browser.info"])

        let session = TestFixtures.makeMockSession()
        service = RadioBrowserService(discovery: discovery, session: session)

        suiteName = "test.browse.\(UUID().uuidString)"
        let testDefaults = UserDefaults(suiteName: suiteName)!
        cache = StationCacheService(defaults: testDefaults)
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        if let suiteName = suiteName {
            UserDefaults.standard.removePersistentDomain(forName: suiteName)
        }
    }

    // MARK: - Countries

    func testLoadCountriesSuccess() async {
        let json = """
        [
            {"name": "The United States Of America", "iso_3166_1": "US", "stationcount": 1000},
            {"name": "Argentina", "iso_3166_1": "AR", "stationcount": 500},
            {"name": "France", "iso_3166_1": "FR", "stationcount": 300},
            {"name": "Netherlands", "iso_3166_1": "NL", "stationcount": 400}
        ]
        """
        setMockResponse(json: json)

        let vm = BrowseViewModel(service: service, cache: cache)
        await vm.loadCountries()

        XCTAssertEqual(vm.countries.count, 4)
        // Raw data is stored in API order (unsorted)
        let names = Set(vm.countries.map(\.displayName))
        XCTAssertTrue(names.contains("France"))
        XCTAssertTrue(names.contains("Argentina"))
        XCTAssertTrue(names.contains("United States"))
        XCTAssertTrue(names.contains("Netherlands"))
        XCTAssertFalse(vm.isLoadingCountries)
        XCTAssertNil(vm.countriesError)
    }

    func testLoadCountriesError() async {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let vm = BrowseViewModel(service: service, cache: cache)
        await vm.loadCountries()

        XCTAssertTrue(vm.countries.isEmpty)
        XCTAssertNotNil(vm.countriesError)
        XCTAssertFalse(vm.isLoadingCountries)
    }

    func testLoadCountriesGuardsConcurrency() async {
        setMockResponse(json: "[]")

        let vm = BrowseViewModel(service: service, cache: cache)
        vm.isLoadingCountries = true

        await vm.loadCountries()
        // Should return immediately due to guard
        XCTAssertTrue(vm.isLoadingCountries)
    }

    // MARK: - Languages

    func testLoadLanguagesSuccess() async {
        let json = """
        [
            {"name": "english", "iso_639": "eng", "stationcount": 10000},
            {"name": "spanish", "iso_639": "spa", "stationcount": 5000}
        ]
        """
        setMockResponse(json: json)

        let vm = BrowseViewModel(service: service, cache: cache)
        await vm.loadLanguages()

        XCTAssertEqual(vm.languages.count, 2)
        XCTAssertEqual(vm.languages[0].name, "english")
        XCTAssertEqual(vm.languages[1].name, "spanish")
        XCTAssertFalse(vm.isLoadingLanguages)
        XCTAssertNil(vm.languagesError)
    }

    func testLoadLanguagesError() async {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let vm = BrowseViewModel(service: service, cache: cache)
        await vm.loadLanguages()

        XCTAssertTrue(vm.languages.isEmpty)
        XCTAssertNotNil(vm.languagesError)
        XCTAssertFalse(vm.isLoadingLanguages)
    }

    func testLoadLanguagesGuardsConcurrency() async {
        setMockResponse(json: "[]")

        let vm = BrowseViewModel(service: service, cache: cache)
        vm.isLoadingLanguages = true

        await vm.loadLanguages()
        XCTAssertTrue(vm.isLoadingLanguages)
    }

    // MARK: - Tags

    func testLoadTagsSuccess() async {
        let json = """
        [
            {"name": "rock", "stationcount": 5000},
            {"name": "pop", "stationcount": 3000},
            {"name": "jazz", "stationcount": 2000}
        ]
        """
        setMockResponse(json: json)

        let vm = BrowseViewModel(service: service, cache: cache)
        await vm.loadTags()

        XCTAssertEqual(vm.tags.count, 3)
        XCTAssertEqual(vm.tags[0].name, "rock")
        XCTAssertEqual(vm.tags[1].name, "pop")
        XCTAssertEqual(vm.tags[2].name, "jazz")
        XCTAssertFalse(vm.isLoadingTags)
        XCTAssertNil(vm.tagsError)
    }

    func testLoadTagsError() async {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let vm = BrowseViewModel(service: service, cache: cache)
        await vm.loadTags()

        XCTAssertTrue(vm.tags.isEmpty)
        XCTAssertNotNil(vm.tagsError)
        XCTAssertFalse(vm.isLoadingTags)
    }

    func testLoadTagsGuardsConcurrency() async {
        setMockResponse(json: "[]")

        let vm = BrowseViewModel(service: service, cache: cache)
        vm.isLoadingTags = true

        await vm.loadTags()
        XCTAssertTrue(vm.isLoadingTags)
    }

    // MARK: - Initial State

    func testInitialState() {
        let vm = BrowseViewModel(service: service, cache: cache)

        XCTAssertTrue(vm.countries.isEmpty)
        XCTAssertTrue(vm.languages.isEmpty)
        XCTAssertTrue(vm.tags.isEmpty)
        XCTAssertFalse(vm.isLoadingCountries)
        XCTAssertFalse(vm.isLoadingLanguages)
        XCTAssertFalse(vm.isLoadingTags)
        XCTAssertNil(vm.countriesError)
        XCTAssertNil(vm.languagesError)
        XCTAssertNil(vm.tagsError)
    }

    func testDefaultSortOrders() {
        let vm = BrowseViewModel(service: service, cache: cache)

        XCTAssertEqual(vm.countrySortOrder, .alphabetical)
        XCTAssertEqual(vm.languagesSortOrder, .byStationCount)
        XCTAssertEqual(vm.tagsSortOrder, .byStationCount)
    }

    // MARK: - Sorted Computed Properties

    func testSortedCountriesAlphabetical() async {
        let json = """
        [
            {"name": "The United States Of America", "iso_3166_1": "US", "stationcount": 1000},
            {"name": "Argentina", "iso_3166_1": "AR", "stationcount": 500},
            {"name": "France", "iso_3166_1": "FR", "stationcount": 300},
            {"name": "Netherlands", "iso_3166_1": "NL", "stationcount": 400}
        ]
        """
        setMockResponse(json: json)

        let vm = BrowseViewModel(service: service, cache: cache)
        await vm.loadCountries()
        vm.countrySortOrder = .alphabetical

        XCTAssertEqual(vm.sortedCountries[0].displayName, "Argentina")
        XCTAssertEqual(vm.sortedCountries[1].displayName, "France")
        XCTAssertEqual(vm.sortedCountries[2].displayName, "Netherlands")
        XCTAssertEqual(vm.sortedCountries[3].displayName, "United States")
    }

    func testSortedCountriesByStationCount() async {
        let json = """
        [
            {"name": "Argentina", "iso_3166_1": "AR", "stationcount": 500},
            {"name": "France", "iso_3166_1": "FR", "stationcount": 300},
            {"name": "The United States Of America", "iso_3166_1": "US", "stationcount": 1000},
            {"name": "Netherlands", "iso_3166_1": "NL", "stationcount": 400}
        ]
        """
        setMockResponse(json: json)

        let vm = BrowseViewModel(service: service, cache: cache)
        await vm.loadCountries()
        vm.countrySortOrder = .byStationCount

        XCTAssertEqual(vm.sortedCountries[0].stationcount, 1000)
        XCTAssertEqual(vm.sortedCountries[1].stationcount, 500)
        XCTAssertEqual(vm.sortedCountries[2].stationcount, 400)
        XCTAssertEqual(vm.sortedCountries[3].stationcount, 300)
    }

    func testSortedLanguagesAlphabetical() async {
        let json = """
        [
            {"name": "spanish", "iso_639": "spa", "stationcount": 5000},
            {"name": "english", "iso_639": "eng", "stationcount": 10000}
        ]
        """
        setMockResponse(json: json)

        let vm = BrowseViewModel(service: service, cache: cache)
        await vm.loadLanguages()
        vm.languagesSortOrder = .alphabetical

        XCTAssertEqual(vm.sortedLanguages[0].name, "english")
        XCTAssertEqual(vm.sortedLanguages[1].name, "spanish")
    }

    func testSortedLanguagesByStationCount() async {
        let json = """
        [
            {"name": "english", "iso_639": "eng", "stationcount": 10000},
            {"name": "spanish", "iso_639": "spa", "stationcount": 5000}
        ]
        """
        setMockResponse(json: json)

        let vm = BrowseViewModel(service: service, cache: cache)
        await vm.loadLanguages()
        vm.languagesSortOrder = .byStationCount

        XCTAssertEqual(vm.sortedLanguages[0].name, "english")
        XCTAssertEqual(vm.sortedLanguages[1].name, "spanish")
    }

    func testSortedTagsAlphabetical() async {
        let json = """
        [
            {"name": "rock", "stationcount": 5000},
            {"name": "jazz", "stationcount": 2000},
            {"name": "pop", "stationcount": 3000}
        ]
        """
        setMockResponse(json: json)

        let vm = BrowseViewModel(service: service, cache: cache)
        await vm.loadTags()
        vm.tagsSortOrder = .alphabetical

        XCTAssertEqual(vm.sortedTags[0].name, "jazz")
        XCTAssertEqual(vm.sortedTags[1].name, "pop")
        XCTAssertEqual(vm.sortedTags[2].name, "rock")
    }

    func testSortedTagsByStationCount() async {
        let json = """
        [
            {"name": "jazz", "stationcount": 2000},
            {"name": "rock", "stationcount": 5000},
            {"name": "pop", "stationcount": 3000}
        ]
        """
        setMockResponse(json: json)

        let vm = BrowseViewModel(service: service, cache: cache)
        await vm.loadTags()
        vm.tagsSortOrder = .byStationCount

        XCTAssertEqual(vm.sortedTags[0].name, "rock")
        XCTAssertEqual(vm.sortedTags[1].name, "pop")
        XCTAssertEqual(vm.sortedTags[2].name, "jazz")
    }

    // MARK: - Cache Tests

    func testCachedCountriesShownOnNetworkFailure() async {
        let countries = [
            TestFixtures.makeCountry(name: "Argentina", stationcount: 500),
            TestFixtures.makeCountry(name: "France", stationcount: 300),
        ]
        await cache.save(key: StationCacheService.browseCountries, value: countries)

        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let vm = BrowseViewModel(service: service, cache: cache)
        await vm.loadCountries()

        XCTAssertEqual(vm.countries.count, 2)
        XCTAssertEqual(vm.countries[0].name, "Argentina")
        XCTAssertNil(vm.countriesError)
        XCTAssertFalse(vm.isLoadingCountries)
    }

    func testFreshCountriesReplaceCachedData() async {
        let oldCountries = [TestFixtures.makeCountry(name: "Old Country")]
        await cache.save(key: StationCacheService.browseCountries, value: oldCountries)

        let json = """
        [
            {"name": "Argentina", "iso_3166_1": "AR", "stationcount": 500},
            {"name": "France", "iso_3166_1": "FR", "stationcount": 300}
        ]
        """
        setMockResponse(json: json)

        let vm = BrowseViewModel(service: service, cache: cache)
        await vm.loadCountries()

        XCTAssertEqual(vm.countries.count, 2)
        let names = Set(vm.countries.map(\.displayName))
        XCTAssertTrue(names.contains("France"))
        XCTAssertTrue(names.contains("Argentina"))
    }

    func testCountriesCacheUpdatedAfterFetch() async {
        let json = """
        [
            {"name": "Argentina", "iso_3166_1": "AR", "stationcount": 500}
        ]
        """
        setMockResponse(json: json)

        let vm = BrowseViewModel(service: service, cache: cache)
        await vm.loadCountries()

        let cached: [Country]? = await cache.load(key: StationCacheService.browseCountries)
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.count, 1)
        XCTAssertEqual(cached?[0].name, "Argentina")
    }

    func testCachedLanguagesShownOnNetworkFailure() async {
        let languages = [TestFixtures.makeLanguage(name: "english")]
        await cache.save(key: StationCacheService.browseLanguages, value: languages)

        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let vm = BrowseViewModel(service: service, cache: cache)
        await vm.loadLanguages()

        XCTAssertEqual(vm.languages.count, 1)
        XCTAssertEqual(vm.languages[0].name, "english")
        XCTAssertNil(vm.languagesError)
    }

    func testLanguagesCacheUpdatedAfterFetch() async {
        let json = """
        [
            {"name": "english", "iso_639": "eng", "stationcount": 10000}
        ]
        """
        setMockResponse(json: json)

        let vm = BrowseViewModel(service: service, cache: cache)
        await vm.loadLanguages()

        let cached: [Language]? = await cache.load(key: StationCacheService.browseLanguages)
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?[0].name, "english")
    }

    func testCachedTagsShownOnNetworkFailure() async {
        let tags = [TestFixtures.makeTag(name: "rock")]
        await cache.save(key: StationCacheService.browseTags, value: tags)

        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let vm = BrowseViewModel(service: service, cache: cache)
        await vm.loadTags()

        XCTAssertEqual(vm.tags.count, 1)
        XCTAssertEqual(vm.tags[0].name, "rock")
        XCTAssertNil(vm.tagsError)
    }

    func testTagsCacheUpdatedAfterFetch() async {
        let json = """
        [
            {"name": "rock", "stationcount": 5000}
        ]
        """
        setMockResponse(json: json)

        let vm = BrowseViewModel(service: service, cache: cache)
        await vm.loadTags()

        let cached: [Tag]? = await cache.load(key: StationCacheService.browseTags)
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?[0].name, "rock")
    }

    // MARK: - Helpers

    private func setMockResponse(json: String) {
        MockURLProtocol.requestHandler = { request in
            let data = json.data(using: .utf8)!
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, data)
        }
    }
}
