import Foundation

/// iCloud'da her öğe ayrı bir kayıt olarak tutulur. Böylece iki telefon aynı anda
/// farklı görevler kaydettiğinde hiçbir kayıt kaybolmaz.
public enum SenkronTuru: String, CaseIterable, Codable, Sendable {
    case ebeveyn = "Ebeveyn"
    case gorev = "Gorev"
    case kayit = "Kayit"
    case ayarlar = "Ayarlar"

    var onEk: String { rawValue.lowercased() + "_" }
}

/// Eşitlenecek tek bir öğenin bulut kaydı karşılığı.
public struct SenkronOgesi: Hashable, Sendable {
    public var tur: SenkronTuru
    /// Bulut kaydının adı (CKRecord.ID.recordName), ör. `kayit_<uuid>`.
    public var ad: String
    /// Öğenin JSON hali.
    public var veri: Data

    public init(tur: SenkronTuru, ad: String, veri: Data) {
        self.tur = tur
        self.ad = ad
        self.veri = veri
    }
}

/// Bir öğenin tür bilgisiyle birlikte değeri.
public enum SenkronDegeri: Hashable, Sendable {
    case ebeveyn(Ebeveyn)
    case gorev(GorevTuru)
    case kayit(GorevKaydi)
    case ayarlar(AileAyarlari)

    public var tur: SenkronTuru {
        switch self {
        case .ebeveyn: return .ebeveyn
        case .gorev: return .gorev
        case .kayit: return .kayit
        case .ayarlar: return .ayarlar
        }
    }

    /// "Son değişiklik kazanır" kuralı için. Görev kayıtları değişmediği için zamanı yoktur.
    var guncellenme: Date? {
        switch self {
        case .ebeveyn(let e): return e.guncellenme
        case .gorev(let g): return g.guncellenme
        case .ayarlar(let a): return a.guncellenme
        case .kayit: return nil
        }
    }

    func jsonVerisi() throws -> Data {
        let encoder = AileDurumu.jsonCoder().0
        switch self {
        case .ebeveyn(let e): return try encoder.encode(e)
        case .gorev(let g): return try encoder.encode(g)
        case .kayit(let k): return try encoder.encode(k)
        case .ayarlar(let a): return try encoder.encode(a)
        }
    }

    static func coz(_ oge: SenkronOgesi) throws -> SenkronDegeri {
        let decoder = AileDurumu.jsonCoder().1
        switch oge.tur {
        case .ebeveyn: return .ebeveyn(try decoder.decode(Ebeveyn.self, from: oge.veri))
        case .gorev: return .gorev(try decoder.decode(GorevTuru.self, from: oge.veri))
        case .kayit: return .kayit(try decoder.decode(GorevKaydi.self, from: oge.veri))
        case .ayarlar: return .ayarlar(try decoder.decode(AileAyarlari.self, from: oge.veri))
        }
    }
}

public extension AileDurumu {
    static let ayarlarKaydiAdi = "ayarlar_aile"

    static func kayitAdi(_ tur: SenkronTuru, _ kimlik: String) -> String {
        tur == .ayarlar ? ayarlarKaydiAdi : tur.onEk + kimlik
    }

    static func tur(kayitAdi: String) -> SenkronTuru? {
        SenkronTuru.allCases.first { kayitAdi.hasPrefix($0.onEk) }
    }

    /// Durumdaki tüm eşitlenebilir öğeler, bulut kaydı adına göre.
    func senkronDegerleri() -> [String: SenkronDegeri] {
        var harita: [String: SenkronDegeri] = [AileDurumu.ayarlarKaydiAdi: .ayarlar(ayarlar)]
        for e in ebeveynler { harita[AileDurumu.kayitAdi(.ebeveyn, e.id.uuidString)] = .ebeveyn(e) }
        for g in gorevTurleri { harita[AileDurumu.kayitAdi(.gorev, g.id)] = .gorev(g) }
        for k in kayitlar { harita[AileDurumu.kayitAdi(.kayit, k.id.uuidString)] = .kayit(k) }
        return harita
    }

    func senkronOgesi(ad: String) -> SenkronOgesi? {
        guard let deger = senkronDegerleri()[ad], let veri = try? deger.jsonVerisi() else { return nil }
        return SenkronOgesi(tur: deger.tur, ad: ad, veri: veri)
    }

    /// İki durum arasında buluta gönderilmesi gereken değişiklikler.
    static func farklar(onceki: AileDurumu, sonraki: AileDurumu) -> (kaydedilecek: Set<String>, silinecek: Set<String>) {
        let eski = onceki.senkronDegerleri()
        let yeni = sonraki.senkronDegerleri()
        let kaydedilecek = Set(yeni.compactMap { ad, deger in eski[ad] == deger ? nil : ad })
        let silinecek = Set(eski.keys).subtracting(yeni.keys)
        return (kaydedilecek, silinecek)
    }

    /// Buluttan gelen bir öğeyi uygular. Yereldeki öğe daha yeni ise yerel korunur.
    /// - Returns: Durum değiştiyse `true`.
    @discardableResult
    mutating func uzaktanUygula(_ oge: SenkronOgesi) throws -> Bool {
        let gelen = try SenkronDegeri.coz(oge)
        let mevcut = senkronDegerleri()[oge.ad]
        if mevcut == gelen { return false }
        if let yerelZaman = mevcut?.guncellenme, let gelenZaman = gelen.guncellenme, yerelZaman > gelenZaman {
            return false
        }
        switch gelen {
        case .ayarlar(let a):
            ayarlar = a
        case .ebeveyn(let e):
            if let i = ebeveynler.firstIndex(where: { $0.id == e.id }) {
                ebeveynler[i] = e
            } else {
                ebeveynler.append(e)
                ebeveynler.sort { $0.rol.rawValue < $1.rol.rawValue }
            }
        case .gorev(let g):
            if let i = gorevTurleri.firstIndex(where: { $0.id == g.id }) {
                gorevTurleri[i] = g
            } else {
                gorevTurleri.append(g)
            }
        case .kayit(let k):
            kayitEkle(k)
        }
        return true
    }

    /// Bulutta silinen bir öğeyi yerelden de siler.
    /// - Returns: Durum değiştiyse `true`.
    @discardableResult
    mutating func uzaktanSil(ad: String) -> Bool {
        let onceki = self
        switch AileDurumu.tur(kayitAdi: ad) {
        case .kayit:
            kayitlar.removeAll { AileDurumu.kayitAdi(.kayit, $0.id.uuidString) == ad }
        case .gorev:
            gorevTurleri.removeAll { AileDurumu.kayitAdi(.gorev, $0.id) == ad }
        case .ebeveyn, .ayarlar, .none:
            // Ebeveynler ve ayarlar silinmez; yalnızca güncellenir.
            break
        }
        return onceki != self
    }
}
