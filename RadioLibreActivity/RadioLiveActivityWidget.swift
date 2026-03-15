import ActivityKit
import SwiftUI
import WidgetKit

@available(iOS 16.2, *)
@main
struct RadioLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RadioActivityAttributes.self) { context in
            lockScreenBanner(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.state.stationName)
                            .font(.headline)
                            .lineLimit(1)
                    } icon: {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    stateIcon(context: context)
                        .font(.title2)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 8) {
                        if let flag = context.state.flagEmoji {
                            Text(flag)
                        }
                        if let codec = context.state.codec {
                            Text(codec)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(context.state.bitrateLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundStyle(.cyan)
            } compactTrailing: {
                stateIcon(context: context)
            } minimal: {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundStyle(.cyan)
            }
        }
    }

    // MARK: - Lock Screen Banner

    @ViewBuilder
    private func lockScreenBanner(context: ActivityViewContext<RadioActivityAttributes>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if let flag = context.state.flagEmoji {
                        Text(flag)
                    }
                    Text(context.state.stationName)
                        .font(.headline)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    if let codec = context.state.codec {
                        Text(codec)
                    }
                    Text(context.state.bitrateLabel)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            stateIcon(context: context)
                .font(.title2)
        }
        .padding()
    }

    // MARK: - Helpers

    @ViewBuilder
    private func stateIcon(context: ActivityViewContext<RadioActivityAttributes>) -> some View {
        if context.state.isLoading || context.state.isBuffering {
            Image(systemName: "ellipsis")
        } else if context.state.isPlaying {
            Image(systemName: "waveform")
                .foregroundStyle(.cyan)
        } else {
            Image(systemName: "pause.fill")
                .foregroundStyle(.secondary)
        }
    }
}
