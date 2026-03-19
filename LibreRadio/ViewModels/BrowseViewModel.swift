import Foundation

@MainActor
final class BrowseViewModel: ObservableObject {
    @Published var countries: [Country] = []
    @Published var languages: [Language] = []
    @Published var tags: [Tag] = []
    @Published var isLoadingCountries = false
    @Published var isLoadingLanguages = false
    @Published var isLoadingTags = false
    @Published var countriesError: AppError?
    @Published var languagesError: AppError?
    @Published var tagsError: AppError?
    @Published var countrySortOrder: BrowseSortOrder = .alphabetical
    @Published var languagesSortOrder: BrowseSortOrder = .byStationCount
    @Published var tagsSortOrder: BrowseSortOrder = .byStationCount

    private let service: RadioBrowserService
    private let cache: StationCacheService

    init(service: RadioBrowserService = .shared, cache: StationCacheService = .shared) {
        self.service = service
        self.cache = cache
    }

    func loadCountries() async {
        guard !isLoadingCountries else { return }
        isLoadingCountries = true
        countriesError = nil

        let cached: [Country]? = await cache.load(key: StationCacheService.browseCountries)
        let hasCache = cached != nil
        if let cached = cached {
            countries = cached
        }

        do {
            let result = try await service.fetchCountries()
            countries = result
            await cache.save(key: StationCacheService.browseCountries, value: countries)
        } catch let appError as AppError {
            if !hasCache { countriesError = appError }
        } catch {
            if !hasCache { countriesError = .networkUnavailable }
        }

        isLoadingCountries = false
    }

    func loadLanguages() async {
        guard !isLoadingLanguages else { return }
        isLoadingLanguages = true
        languagesError = nil

        let cached: [Language]? = await cache.load(key: StationCacheService.browseLanguages)
        let hasCache = cached != nil
        if let cached = cached {
            languages = cached
        }

        do {
            let result = try await service.fetchLanguages()
            languages = result
            await cache.save(key: StationCacheService.browseLanguages, value: languages)
        } catch let appError as AppError {
            if !hasCache { languagesError = appError }
        } catch {
            if !hasCache { languagesError = .networkUnavailable }
        }

        isLoadingLanguages = false
    }

    func loadTags() async {
        guard !isLoadingTags else { return }
        isLoadingTags = true
        tagsError = nil

        let cached: [Tag]? = await cache.load(key: StationCacheService.browseTags)
        let hasCache = cached != nil
        if let cached = cached {
            tags = cached
        }

        do {
            let result = try await service.fetchTags()
            tags = result
            await cache.save(key: StationCacheService.browseTags, value: tags)
        } catch let appError as AppError {
            if !hasCache { tagsError = appError }
        } catch {
            if !hasCache { tagsError = .networkUnavailable }
        }

        isLoadingTags = false
    }

    var sortedCountries: [Country] {
        switch countrySortOrder {
        case .alphabetical:
            countries.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        case .byStationCount:
            countries.sorted { $0.stationcount > $1.stationcount }
        }
    }

    var sortedLanguages: [Language] {
        switch languagesSortOrder {
        case .alphabetical:
            languages.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .byStationCount:
            languages.sorted { $0.stationcount > $1.stationcount }
        }
    }

    var sortedTags: [Tag] {
        switch tagsSortOrder {
        case .alphabetical:
            tags.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .byStationCount:
            tags.sorted { $0.stationcount > $1.stationcount }
        }
    }
}
