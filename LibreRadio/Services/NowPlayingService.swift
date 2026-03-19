import MediaPlayer
import UIKit

@MainActor
final class NowPlayingService {
    static let shared = NowPlayingService()

    private weak var audioService: AudioPlayerService?
    weak var playerViewModel: PlayerViewModel?

    init() {
        setupRemoteCommands()
    }

    func setAudioService(_ service: AudioPlayerService) {
        self.audioService = service
    }

    func setPlayerViewModel(_ viewModel: PlayerViewModel) {
        self.playerViewModel = viewModel
    }

    // MARK: - Now Playing Info

    func updateNowPlaying(station: StationDTO, isPlaying: Bool) {
        // Disabled: Live Activity is the sole lock screen element.
        // Remote commands still work via MPRemoteCommandCenter.
    }

    func clearNowPlaying() {
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - Remote Commands

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            self?.audioService?.resume()
            return .success
        }

        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            self?.audioService?.pause()
            return .success
        }

        center.stopCommand.isEnabled = true
        center.stopCommand.addTarget { [weak self] _ in
            self?.audioService?.stop()
            return .success
        }

        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.audioService?.togglePlayPause()
            return .success
        }

        center.nextTrackCommand.isEnabled = true
        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                await self?.playerViewModel?.playNextFavorite()
            }
            return .success
        }

        center.previousTrackCommand.isEnabled = true
        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                await self?.playerViewModel?.playPreviousFavorite()
            }
            return .success
        }
    }

}
