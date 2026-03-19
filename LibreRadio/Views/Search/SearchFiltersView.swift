import SwiftUI

struct SearchFiltersView: View {
    @ObservedObject var viewModel: SearchViewModel

    var body: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if let code = viewModel.filterCountrycode {
                        filterChip(label: "Country: \(code)") {
                            viewModel.filterCountrycode = nil
                            Task { await viewModel.performSearch() }
                        }
                    }
                    if let lang = viewModel.filterLanguage {
                        filterChip(label: "Language: \(lang)") {
                            viewModel.filterLanguage = nil
                            Task { await viewModel.performSearch() }
                        }
                    }
                    if let codec = viewModel.filterCodec {
                        filterChip(label: "Codec: \(codec)") {
                            viewModel.filterCodec = nil
                            Task { await viewModel.performSearch() }
                        }
                    }
                    if let bitrate = viewModel.filterBitrateMin {
                        filterChip(label: "Min: \(bitrate)k") {
                            viewModel.filterBitrateMin = nil
                            Task { await viewModel.performSearch() }
                        }
                    }

                    Button("Clear All") {
                        viewModel.clearFilters()
                    }
                    .font(.caption)
                    .foregroundStyle(.red)
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private func filterChip(label: String, onRemove: @escaping () -> Void) -> some View {
        Button(action: onRemove) {
            HStack(spacing: 4) {
                Text(label)
                Image(systemName: "xmark.circle.fill")
            }
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.systemGray5))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
