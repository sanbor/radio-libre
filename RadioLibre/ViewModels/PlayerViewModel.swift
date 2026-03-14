import Foundation
import Combine

@MainActor
final class PlayerViewModel: ObservableObject {
    let audioService: AudioPlayerService
    private let radioBrowserService: RadioBrowserService
    private let historyService: HistoryService
    private var cancellable: AnyCancellable?
    /// Exposed for testing – lets callers await the fire-and-forget history write.
    private(set) var historyTask: Task<Void, Never>?

    @MainActor
    init(
        audioService: AudioPlayerService,
        radioBrowserService: RadioBrowserService = .shared,
        historyService: HistoryService = .shared
    ) {
        self.audioService = audioService
        self.radioBrowserService = radioBrowserService
        self.historyService = historyService

        // Forward audioService state changes to trigger objectWillChange
        cancellable = audioService.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    // MARK: - Computed Properties

    var currentStation: StationDTO? {
        audioService.currentStation
    }

    var isPlaying: Bool {
        audioService.isPlaying
    }

    var isLoading: Bool {
        audioService.isLoading
    }

    var errorMessage: String? {
        if case .error(_, let message) = audioService.state {
            return message
        }
        return nil
    }

    var state: AudioPlayerService.PlaybackState {
        audioService.state
    }

    // MARK: - Actions

    func play(station: StationDTO) {
        audioService.play(station: station)
        historyTask = Task {
            await historyService.recordPlay(station: station)
        }
    }

    func togglePlayPause() {
        audioService.togglePlayPause()
    }

    func stop() {
        audioService.stop()
    }

    func vote(station: StationDTO) async throws -> VoteResponse {
        try await radioBrowserService.vote(stationuuid: station.stationuuid)
    }
}
