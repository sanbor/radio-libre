import SwiftUI

struct StationCardView: View {
    let station: StationDTO
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                FaviconImageView(url: station.faviconURL, size: 64)

                Text(station.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)

                if let country = station.countryDisplayName, !country.isEmpty {
                    HStack(spacing: 2) {
                        if let flag = station.flagEmoji {
                            Text(flag).font(.caption2)
                        }
                        Text(country)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(width: 130)
            .padding(.vertical, 14)
            .padding(.horizontal, 10)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(station.name)
        .accessibilityHint("Double tap to play")
    }
}
