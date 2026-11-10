import SwiftUI
import BebekPuanCore

struct AyarlarGorunumu: View {
    @Environment(AileStore.self) private var store
    @State private var yeniGorevGorunur = false
    @State private var sifirlaOnayi = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Aile") {
                    TextField("Bebeğin adı", text: Binding(
                        get: { store.durum.bebekAdi },
                        set: { store.bebekAdiGuncelle($0) }
                    ))
                    ForEach(store.durum.ebeveynler) { ebeveyn in
                        HStack {
                            TextField("Emoji", text: Binding(
                                get: { ebeveyn.emoji },
                                set: { var e = ebeveyn; e.emoji = String($0.prefix(2)); store.ebeveynGuncelle(e) }
                            ))
                            .frame(width: 44)
                            TextField(ebeveyn.rol.varsayilanAd, text: Binding(
                                get: { ebeveyn.ad },
                                set: { var e = ebeveyn; e.ad = $0; store.ebeveynGuncelle(e) }
                            ))
                        }
                    }
                }

                Section {
                    Stepper(
                        "Başlangıç: \(saat(store.durum.kurallar.geceBaslangicSaati))",
                        value: Binding(
                            get: { store.durum.kurallar.geceBaslangicSaati },
                            set: { store.geceAraligiGuncelle(baslangic: ($0 + 24) % 24, bitis: store.durum.kurallar.geceBitisSaati) }
                        ),
                        in: -1...24
                    )
                    Stepper(
                        "Bitiş: \(saat(store.durum.kurallar.geceBitisSaati))",
                        value: Binding(
                            get: { store.durum.kurallar.geceBitisSaati },
                            set: { store.geceAraligiGuncelle(baslangic: store.durum.kurallar.geceBaslangicSaati, bitis: ($0 + 24) % 24) }
                        ),
                        in: -1...24
                    )
                } header: {
                    Text("Gece bonusu 🌙")
                } footer: {
                    Text("Bu saatler arasında yapılan görevler ×\(store.durum.kurallar.geceCarpani.formatted()) puan kazandırır.")
                }

                Section {
                    ForEach(store.durum.gorevTurleri) { gorev in
                        NavigationLink {
                            ZorlukDuzenle(gorev: gorev)
                        } label: {
                            HStack {
                                Text(gorev.emoji)
                                Text(gorev.ad)
                                Spacer()
                                Text("\(gorev.zorluk)/10")
                                    .foregroundStyle(ZorlukRengi.renk(gorev.zorluk))
                                    .monospacedDigit()
                            }
                        }
                    }
                    .onDelete { indeksler in
                        let silinecek = indeksler.map { store.durum.gorevTurleri[$0] }
                        silinecek.forEach(store.gorevSil)
                    }
                    Button {
                        yeniGorevGorunur = true
                    } label: {
                        Label("Yeni görev ekle", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Görevler ve zorluk puanları")
                } footer: {
                    Text("Zorluğu değiştirmek geçmişte kazanılan puanları etkilemez.")
                }

                Section {
                    Button("Tüm kayıtları sıfırla", role: .destructive) { sifirlaOnayi = true }
                }
            }
            .navigationTitle("Ayarlar")
            .sheet(isPresented: $yeniGorevGorunur) { YeniGorevFormu() }
            .confirmationDialog("Tüm görev kayıtları ve puanlar silinsin mi?", isPresented: $sifirlaOnayi, titleVisibility: .visible) {
                Button("Sıfırla", role: .destructive) { store.tumKayitlariSifirla() }
            }
        }
    }

    private func saat(_ s: Int) -> String { String(format: "%02d:00", s) }
}

private struct ZorlukDuzenle: View {
    @Environment(AileStore.self) private var store
    let gorev: GorevTuru

    var body: some View {
        let guncel = store.gorev(id: gorev.id) ?? gorev
        Form {
            Section {
                HStack {
                    Text(guncel.emoji).font(.system(size: 56))
                    VStack(alignment: .leading) {
                        Text(guncel.ad).font(.title3.bold())
                        Text(ZorlukRengi.etiket(guncel.zorluk))
                            .foregroundStyle(ZorlukRengi.renk(guncel.zorluk))
                    }
                }
            }
            Section("Zorluk: \(guncel.zorluk) / 10") {
                Slider(
                    value: Binding(
                        get: { Double(guncel.zorluk) },
                        set: { store.zorlukGuncelle(guncel, zorluk: Int($0.rounded())) }
                    ),
                    in: 1...10,
                    step: 1
                )
                ZorlukCubugu(zorluk: guncel.zorluk)
                Text("Gündüz: \(guncel.zorluk * store.durum.kurallar.zorlukCarpani) puan · Gece: \(Int((Double(guncel.zorluk * store.durum.kurallar.zorlukCarpani) * store.durum.kurallar.geceCarpani).rounded())) puan")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Zorluk")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct YeniGorevFormu: View {
    @Environment(AileStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var ad = ""
    @State private var emoji = "⭐️"
    @State private var kategori: GorevKategorisi = .bakim
    @State private var zorluk = 3.0

    var body: some View {
        NavigationStack {
            Form {
                TextField("Görev adı (ör. Mama hazırlama)", text: $ad)
                TextField("Emoji", text: $emoji)
                Picker("Kategori", selection: $kategori) {
                    ForEach(GorevKategorisi.allCases) { Text($0.baslik).tag($0) }
                }
                VStack(alignment: .leading) {
                    Text("Zorluk: \(Int(zorluk)) / 10")
                    Slider(value: $zorluk, in: 1...10, step: 1)
                }
            }
            .navigationTitle("Yeni Görev")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ekle") {
                        store.ozelGorevEkle(ad: ad, emoji: String(emoji.prefix(2)), kategori: kategori, zorluk: Int(zorluk))
                        dismiss()
                    }
                    .disabled(ad.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
