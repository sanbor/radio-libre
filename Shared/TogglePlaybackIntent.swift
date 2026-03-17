import AppIntents
import ActivityKit

@available(iOS 17.0, *)
struct TogglePlaybackIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Toggle Playback"

    @MainActor
    func perform() async throws -> some IntentResult {
        if let activity = Activity<RadioActivityAttributes>.activities.first {
            let current = activity.content.state
            let toggled = RadioActivityAttributes.ContentState(
                stationName: current.stationName,
                codec: current.codec,
                bitrateLabel: current.bitrateLabel,
                flagEmoji: current.flagEmoji,
                countryName: current.countryName,
                isPlaying: !current.isPlaying,
                isLoading: false,
                isBuffering: false,
                faviconData: current.faviconData
            )
            await activity.update(
                ActivityContent(state: toggled, staleDate: Date().addingTimeInterval(15 * 60))
            )
        }
        RadioPlaybackAction.togglePlayPause?()
        return .result()
    }
}
