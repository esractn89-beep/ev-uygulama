import SwiftUI
import BebekPuanCore

struct SkorGorunumu: View {
    @Environment(AileStore.self) private var store
    @State private var donem: SkorDonemi = .buHafta

    var body: some View {
        let skorlar = store.durum.skorlar(donem: donem)
        let paylar = SkorTablosu.paylar(skorlar)

        NavigationStack {
            List {
                Section {
                    Picker("Dönem", selection: $donem) {
                        ForEach(SkorDonemi.allCases) { Text($0.baslik).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                }

                Section {
                    ForEach(Array(skorlar.enumerated()), id: \.element.id) { sira, skor in
                        HStack(spacing: 12) {
                            Text(sira == 0 && skor.toplamPuan > 0 ? "👑" : skor.ebeveyn.emoji)
                                .font(.largeTitle)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(skor.ebeveyn.ad).font(.headline)
                                Text("\(skor.gorevSayisi) görev · \(skor.geceGorevSayisi) gece görevi")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(skor.toplamPuan)")
                                .font(.title.bold())
                                .monospacedDigit()
                        }
                        .padding(.vertical, 4)
                    }
                } footer: {
                    Text(SkorTablosu.dengeMesaji(skorlar))
                }

                if skorlar.count >= 2 {
                    Section("İş paylaşımı") {
                        PayCubugu(skorlar: skorlar, paylar: paylar)
                            .padding(.vertical, 8)
                    }
                }

                Section("Puanlama nasıl çalışır?") {
                    Label("Her görevin 1–10 arası zorluk puanı var.", systemImage: "gauge.with.dots.needle.67percent")
                    Label("Kazanılan puan = zorluk × \(store.durum.kurallar.zorlukCarpani).", systemImage: "star.fill")
                    Label(
                        "\(saat(store.durum.kurallar.geceBaslangicSaati))–\(saat(store.durum.kurallar.geceBitisSaati)) arası yapılan görevler ×\(store.durum.kurallar.geceCarpani.formatted()) puan.",
                        systemImage: "moon.stars.fill"
                    )
                }
                .font(.callout)
            }
            .navigationTitle("Skor Tablosu")
        }
    }

    private func saat(_ s: Int) -> String { String(format: "%02d:00", s) }
}

private struct PayCubugu: View {
    let skorlar: [EbeveynSkoru]
    let paylar: [UUID: Double]
    private let renkler: [Color] = [.pink, .blue, .purple, .teal]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                HStack(spacing: 0) {
                    ForEach(Array(skorlar.enumerated()), id: \.element.id) { i, skor in
                        renkler[i % renkler.count]
                            .frame(width: geo.size.width * (paylar[skor.id] ?? 0))
                    }
                }
                .clipShape(Capsule())
            }
            .frame(height: 16)
            .animation(.spring, value: paylar)

            HStack {
                ForEach(Array(skorlar.enumerated()), id: \.element.id) { i, skor in
                    Label {
                        Text("\(skor.ebeveyn.ad) %\(Int(((paylar[skor.id] ?? 0) * 100).rounded()))")
                    } icon: {
                        Circle().fill(renkler[i % renkler.count]).frame(width: 10, height: 10)
                    }
                    .font(.caption)
                    if i < skorlar.count - 1 { Spacer() }
                }
            }
        }
    }
}
