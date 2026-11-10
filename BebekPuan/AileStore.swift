import Foundation
import Observation
import BebekPuanCore

/// Uygulama durumunu tutar ve her değişiklikte cihazdaki JSON dosyasına kaydeder.
@MainActor
@Observable
final class AileStore {
    private(set) var durum: AileDurumu
    /// Son kaydedilen görev; ekranda kısa "+puan" bildirimi göstermek için.
    var sonKayit: GorevKaydi?

    private let dosyaURL: URL

    init(dosyaURL: URL? = nil) {
        let url = dosyaURL ?? URL.documentsDirectory.appending(path: "aile-durumu.json")
        self.dosyaURL = url
        if let veri = try? Data(contentsOf: url), let yuklenen = try? AileDurumu.yukle(veri) {
            durum = yuklenen
        } else {
            durum = AileDurumu()
        }
    }

    // MARK: - İşlemler

    func gorevYapildi(_ gorev: GorevTuru, ebeveyn: Ebeveyn, tarih: Date = Date()) {
        degistir { durum in
            sonKayit = try? durum.kaydet(gorevID: gorev.id, ebeveynID: ebeveyn.id, tarih: tarih)
        }
    }

    func kaydiSil(_ kayit: GorevKaydi) {
        degistir { $0.kaydiSil(id: kayit.id) }
    }

    func zorlukGuncelle(_ gorev: GorevTuru, zorluk: Int) {
        degistir { $0.zorlukGuncelle(gorevID: gorev.id, zorluk: zorluk) }
    }

    func ozelGorevEkle(ad: String, emoji: String, kategori: GorevKategorisi, zorluk: Int) {
        degistir { _ = try? $0.ozelGorevEkle(ad: ad, emoji: emoji, kategori: kategori, zorluk: zorluk) }
    }

    func gorevSil(_ gorev: GorevTuru) {
        degistir { $0.gorevSil(id: gorev.id) }
    }

    func ebeveynGuncelle(_ ebeveyn: Ebeveyn) {
        degistir { durum in
            guard let index = durum.ebeveynler.firstIndex(where: { $0.id == ebeveyn.id }) else { return }
            durum.ebeveynler[index] = ebeveyn
        }
    }

    func bebekAdiGuncelle(_ ad: String) {
        degistir { $0.bebekAdi = ad }
    }

    func geceAraligiGuncelle(baslangic: Int, bitis: Int) {
        degistir { durum in
            durum.kurallar.geceBaslangicSaati = baslangic
            durum.kurallar.geceBitisSaati = bitis
        }
    }

    func tumKayitlariSifirla() {
        degistir { $0.kayitlar.removeAll() }
    }

    // MARK: - Yardımcılar

    func gorev(id: String) -> GorevTuru? { durum.gorev(id: id) }
    func ebeveyn(id: UUID) -> Ebeveyn? { durum.ebeveyn(id: id) }

    private func degistir(_ islem: (inout AileDurumu) -> Void) {
        islem(&durum)
        kaydet()
    }

    private func kaydet() {
        do {
            try durum.jsonVerisi().write(to: dosyaURL, options: [.atomic, .completeFileProtection])
        } catch {
            print("Kaydetme hatası: \(error)")
        }
    }
}
