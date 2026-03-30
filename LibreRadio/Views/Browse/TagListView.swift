import SwiftUI

struct TagListView: View {
    @EnvironmentObject private var viewModel: BrowseViewModel
    @State private var searchText = ""
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        Group {
            if viewModel.isLoadingTags && viewModel.tags.isEmpty {
                LoadingView(message: "Loading tags...")
            } else if let error = viewModel.tagsError, viewModel.tags.isEmpty {
                ErrorView(error: error) {
                    await viewModel.loadTags()
                }
            } else {
                tagList
            }
        }
        .navigationTitle("Tags")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search tags")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if verticalSizeClass == .compact {
                    sortMenu
                }
            }
        }
        .task { await viewModel.loadTags() }
    }

    private var filteredTags: [Tag] {
        let sorted = viewModel.sortedTags
        if searchText.isEmpty { return sorted }
        return sorted.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var sectionedTags: [(letter: String, tags: [Tag])] {
        let grouped = Dictionary(grouping: filteredTags) { tag in
            String(tag.name.prefix(1)).uppercased()
        }
        return grouped.sorted { $0.key < $1.key }
            .map { (letter: $0.key, tags: $0.value) }
    }

    private var tagList: some View {
        VStack(spacing: 0) {
            if verticalSizeClass != .compact {
                sortPicker
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            if viewModel.tagsSortOrder == .alphabetical {
                alphabeticalList
            } else {
                flatList
            }
        }
    }

    private var sortPicker: some View {
        Picker("Sort", selection: $viewModel.tagsSortOrder) {
            ForEach(BrowseSortOrder.allCases, id: \.self) { order in
                Text(order.label).tag(order)
            }
        }
        .pickerStyle(.segmented)
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort", selection: $viewModel.tagsSortOrder) {
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
        let sections = sectionedTags
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
                        ForEach(section.tags) { tag in
                            tagRow(tag)
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
            ForEach(filteredTags) { tag in
                tagRow(tag)
            }

            Color.clear
                .frame(height: verticalSizeClass == .compact ? 160 : LayoutConstants.listBottomPadding)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .compactSectionSpacing()
    }

    private func tagRow(_ tag: Tag) -> some View {
        NavigationLink {
            StationListView(filter: .tag(tag.name), title: tag.name.capitalized)
        } label: {
            HStack {
                Text(tag.name)
                Spacer()
                Text("\(tag.stationcount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
