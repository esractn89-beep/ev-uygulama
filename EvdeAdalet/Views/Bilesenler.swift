import SwiftUI

enum ZorlukRengi {
    static func renk(_ zorluk: Int) -> Color {
        switch zorluk {
        case ...3: return .green
        case 4...6: return .orange
        default: return .red
        }
    }

    static func etiket(_ zorluk: Int) -> String {
        switch zorluk {
        case ...3: return "Kolay"
        case 4...6: return "Orta"
        default: return "Zor"
        }
    }
}

/// 10 parçalı zorluk göstergesi.
struct ZorlukCubugu: View {
    let zorluk: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...10, id: \.self) { i in
                Capsule()
                    .fill(i <= zorluk ? ZorlukRengi.renk(zorluk) : Color.gray.opacity(0.25))
                    .frame(height: 5)
            }
        }
        .accessibilityHidden(true)
    }
}
