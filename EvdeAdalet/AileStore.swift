import Foundation
import Observation
import EvdeAdaletCore

/// Uygulama durumunu tutar, her değişiklikte cihazdaki JSON dosyasına kaydeder
/// ve değişiklikleri iCloud eşitleme motoruna bildirir.
@MainActor
@Observable
final class AileStore {
    private(set) var durum: AileDurumu
    /// Son kaydedilen görev; ekranda kısa "+puan" bildirimi göstermek için.
    var sonKayit: GorevKaydi?

    /// Önizlemelerde ve testlerde `nil`.
    private(set) var senkron: SenkronMotoru?

    private let dosyaURL: URL

    init(dosyaURL: URL? = nil, senkronEtkin: Bool = true) {
        let url = dosyaURL ?? URL.documentsDirectory.appending(path: "aile-durumu.json")
        self.dosyaURL = url
        if let veri = try? Data(contentsOf: url), let yuklenen = try? AileDurumu.yukle(veri) {
            durum = yuklenen
        } else {
            durum = AileDurumu()
        }
        if senkronEtkin {
            senkron = SenkronMotoru(store: self)
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

    func ebeveynGuncelle(_ ebeveyn: Ebeveyn, ad: String? = nil, emoji: String? = nil) {
        degistir { $0.ebeveynGuncelle(id: ebeveyn.id, ad: ad, emoji: emoji) }
    }

    func bebekAdiGuncelle(_ ad: String) {
        degistir { durum in durum.ayarlariGuncelle { $0.bebekAdi = ad } }
    }

    func geceAraligiGuncelle(baslangic: Int, bitis: Int) {
        degistir { durum in
            durum.ayarlariGuncelle {
                $0.kurallar.geceBaslangicSaati = baslangic
                $0.kurallar.geceBitisSaati = bitis
            }
        }
    }

    func tumKayitlariSifirla() {
        degistir { $0.tumKayitlariSil() }
    }

    // MARK: - Eşitleme

    /// iCloud'dan gelen değişiklikleri uygular (buluta geri bildirilmez).
    func uzaktanUygula(degisenler: [SenkronOgesi], silinenler: [String]) {
        var yeni = durum
        for oge in degisenler {
            do {
                try yeni.uzaktanUygula(oge)
            } catch {
                print("Eşitleme: \(oge.ad) çözülemedi: \(error)")
            }
        }
        for ad in silinenler {
            yeni.uzaktanSil(ad: ad)
        }
        guard yeni != durum else { return }
        durum = yeni
        diskeYaz()
    }

    // MARK: - Yardımcılar

    func gorev(id: String) -> GorevTuru? { durum.gorev(id: id) }
    func ebeveyn(id: UUID) -> Ebeveyn? { durum.ebeveyn(id: id) }

    private func degistir(_ islem: (inout AileDurumu) -> Void) {
        let onceki = durum
        islem(&durum)
        guard durum != onceki else { return }
        diskeYaz()
        let fark = AileDurumu.farklar(onceki: onceki, sonraki: durum)
        senkron?.yerelDegisiklikler(kaydedilecek: fark.kaydedilecek, silinecek: fark.silinecek)
    }

    private func diskeYaz() {
        do {
            try durum.jsonVerisi().write(to: dosyaURL, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } catch {
            print("Kaydetme hatası: \(error)")
        }
    }
}
