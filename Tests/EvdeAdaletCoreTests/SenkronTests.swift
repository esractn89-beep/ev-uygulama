import XCTest
@testable import EvdeAdaletCore

/// İki telefonun bulut üzerinden eşitlenmesini, CloudKit olmadan taklit eder.
final class SenkronTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    /// `kaynak` durumundaki öğeleri buluta "gönderip" `hedef`e uygular.
    private func aktar(_ adlar: Set<String>, from kaynak: AileDurumu, to hedef: inout AileDurumu) throws {
        for ad in adlar {
            let oge = try XCTUnwrap(kaynak.senkronOgesi(ad: ad))
            try hedef.uzaktanUygula(oge)
        }
    }

    private func tumOgeler(_ durum: AileDurumu) -> Set<String> {
        Set(durum.senkronDegerleri().keys)
    }

    func testVarsayilanEbeveynlerHerCihazdaAyniKimligiTasir() {
        XCTAssertEqual(AileDurumu().ebeveynler, AileDurumu().ebeveynler)
        XCTAssertEqual(AileDurumu().ebeveynler.map(\.id), [EbeveynRolu.anne.sabitKimlik, EbeveynRolu.baba.sabitKimlik])
    }

    func testKayitAdlariVeTurleri() {
        XCTAssertEqual(AileDurumu.tur(kayitAdi: "kayit_123"), .kayit)
        XCTAssertEqual(AileDurumu.tur(kayitAdi: "gorev_bez-islak"), .gorev)
        XCTAssertEqual(AileDurumu.tur(kayitAdi: AileDurumu.ayarlarKaydiAdi), .ayarlar)
        XCTAssertNil(AileDurumu.tur(kayitAdi: "baska_x"))
        // 2 ebeveyn + 18 görev + 1 ayar
        XCTAssertEqual(AileDurumu().senkronDegerleri().count, 2 + GorevTuru.varsayilanlar.count + 1)
    }

    func testFarklarYalnizcaDegisenleriVerir() throws {
        var durum = AileDurumu()
        let onceki = durum
        let kayit = try durum.kaydet(gorevID: "uyutma", ebeveynID: EbeveynRolu.baba.sabitKimlik, tarih: t0)
        durum.zorlukGuncelle(gorevID: "banyo", zorluk: 9, simdi: t0)
        durum.gorevSil(id: "tirnak")

        let fark = AileDurumu.farklar(onceki: onceki, sonraki: durum)
        XCTAssertEqual(fark.kaydedilecek, ["kayit_\(kayit.id.uuidString)", "gorev_banyo"])
        XCTAssertEqual(fark.silinecek, ["gorev_tirnak"])

        XCTAssertTrue(AileDurumu.farklar(onceki: durum, sonraki: durum).kaydedilecek.isEmpty)
    }

    func testDegismeyenDuzenlemeGuncellenmeyiDegistirmez() {
        var durum = AileDurumu()
        let onceki = durum
        durum.zorlukGuncelle(gorevID: "banyo", zorluk: 5, simdi: t0) // zaten 5
        durum.ebeveynGuncelle(id: EbeveynRolu.anne.sabitKimlik, ad: "Anne", simdi: t0)
        durum.ayarlariGuncelle(simdi: t0) { $0.bebekAdi = "Bebek" }
        XCTAssertEqual(durum, onceki)
    }

    func testIkiTelefonAyniAndaKayitEklediğindeHicbiriKaybolmaz() throws {
        var anneTelefonu = AileDurumu()
        var babaTelefonu = AileDurumu()

        let a = try anneTelefonu.kaydet(gorevID: "emzirme", ebeveynID: EbeveynRolu.anne.sabitKimlik, tarih: t0)
        let b = try babaTelefonu.kaydet(gorevID: "bez-kaka", ebeveynID: EbeveynRolu.baba.sabitKimlik, tarih: t0.addingTimeInterval(60))

        try aktar(tumOgeler(anneTelefonu), from: anneTelefonu, to: &babaTelefonu)
        try aktar(tumOgeler(babaTelefonu), from: babaTelefonu, to: &anneTelefonu)

        XCTAssertEqual(anneTelefonu, babaTelefonu)
        XCTAssertEqual(anneTelefonu.kayitlar.map(\.id), [b.id, a.id], "yeniden eskiye sıralı")
        XCTAssertEqual(anneTelefonu.skorlar(donem: .tumZamanlar).map(\.toplamPuan), [50, 40])
    }

    func testYeniKurulanTelefonunVarsayilanlariDuzenlemeleriEzmez() throws {
        var sahip = AileDurumu()
        sahip.ebeveynGuncelle(id: EbeveynRolu.anne.sabitKimlik, ad: "Ayşe", emoji: "🌸", simdi: t0)
        sahip.ayarlariGuncelle(simdi: t0) { $0.bebekAdi = "Deniz" }
        sahip.zorlukGuncelle(gorevID: "uyutma", zorluk: 9, simdi: t0)

        // Eşi uygulamayı daha sonra kuruyor ve hiçbir şeyi değiştirmeden aileye katılıyor.
        var katilimci = AileDurumu()
        // Katılımcı önce kendi varsayılanlarını göndermeye çalışır; sunucudaki (sahibin) kayıt kazanmalı.
        try aktar(tumOgeler(sahip), from: sahip, to: &katilimci)
        try aktar(tumOgeler(katilimci), from: katilimci, to: &sahip)

        XCTAssertEqual(katilimci.ebeveyn(id: EbeveynRolu.anne.sabitKimlik)?.ad, "Ayşe")
        XCTAssertEqual(katilimci.bebekAdi, "Deniz")
        XCTAssertEqual(katilimci.gorev(id: "uyutma")?.zorluk, 9)
        XCTAssertEqual(sahip, katilimci)
    }

    func testSonDegisiklikKazanir() throws {
        var telefon1 = AileDurumu()
        var telefon2 = AileDurumu()
        telefon1.zorlukGuncelle(gorevID: "banyo", zorluk: 7, simdi: t0)
        telefon2.zorlukGuncelle(gorevID: "banyo", zorluk: 3, simdi: t0.addingTimeInterval(5))

        let ad = AileDurumu.kayitAdi(.gorev, "banyo")
        XCTAssertFalse(try telefon2.uzaktanUygula(XCTUnwrap(telefon1.senkronOgesi(ad: ad))), "eski değişiklik yok sayılır")
        XCTAssertTrue(try telefon1.uzaktanUygula(XCTUnwrap(telefon2.senkronOgesi(ad: ad))))
        XCTAssertEqual(telefon1.gorev(id: "banyo")?.zorluk, 3)
        XCTAssertEqual(telefon2.gorev(id: "banyo")?.zorluk, 3)
    }

    func testOzelGorevVeSilmeEsitlenir() throws {
        var telefon1 = AileDurumu()
        var telefon2 = AileDurumu()
        let onceki = telefon1
        let gorev = try telefon1.ozelGorevEkle(ad: "Mama hazırlama", emoji: "🥣", kategori: .beslenme, zorluk: 3, simdi: t0)
        let kayit = try telefon1.kaydet(gorevID: gorev.id, ebeveynID: EbeveynRolu.baba.sabitKimlik, tarih: t0)

        try aktar(AileDurumu.farklar(onceki: onceki, sonraki: telefon1).kaydedilecek, from: telefon1, to: &telefon2)
        XCTAssertEqual(telefon2.gorev(id: gorev.id)?.ad, "Mama hazırlama")
        XCTAssertEqual(telefon2.kayitlar.map(\.id), [kayit.id])

        XCTAssertTrue(telefon2.uzaktanSil(ad: AileDurumu.kayitAdi(.kayit, kayit.id.uuidString)))
        XCTAssertTrue(telefon2.uzaktanSil(ad: AileDurumu.kayitAdi(.gorev, gorev.id)))
        XCTAssertFalse(telefon2.uzaktanSil(ad: AileDurumu.kayitAdi(.ebeveyn, EbeveynRolu.anne.sabitKimlik.uuidString)))
        XCTAssertTrue(telefon2.kayitlar.isEmpty)
        XCTAssertNil(telefon2.gorev(id: gorev.id))
    }

    func testBozukVeriHataVerir() {
        var durum = AileDurumu()
        let bozuk = SenkronOgesi(tur: .kayit, ad: "kayit_x", veri: Data("{}".utf8))
        XCTAssertThrowsError(try durum.uzaktanUygula(bozuk))
    }
}
