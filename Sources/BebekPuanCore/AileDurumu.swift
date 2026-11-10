import Foundation

/// Uygulamanın tüm kalıcı durumu. JSON olarak saklanır.
public struct AileDurumu: Codable, Hashable, Sendable {
    public static let surum = 1

    public var surum: Int
    public var bebekAdi: String
    public var ebeveynler: [Ebeveyn]
    public var gorevTurleri: [GorevTuru]
    public var kayitlar: [GorevKaydi]
    public var kurallar: PuanKurallari

    public init(
        bebekAdi: String = "Bebek",
        ebeveynler: [Ebeveyn] = EbeveynRolu.allCases.map { Ebeveyn(ad: $0.varsayilanAd, rol: $0) },
        gorevTurleri: [GorevTuru] = GorevTuru.varsayilanlar,
        kayitlar: [GorevKaydi] = [],
        kurallar: PuanKurallari = .varsayilan
    ) {
        self.surum = AileDurumu.surum
        self.bebekAdi = bebekAdi
        self.ebeveynler = ebeveynler
        self.gorevTurleri = gorevTurleri
        self.kayitlar = kayitlar
        self.kurallar = kurallar
    }

    public func gorev(id: String) -> GorevTuru? { gorevTurleri.first { $0.id == id } }
    public func ebeveyn(id: UUID) -> Ebeveyn? { ebeveynler.first { $0.id == id } }

    public enum Hata: Error, Equatable {
        case bilinmeyenGorev
        case bilinmeyenEbeveyn
        case gecersizAd
    }

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
        kayitlar.append(kayit)
        kayitlar.sort { $0.tarih > $1.tarih }
        return kayit
    }

    public mutating func kaydiSil(id: UUID) {
        kayitlar.removeAll { $0.id == id }
    }

    public mutating func zorlukGuncelle(gorevID: String, zorluk: Int) {
        guard let index = gorevTurleri.firstIndex(where: { $0.id == gorevID }) else { return }
        gorevTurleri[index].zorluk = zorluk
    }

    /// Kullanıcının kendi görevini ekler. Oluşan görevin kimliğini döner.
    @discardableResult
    public mutating func ozelGorevEkle(
        ad: String,
        emoji: String,
        kategori: GorevKategorisi,
        zorluk: Int
    ) throws -> GorevTuru {
        let temizAd = ad.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !temizAd.isEmpty else { throw Hata.gecersizAd }
        let gorev = GorevTuru(
            id: "ozel-\(UUID().uuidString.lowercased())",
            ad: temizAd,
            emoji: emoji.isEmpty ? "⭐️" : emoji,
            kategori: kategori,
            zorluk: zorluk
        )
        gorevTurleri.append(gorev)
        return gorev
    }

    /// Görevi listeden kaldırır; geçmiş kayıtlar (ve puanları) korunur.
    public mutating func gorevSil(id: String) {
        gorevTurleri.removeAll { $0.id == id }
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
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (encoder, decoder)
    }

    public func jsonVerisi() throws -> Data {
        try AileDurumu.jsonCoder().0.encode(self)
    }

    public static func yukle(_ veri: Data) throws -> AileDurumu {
        try jsonCoder().1.decode(AileDurumu.self, from: veri)
    }
}
