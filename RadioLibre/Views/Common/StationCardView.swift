import SwiftUI

struct StationCardView: View {
    let station: StationDTO
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                FaviconImageView(url: station.faviconURL, size: 80)

                Text(station.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)

                if let codec = station.codec, !codec.isEmpty {
                    Text("\(codec) · \(station.bitrateLabel)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(width: 140)
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(station.name)
        .accessibilityHint("Double tap to play")
    }
}
