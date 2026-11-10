import SwiftUI
import EvdeAdaletCore

struct GecmisGorunumu: View {
    @Environment(AileStore.self) private var store

    private var gunlereGore: [(gun: Date, kayitlar: [GorevKaydi])] {
        let takvim = Calendar.current
        let gruplar = Dictionary(grouping: store.durum.kayitlar) { takvim.startOfDay(for: $0.tarih) }
        return gruplar
            .map { (gun: $0.key, kayitlar: $0.value.sorted { $0.tarih > $1.tarih }) }
            .sorted { $0.gun > $1.gun }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.durum.kayitlar.isEmpty {
                    ContentUnavailableView(
                        "Henüz kayıt yok",
                        systemImage: "tray",
                        description: Text("Görevler sekmesinden yaptığınız işleri kaydedin.")
                    )
                } else {
                    List {
                        ForEach(gunlereGore, id: \.gun) { grup in
                            Section {
                                ForEach(grup.kayitlar) { kayit in
                                    KayitSatiri(kayit: kayit)
                                }
                                .onDelete { indeksler in
                                    for i in indeksler { store.kaydiSil(grup.kayitlar[i]) }
                                }
                            } header: {
                                Text(grup.gun.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                            }
                        }
                    }
                }
            }
            .refreshable { await store.senkron?.simdiEsitle() }
            .navigationTitle("Geçmiş")
        }
    }
}

private struct KayitSatiri: View {
    @Environment(AileStore.self) private var store
    let kayit: GorevKaydi

    var body: some View {
        let gorev = store.gorev(id: kayit.gorevID)
        let ebeveyn = store.ebeveyn(id: kayit.ebeveynID)
        HStack(spacing: 12) {
            Text(gorev?.emoji ?? "❔").font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(gorev?.ad ?? "Silinmiş görev").font(.subheadline.weight(.semibold))
                Text("\(ebeveyn?.emoji ?? "") \(ebeveyn?.ad ?? "?") · \(kayit.tarih.formatted(date: .omitted, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("+\(kayit.kazanilanPuan)").font(.headline).monospacedDigit()
                if kayit.geceBonusu {
                    Text("🌙 gece").font(.caption2).foregroundStyle(.indigo)
                }
            }
        }
    }
}
