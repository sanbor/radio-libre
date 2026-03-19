import SwiftUI

struct TagChipView: View {
    let tag: String

    var body: some View {
        Text(tag)
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color(.systemGray5))
            .clipShape(Capsule())
    }
}
