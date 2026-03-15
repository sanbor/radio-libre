import ActivityKit
import Foundation

@MainActor
final class LiveActivityService {
    static let shared = LiveActivityService()

    private var currentActivity: (any AnyLiveActivity)?

    private init() {}

    func startOrUpdate(station: StationDTO, isPlaying: Bool, isLoading: Bool, isBuffering: Bool) {
        guard #available(iOS 16.2, *) else { return }

        let state = RadioActivityAttributes.ContentState(
            stationName: station.name,
            codec: station.codec,
            bitrateLabel: station.bitrateLabel,
            flagEmoji: station.flagEmoji,
            isPlaying: isPlaying,
            isLoading: isLoading,
            isBuffering: isBuffering
        )

        if let activity = currentActivity as? Activity<RadioActivityAttributes> {
            Task {
                await activity.update(
                    ActivityContent(state: state, staleDate: Date().addingTimeInterval(15 * 60))
                )
            }
        } else {
            do {
                let activity = try Activity.request(
                    attributes: RadioActivityAttributes(),
                    content: ActivityContent(state: state, staleDate: Date().addingTimeInterval(15 * 60)),
                    pushType: nil
                )
                currentActivity = activity
            } catch {
                // Live Activity not available or permission denied
            }
        }
    }

    func end() {
        guard #available(iOS 16.2, *) else { return }
        guard let activity = currentActivity as? Activity<RadioActivityAttributes> else { return }

        Task {
            await activity.end(nil, dismissalPolicy: .default)
        }
        currentActivity = nil
    }

    func endOrphanedActivities() {
        guard #available(iOS 16.2, *) else { return }

        Task {
            for activity in Activity<RadioActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .default)
            }
        }
    }
}

/// Type-erased protocol to store any Activity without exposing the generic parameter.
private protocol AnyLiveActivity {}

@available(iOS 16.2, *)
extension Activity: AnyLiveActivity {}
