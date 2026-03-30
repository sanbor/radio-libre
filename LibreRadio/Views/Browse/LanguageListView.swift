import SwiftUI

struct LanguageListView: View {
    @EnvironmentObject private var viewModel: BrowseViewModel
    @State private var searchText = ""
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        Group {
            if viewModel.isLoadingLanguages && viewModel.languages.isEmpty {
                LoadingView(message: "Loading languages...")
            } else if let error = viewModel.languagesError, viewModel.languages.isEmpty {
                ErrorView(error: error) {
                    await viewModel.loadLanguages()
                }
            } else {
                languageList
            }
        }
        .navigationTitle("Languages")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search languages")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if verticalSizeClass == .compact {
                    sortMenu
                }
            }
        }
        .task { await viewModel.loadLanguages() }
    }

    private var filteredLanguages: [Language] {
        let sorted = viewModel.sortedLanguages
        if searchText.isEmpty { return sorted }
        return sorted.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var sectionedLanguages: [(letter: String, languages: [Language])] {
        let grouped = Dictionary(grouping: filteredLanguages) { language in
            languageSectionKey(for: language.name)
        }
        return grouped.sorted { lhs, rhs in
            if lhs.key == "#" { return false }
            if rhs.key == "#" { return true }
            return lhs.key < rhs.key
        }
        .map { (letter: $0.key, languages: $0.value) }
    }

    private var languageList: some View {
        VStack(spacing: 0) {
            if verticalSizeClass != .compact {
                sortPicker
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            if viewModel.languagesSortOrder == .alphabetical {
                alphabeticalList
            } else {
                flatList
            }
        }
    }

    private var sortPicker: some View {
        Picker("Sort", selection: $viewModel.languagesSortOrder) {
            ForEach(BrowseSortOrder.allCases, id: \.self) { order in
                Text(order.label).tag(order)
            }
        }
        .pickerStyle(.segmented)
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort", selection: $viewModel.languagesSortOrder) {
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
        let sections = sectionedLanguages
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
                        ForEach(section.languages) { language in
                            languageRow(language)
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
            ForEach(filteredLanguages) { language in
                languageRow(language)
            }

            Color.clear
                .frame(height: verticalSizeClass == .compact ? 160 : LayoutConstants.listBottomPadding)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .compactSectionSpacing()
    }

    private func languageRow(_ language: Language) -> some View {
        NavigationLink {
            StationListView(filter: .language(language.name), title: language.name.capitalized)
        } label: {
            HStack {
                Text(language.name.capitalized)
                Spacer()
                Text("\(language.stationcount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

func languageSectionKey(for name: String) -> String {
    let folded = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    guard let first = folded.first, first.isASCII && first.isLetter else { return "#" }
    return String(first).uppercased()
}
