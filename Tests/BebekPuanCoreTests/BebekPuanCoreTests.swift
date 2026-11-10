import XCTest
@testable import BebekPuanCore

final class BebekPuanCoreTests: XCTestCase {
    private var takvim: Calendar = {
        var takvim = Calendar(identifier: .gregorian)
        takvim.timeZone = TimeZone(identifier: "Europe/Istanbul")!
        takvim.firstWeekday = 2 // Pazartesi
        return takvim
    }()

    private func tarih(_ gun: Int, _ saat: Int, _ dakika: Int = 0) -> Date {
        takvim.date(from: DateComponents(year: 2026, month: 11, day: gun, hour: saat, minute: dakika))!
    }

    func testVarsayilanGorevlerinKimlikleriBenzersizVeZorluklarAraliktaOlmali() {
        let kimlikler = GorevTuru.varsayilanlar.map(\.id)
        XCTAssertEqual(Set(kimlikler).count, kimlikler.count)
        for gorev in GorevTuru.varsayilanlar {
            XCTAssertTrue(GorevTuru.zorlukAraligi.contains(gorev.zorluk), gorev.ad)
        }
    }

    func testZorlukSinirlandirilir() {
        var gorev = GorevTuru(id: "x", ad: "X", emoji: "x", kategori: .ev, zorluk: 42)
        XCTAssertEqual(gorev.zorluk, 10)
        gorev.zorluk = -3
        XCTAssertEqual(gorev.zorluk, 1)
    }

    func testGunduzPuaniZorlukCarpiOn() {
        let kurallar = PuanKurallari.varsayilan
        let bez = GorevTuru.varsayilanlar.first { $0.id == "bez-kaka" }!
        let sonuc = kurallar.puan(for: bez, tarih: tarih(10, 14), takvim: takvim)
        XCTAssertEqual(sonuc.puan, 40)
        XCTAssertFalse(sonuc.geceBonusu)
    }

    func testGeceBonusuUygulanir() {
        let kurallar = PuanKurallari.varsayilan
        let uyutma = GorevTuru.varsayilanlar.first { $0.id == "uyutma" }!
        let sonuc = kurallar.puan(for: uyutma, tarih: tarih(10, 3), takvim: takvim)
        XCTAssertEqual(sonuc.puan, 90) // 6 × 10 × 1.5
        XCTAssertTrue(sonuc.geceBonusu)
        XCTAssertFalse(kurallar.geceMi(tarih(10, 6), takvim: takvim))
    }

    func testGeceYarisiniAsanGeceAraligi() {
        let kurallar = PuanKurallari(geceBaslangicSaati: 22, geceBitisSaati: 6)
        XCTAssertTrue(kurallar.geceMi(tarih(10, 23), takvim: takvim))
        XCTAssertTrue(kurallar.geceMi(tarih(10, 2), takvim: takvim))
        XCTAssertFalse(kurallar.geceMi(tarih(10, 12), takvim: takvim))
    }

    func testKayitVeSkorTablosu() throws {
        var durum = AileDurumu()
        let anne = durum.ebeveynler.first { $0.rol == .anne }!
        let baba = durum.ebeveynler.first { $0.rol == .baba }!

        try durum.kaydet(gorevID: "bez-islak", ebeveynID: baba.id, tarih: tarih(10, 10), takvim: takvim) // 20
        try durum.kaydet(gorevID: "gece-uyanma", ebeveynID: baba.id, tarih: tarih(10, 3), takvim: takvim) // 105
        try durum.kaydet(gorevID: "emzirme", ebeveynID: anne.id, tarih: tarih(10, 11), takvim: takvim) // 50
        try durum.kaydet(gorevID: "banyo", ebeveynID: anne.id, tarih: tarih(3, 18), takvim: takvim) // 50, önceki hafta

        let bugun = durum.skorlar(donem: .bugun, simdi: tarih(10, 20), takvim: takvim)
        XCTAssertEqual(bugun.map(\.ebeveyn.rol), [.baba, .anne])
        XCTAssertEqual(bugun.map(\.toplamPuan), [125, 50])
        XCTAssertEqual(bugun[0].geceGorevSayisi, 1)

        let tumu = durum.skorlar(donem: .tumZamanlar, takvim: takvim)
        XCTAssertEqual(tumu.map(\.toplamPuan), [125, 100])

        XCTAssertEqual(durum.kayitlar.first?.gorevID, "emzirme", "kayıtlar yeniden eskiye sıralı")
    }

