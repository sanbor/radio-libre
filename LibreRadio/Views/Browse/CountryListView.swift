import SwiftUI

struct CountryListView: View {
    @EnvironmentObject private var viewModel: BrowseViewModel
    @State private var searchText = ""
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        Group {
            if viewModel.isLoadingCountries && viewModel.countries.isEmpty {
                LoadingView(message: "Loading countries...")
            } else if let error = viewModel.countriesError, viewModel.countries.isEmpty {
                ErrorView(error: error) {
                    await viewModel.loadCountries()
                }
            } else {
                countryList
            }
        }
        .navigationTitle("Countries")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search countries")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if verticalSizeClass == .compact {
                    sortMenu
                }
            }
        }
        .task { await viewModel.loadCountries() }
    }

    private var filteredCountries: [Country] {
        let sorted = viewModel.sortedCountries
        if searchText.isEmpty {
            return sorted
        }
        return sorted.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var sectionedCountries: [(letter: String, countries: [Country])] {
        let grouped = Dictionary(grouping: filteredCountries) { country in
            String(country.displayName.prefix(1)).uppercased()
        }
        return grouped.sorted { $0.key < $1.key }
            .map { (letter: $0.key, countries: $0.value) }
    }

    private var countryList: some View {
        VStack(spacing: 0) {
            if verticalSizeClass != .compact {
                sortPicker
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            if viewModel.countrySortOrder == .alphabetical {
                alphabeticalList
            } else {
                flatList
            }
        }
    }

    private var sortPicker: some View {
        Picker("Sort", selection: $viewModel.countrySortOrder) {
            ForEach(BrowseSortOrder.allCases, id: \.self) { order in
                Text(order.label).tag(order)
            }
        }
        .pickerStyle(.segmented)
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort", selection: $viewModel.countrySortOrder) {
                ForEach(BrowseSortOrder.allCases, id: \.self) { order in
                    Text(order.label).tag(order)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
    }

    private var alphabeticalList: some View {
        let sections = sectionedCountries
        let letters = sections.map(\.letter)

        return ScrollViewReader { proxy in
            List {
                if verticalSizeClass == .compact {
                    Color.clear
                        .frame(height: 72)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                }

                ForEach(sections, id: \.letter) { section in
                    Section {
                        ForEach(section.countries) { country in
                            countryRow(country)
                        }
                    } header: {
                        Text(section.letter)
                    }
                    .id(section.letter)
                }

                Color.clear
                    .frame(height: verticalSizeClass == .compact ? 160 : LayoutConstants.listBottomPadding)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .compactSectionSpacing()
            .safeAreaInset(edge: .trailing, spacing: 0) {
                AlphabetIndexView(letters: letters) { letter in
                    withAnimation {
                        proxy.scrollTo(letter, anchor: .top)
                    }
                }
            }
        }
    }

    private var flatList: some View {
        List {
            ForEach(filteredCountries) { country in
                countryRow(country)
            }

            Color.clear
                .frame(height: verticalSizeClass == .compact ? 160 : LayoutConstants.listBottomPadding)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .compactSectionSpacing()
    }

    private func countryRow(_ country: Country) -> some View {
        NavigationLink {
            StationListView(filter: .country(country.iso_3166_1), title: country.displayName)
        } label: {
            HStack {
                Text(getFlag(from: country.iso_3166_1))
                    .font(.title2)
                Text(country.displayName)
                Spacer()
                Text("\(country.stationcount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
