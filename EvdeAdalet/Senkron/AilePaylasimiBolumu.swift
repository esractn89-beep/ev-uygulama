import CloudKit
import SwiftUI

/// Ayarlar ekranındaki "Aile paylaşımı" bölümü: eşi davet et / paylaşımı yönet.
struct AilePaylasimiBolumu: View {
    let senkron: SenkronMotoru

    @State private var hazirlaniyor = false
    @State private var paylasim: HazirPaylasim?
    @State private var hataMesaji: String?

    struct HazirPaylasim: Identifiable {
        let paylasim: CKShare
        let konteyner: CKContainer
        var id: ObjectIdentifier { ObjectIdentifier(paylasim) }
    }

    var body: some View {
        Section {
            LabeledContent("Durum") {
                Text(senkron.durum.aciklama)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(durumRengi)
            }

            Button {
                Task { await paylasimiAc() }
            } label: {
                HStack {
                    Label(dugmeBasligi, systemImage: senkron.paylasimVar ? "person.2.fill" : "person.badge.plus")
                    if hazirlaniyor {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(hazirlaniyor || senkron.durum == .iCloudYok)

            Button {
                Task { await senkron.simdiEsitle() }
            } label: {
                Label("Şimdi eşitle", systemImage: "arrow.triangle.2.circlepath")
            }
        } header: {
            Text("Aile paylaşımı ☁️")
        } footer: {
            Text(aciklama)
        }
        .sheet(item: $paylasim) { hazir in
            PaylasimGorunumu(paylasim: hazir.paylasim, konteyner: hazir.konteyner) {
                senkron.paylasimSonaErdi()
            }
            .ignoresSafeArea()
        }
        .alert("Paylaşım açılamadı", isPresented: Binding(
            get: { hataMesaji != nil },
            set: { if !$0 { hataMesaji = nil } }
        )) {
            Button("Tamam", role: .cancel) {}
        } message: {
            Text(hataMesaji ?? "")
        }
    }

    private var dugmeBasligi: String {
        switch senkron.kapsam {
        case .paylasilan: return "Paylaşımı görüntüle / ayrıl"
        case .ozel: return senkron.paylasimVar ? "Paylaşımı yönet" : "Eşimi davet et"
        }
    }

    private var aciklama: String {
        switch senkron.kapsam {
        case .paylasilan:
            return "Eşinizin ailesine katıldınız. Kaydettiğiniz her görev iki telefonda da görünür."
        case .ozel:
            return senkron.paylasimVar
                ? "Aileniz eşinizle paylaşılıyor. Kaydedilen her görev iki telefonda da görünür."
                : "Eşinize iCloud daveti gönderin. Daveti kabul ettiğinde iki telefon aynı skor tablosunu görür; onun telefonundaki kayıtlar da birleştirilir."
        }
    }

    private var durumRengi: Color {
        switch senkron.durum {
        case .hata, .iCloudYok: return .red
        case .esitlendi: return .green
        default: return .secondary
        }
    }

    private func paylasimiAc() async {
        hazirlaniyor = true
        defer { hazirlaniyor = false }
        do {
            let (paylasim, konteyner) = try await senkron.paylasimiHazirla()
            self.paylasim = HazirPaylasim(paylasim: paylasim, konteyner: konteyner)
        } catch {
            hataMesaji = error.localizedDescription
        }
    }
}
