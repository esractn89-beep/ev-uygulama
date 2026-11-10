import SwiftUI
import EvdeAdaletCore

/// Ana ekran: kimin yaptığını seç, görevin kartına dokun, puanı kazan.
struct BugunGorunumu: View {
    @Environment(AileStore.self) private var store
    @State private var seciliEbeveynID: UUID?
    /// Bu telefonu kullanan ebeveyn (Ayarlar'dan seçilir); seçim varsayılan olarak bu kişidir.
    @AppStorage("benimRolum") private var benimRolum: EbeveynRolu = .anne
    @State private var bildirimGorunur = false

    private let sutunlar = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    private var seciliEbeveyn: Ebeveyn? {
        store.durum.ebeveynler.first { $0.id == seciliEbeveynID }
            ?? store.durum.ebeveynler.first { $0.rol == benimRolum }
            ?? store.durum.ebeveynler.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ebeveynSecici
                    bugunOzeti
                    ForEach(GorevKategorisi.allCases) { kategori in
                        let gorevler = store.durum.gorevTurleri.filter { $0.kategori == kategori }
                        if !gorevler.isEmpty {
                            Text(kategori.baslik)
                                .font(.headline)
                            LazyVGrid(columns: sutunlar, spacing: 12) {
                                ForEach(gorevler) { gorev in
                                    GorevKarti(gorev: gorev, kurallar: store.durum.kurallar) {
                                        yap(gorev)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .refreshable { await store.senkron?.simdiEsitle() }
            .navigationTitle("\(store.durum.bebekAdi) için 👶")
            .overlay(alignment: .top) { puanBildirimi }
            .sensoryFeedback(.success, trigger: store.sonKayit?.id)
        }
    }

    private var ebeveynSecici: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Bu işi kim yaptı?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Picker("Ebeveyn", selection: Binding(
                get: { seciliEbeveyn?.id },
                set: { seciliEbeveynID = $0 }
            )) {
                ForEach(store.durum.ebeveynler) { ebeveyn in
                    Text("\(ebeveyn.emoji) \(ebeveyn.ad)").tag(Optional(ebeveyn.id))
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var bugunOzeti: some View {
        let skorlar = store.durum.skorlar(donem: .bugun)
        return HStack {
            ForEach(skorlar) { skor in
                VStack {
                    Text(skor.ebeveyn.emoji).font(.title)
                    Text("\(skor.toplamPuan)")
                        .font(.title2.bold())
                        .contentTransition(.numericText())
                    Text("bugün").font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .animation(.spring, value: skorlar.map(\.toplamPuan))
    }

    @ViewBuilder
    private var puanBildirimi: some View {
        if bildirimGorunur, let kayit = store.sonKayit,
           let gorev = store.gorev(id: kayit.gorevID),
           let ebeveyn = store.ebeveyn(id: kayit.ebeveynID) {
            Text("\(ebeveyn.ad) +\(kayit.kazanilanPuan) puan · \(gorev.emoji)\(kayit.geceBonusu ? " 🌙 gece bonusu" : "")")
                .font(.callout.bold())
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.green.gradient, in: Capsule())
                .foregroundStyle(.white)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func yap(_ gorev: GorevTuru) {
        guard let ebeveyn = seciliEbeveyn else { return }
        store.gorevYapildi(gorev, ebeveyn: ebeveyn)
        withAnimation(.spring) { bildirimGorunur = true }
        let kayitID = store.sonKayit?.id
        Task {
            try? await Task.sleep(for: .seconds(2))
            if store.sonKayit?.id == kayitID {
                withAnimation { bildirimGorunur = false }
            }
        }
    }
}

struct GorevKarti: View {
    let gorev: GorevTuru
    let kurallar: PuanKurallari
    let eylem: () -> Void

    var body: some View {
        Button(action: eylem) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(gorev.emoji).font(.largeTitle)
                    Spacer()
                    Text("\(gorev.zorluk * kurallar.zorlukCarpani) p")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(ZorlukRengi.renk(gorev.zorluk).opacity(0.2), in: Capsule())
                        .foregroundStyle(ZorlukRengi.renk(gorev.zorluk))
                }
                Text(gorev.ad)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2, reservesSpace: true)
                ZorlukCubugu(zorluk: gorev.zorluk)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(gorev.ad), zorluk \(gorev.zorluk) / 10")
        .accessibilityHint("Görevi yapıldı olarak kaydeder")
    }
}
