import Foundation

/// Uygulamanın tüm kalıcı durumu. Cihazda JSON olarak saklanır,
/// iCloud'a ise öğe öğe (bkz. `Senkron.swift`) eşitlenir.
public struct AileDurumu: Codable, Hashable, Sendable {
    public static let surum = 2

    public var surum: Int
    public var ayarlar: AileAyarlari
    public var ebeveynler: [Ebeveyn]
    public var gorevTurleri: [GorevTuru]
    public var kayitlar: [GorevKaydi]

    public var bebekAdi: String { ayarlar.bebekAdi }
    public var kurallar: PuanKurallari { ayarlar.kurallar }

    public init(
        ayarlar: AileAyarlari = AileAyarlari(),
        ebeveynler: [Ebeveyn] = EbeveynRolu.allCases.map(Ebeveyn.varsayilan),
        gorevTurleri: [GorevTuru] = GorevTuru.varsayilanlar,
        kayitlar: [GorevKaydi] = []
    ) {
        self.surum = AileDurumu.surum
        self.ayarlar = ayarlar
        self.ebeveynler = ebeveynler
        self.gorevTurleri = gorevTurleri
        self.kayitlar = kayitlar.sorted { $0.tarih > $1.tarih }
    }

    public func gorev(id: String) -> GorevTuru? { gorevTurleri.first { $0.id == id } }
    public func ebeveyn(id: UUID) -> Ebeveyn? { ebeveynler.first { $0.id == id } }

    public enum Hata: Error, Equatable {
        case bilinmeyenGorev
        case bilinmeyenEbeveyn
        case gecersizAd
    }

    // MARK: - Görev kayıtları

    /// Bir görevin yapıldığını kaydeder ve kazanılan puanı hesaplar.
    @discardableResult
    public mutating func kaydet(
        gorevID: String,
        ebeveynID: UUID,
        tarih: Date = Date(),
        not: String? = nil,
        takvim: Calendar = .current
    ) throws -> GorevKaydi {
        guard let gorev = gorev(id: gorevID) else { throw Hata.bilinmeyenGorev }
        guard ebeveyn(id: ebeveynID) != nil else { throw Hata.bilinmeyenEbeveyn }
        let sonuc = kurallar.puan(for: gorev, tarih: tarih, takvim: takvim)
        let kayit = GorevKaydi(
            gorevID: gorevID,
            ebeveynID: ebeveynID,
            tarih: tarih,
            kazanilanPuan: sonuc.puan,
            geceBonusu: sonuc.geceBonusu,
            not: not
        )
        kayitEkle(kayit)
        return kayit
    }

    mutating func kayitEkle(_ kayit: GorevKaydi) {
        kayitlar.removeAll { $0.id == kayit.id }
        let index = kayitlar.firstIndex { $0.tarih <= kayit.tarih } ?? kayitlar.endIndex
        kayitlar.insert(kayit, at: index)
    }

    public mutating func kaydiSil(id: UUID) {
        kayitlar.removeAll { $0.id == id }
    }

    public mutating func tumKayitlariSil() {
        kayitlar.removeAll()
    }

    // MARK: - Görev türleri

    public mutating func zorlukGuncelle(gorevID: String, zorluk: Int, simdi: Date = Date()) {
        guard let index = gorevTurleri.firstIndex(where: { $0.id == gorevID }) else { return }
        guard gorevTurleri[index].zorluk != GorevTuru.sinirla(zorluk) else { return }
        gorevTurleri[index].zorluk = zorluk
        gorevTurleri[index].guncellenme = simdi
    }

    /// Kullanıcının kendi görevini ekler.
    @discardableResult
    public mutating func ozelGorevEkle(
        ad: String,
        emoji: String,
        kategori: GorevKategorisi,
        zorluk: Int,
        simdi: Date = Date()
    ) throws -> GorevTuru {
        let temizAd = ad.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !temizAd.isEmpty else { throw Hata.gecersizAd }
        let gorev = GorevTuru(
            id: "ozel-\(UUID().uuidString.lowercased())",
            ad: temizAd,
            emoji: emoji.isEmpty ? "⭐️" : emoji,
            kategori: kategori,
            zorluk: zorluk,
            guncellenme: simdi
        )
        gorevTurleri.append(gorev)
        return gorev
    }

    /// Görevi listeden kaldırır; geçmiş kayıtlar (ve puanları) korunur.
    public mutating func gorevSil(id: String) {
        gorevTurleri.removeAll { $0.id == id }
    }

    // MARK: - Aile ve ayarlar

    public mutating func ebeveynGuncelle(id: UUID, ad: String? = nil, emoji: String? = nil, simdi: Date = Date()) {
        guard let index = ebeveynler.firstIndex(where: { $0.id == id }) else { return }
        var ebeveyn = ebeveynler[index]
        if let ad { ebeveyn.ad = ad }
        if let emoji { ebeveyn.emoji = emoji }
        guard ebeveyn != ebeveynler[index] else { return }
        ebeveyn.guncellenme = simdi
        ebeveynler[index] = ebeveyn
    }

    public mutating func ayarlariGuncelle(simdi: Date = Date(), _ degisiklik: (inout AileAyarlari) -> Void) {
        var yeni = ayarlar
        degisiklik(&yeni)
        guard yeni != ayarlar else { return }
        yeni.guncellenme = simdi
        ayarlar = yeni
    }

    public func skorlar(donem: SkorDonemi, simdi: Date = Date(), takvim: Calendar = .current) -> [EbeveynSkoru] {
        SkorTablosu.hesapla(
            kayitlar: kayitlar,
            ebeveynler: ebeveynler,
            aralik: donem.aralik(simdi: simdi, takvim: takvim)
        )
    }

    // MARK: - JSON

    public static func jsonCoder() -> (JSONEncoder, JSONDecoder) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (encoder, JSONDecoder())
    }

    public func jsonVerisi() throws -> Data {
        try AileDurumu.jsonCoder().0.encode(self)
    }

    public static func yukle(_ veri: Data) throws -> AileDurumu {
        try jsonCoder().1.decode(AileDurumu.self, from: veri)
    }
}