    func testZorlukDegisinceGecmisPuanDegismez() throws {
        var durum = AileDurumu()
        let anne = durum.ebeveynler[0]
        try durum.kaydet(gorevID: "bez-islak", ebeveynID: anne.id, tarih: tarih(10, 10), takvim: takvim)
        durum.zorlukGuncelle(gorevID: "bez-islak", zorluk: 9)
        try durum.kaydet(gorevID: "bez-islak", ebeveynID: anne.id, tarih: tarih(10, 11), takvim: takvim)
        XCTAssertEqual(durum.kayitlar.map(\.kazanilanPuan).sorted(), [20, 90])
    }

    func testBilinmeyenGorevVeEbeveyn() {
        var durum = AileDurumu()
        XCTAssertThrowsError(try durum.kaydet(gorevID: "yok", ebeveynID: durum.ebeveynler[0].id))
        XCTAssertThrowsError(try durum.kaydet(gorevID: "uyutma", ebeveynID: UUID()))
    }

    func testOzelGorevEkleVeSil() throws {
        var durum = AileDurumu()
        let gorev = try durum.ozelGorevEkle(ad: "  Mama hazırlama ", emoji: "", kategori: .beslenme, zorluk: 3)
        XCTAssertEqual(gorev.ad, "Mama hazırlama")
        XCTAssertEqual(gorev.emoji, "⭐️")
        XCTAssertNotNil(durum.gorev(id: gorev.id))
        XCTAssertThrowsError(try durum.ozelGorevEkle(ad: "   ", emoji: "x", kategori: .ev, zorluk: 1))

        try durum.kaydet(gorevID: gorev.id, ebeveynID: durum.ebeveynler[1].id, tarih: tarih(10, 12), takvim: takvim)
        durum.gorevSil(id: gorev.id)
        XCTAssertNil(durum.gorev(id: gorev.id))
        XCTAssertEqual(durum.kayitlar.count, 1, "silinen görevin geçmiş kaydı korunur")
    }

    func testPaylarVeDengeMesaji() {
        let anne = Ebeveyn(ad: "Ayşe", rol: .anne)
        let baba = Ebeveyn(ad: "Mehmet", rol: .baba)
        let bos = SkorTablosu.hesapla(kayitlar: [], ebeveynler: [anne, baba], aralik: nil)
        XCTAssertEqual(SkorTablosu.paylar(bos)[anne.id], 0.5)
        XCTAssertTrue(SkorTablosu.dengeMesaji(bos).contains("Henüz"))

        let kayitlar = [
            GorevKaydi(gorevID: "a", ebeveynID: anne.id, tarih: Date(), kazanilanPuan: 300, geceBonusu: false),
            GorevKaydi(gorevID: "b", ebeveynID: baba.id, tarih: Date(), kazanilanPuan: 100, geceBonusu: false)
        ]
        let skorlar = SkorTablosu.hesapla(kayitlar: kayitlar, ebeveynler: [anne, baba], aralik: nil)
        XCTAssertEqual(SkorTablosu.paylar(skorlar)[anne.id], 0.75)
        XCTAssertEqual(SkorTablosu.dengeMesaji(skorlar), "Ayşe 200 puan önde. Mehmet, sıra sende! 💪")
    }

    func testJSONGidisDonus() throws {
        var durum = AileDurumu(bebekAdi: "Deniz")
        try durum.kaydet(gorevID: "uyutma", ebeveynID: durum.ebeveynler[0].id, tarih: tarih(10, 21), not: "Ninni ile", takvim: takvim)
        let geri = try AileDurumu.yukle(durum.jsonVerisi())
        XCTAssertEqual(geri, durum)
    }
}
