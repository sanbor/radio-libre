import SwiftUI

struct StationListView: View {
    @StateObject private var viewModel: StationListViewModel
    @EnvironmentObject private var playerVM: PlayerViewModel
    @State private var searchText = ""
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    init(filter: StationListViewModel.Filter, title: String) {
        _viewModel = StateObject(wrappedValue: StationListViewModel(filter: filter, title: title))
    }

    var body: some View {
        AsyncContentView(
            isLoading: viewModel.isLoading,
            error: viewModel.error,
            isEmpty: viewModel.stations.isEmpty,
            loadingMessage: "Loading stations...",
            onRetry: { await viewModel.load() },
            emptyContent: { emptyView },
            content: { stationList }
        )
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search stations")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if verticalSizeClass == .compact {
                    sortMenu
                }
            }
        }
        .onChange(of: viewModel.sortOrder) { _ in
            Task { await viewModel.reloadForCurrentSort() }
        }
        .task(id: searchText) {
            guard !searchText.isEmpty else { return }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            viewModel.fetchAllIfNeeded()
        }
        .onChange(of: viewModel.isLoading) { isLoading in
            if !isLoading && !viewModel.stations.isEmpty {
                viewModel.fetchAllIfNeeded()
            }
        }
        .task { await viewModel.load() }
    }

    // MARK: - Filtered data

    private var filteredStations: [StationDTO] {
        if searchText.isEmpty { return viewModel.stations }
        return viewModel.stations.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var sectionedFilteredStations: [(letter: String, stations: [StationDTO])] {
        let grouped = Dictionary(grouping: filteredStations) { station in
            let first = station.name.trimmingCharacters(in: .whitespaces).prefix(1)
            return first.isEmpty ? "#" : String(first).uppercased()
        }
        return grouped.sorted { $0.key < $1.key }
            .map { (letter: $0.key, stations: $0.value) }
    }

    // MARK: - Views

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No stations found")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var stationList: some View {
        VStack(spacing: 0) {
            if verticalSizeClass != .compact {
                sortPicker
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
            if viewModel.sortOrder == .byName {
                alphabeticalList
            } else {
                flatList
            }
        }
    }

    private var sortPicker: some View {
        Picker("Sort", selection: $viewModel.sortOrder) {
            ForEach(StationSortOrder.allCases, id: \.self) { order in
                Text(order.label).tag(order)
            }
        }
        .pickerStyle(.segmented)
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort", selection: $viewModel.sortOrder) {
                ForEach(StationSortOrder.allCases, id: \.self) { order in
                    Text(order.label).tag(order)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
    }

    private var alphabeticalList: some View {
        let sections = sectionedFilteredStations
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

                if viewModel.isFetchingAll {
                    loadingAllBanner
                }

                ForEach(sections, id: \.letter) { section in
                    Section {
                        ForEach(section.stations) { station in
                            stationRow(station)
                        }
                    } header: {
                        Text(section.letter)
                    }
                    .id(section.letter)
                }

                if filteredStations.isEmpty && !searchText.isEmpty && !viewModel.isFetchingAll {
                    noSearchResultsRow
                }

                if viewModel.isLoadingMore {
                    loadingMoreRow
                }

                Color.clear
                    .frame(height: verticalSizeClass == .compact ? 160 : LayoutConstants.listBottomPadding)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .compactSectionSpacing()
            .safeAreaInset(edge: .trailing, spacing: 0) {
                AlphabetIndexView(letters: letters, isLoading: viewModel.isFetchingAll) { letter in
                    withAnimation {
                        proxy.scrollTo(letter, anchor: .top)
                    }
                }
            }
        }
    }

    private var flatList: some View {
        List {
            if viewModel.isFetchingAll {
                loadingAllBanner
            }

            ForEach(filteredStations) { station in
                stationRow(station)
            }

            if filteredStations.isEmpty && !searchText.isEmpty && !viewModel.isFetchingAll {
                noSearchResultsRow
            }

            if viewModel.isLoadingMore {
                loadingMoreRow
            }

            Color.clear
                .frame(height: verticalSizeClass == .compact ? 160 : LayoutConstants.listBottomPadding)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .compactSectionSpacing()
    }

    private func stationRow(_ station: StationDTO) -> some View {
        let isConnecting = playerVM.isLoading && playerVM.currentStation?.stationuuid == station.stationuuid
        return StationRowView(station: station, isConnecting: isConnecting) {
            let context = PlaybackContext(
                source: .browse(title: viewModel.title),
                stations: filteredStations
            )
            playerVM.play(station: station, context: context)
        }
        .onAppear {
            if station.id == viewModel.stations.last?.id && searchText.isEmpty {
                Task { await viewModel.loadMore() }
            }
        }
    }

    private var loadingAllBanner: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("Loading all stations…")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private var noSearchResultsRow: some View {
        HStack {
            Spacer()
            Text("No stations matching \"\(searchText)\"")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.vertical, 24)
            Spacer()
        }
        .listRowSeparator(.hidden)
    }

    private var loadingMoreRow: some View {
        HStack {
            Spacer()
            ProgressView()
            Spacer()
        }
        .listRowSeparator(.hidden)
    }
}
