import Foundation

/// Ailedeki ebeveynin rolü.
public enum EbeveynRolu: String, Codable, CaseIterable, Identifiable, Sendable {
    case anne
    case baba

    public var id: String { rawValue }

    public var varsayilanAd: String {
        switch self {
        case .anne: return "Anne"
        case .baba: return "Baba"
        }
    }

    public var varsayilanEmoji: String {
        switch self {
        case .anne: return "👩"
        case .baba: return "👨"
        }
    }

    /// Her rolün tüm cihazlarda aynı olan kimliği. İki telefon ilk kez eşitlendiğinde
    /// "Anne" ve "Baba" kayıtlarının çoğalmadan birleşmesini sağlar.
    public var sabitKimlik: UUID {
        switch self {
        case .anne: return UUID(uuidString: "00000000-0000-0000-0000-0000000000A1")!
        case .baba: return UUID(uuidString: "00000000-0000-0000-0000-0000000000B1")!
        }
    }
}

/// Eşitlemede "son değişiklik kazanır" kuralı için kullanılan zaman.
/// Varsayılan (hiç düzenlenmemiş) öğeler en eski tarihi taşır; böylece yeni kurulan
/// bir telefonun varsayılanları diğer telefondaki düzenlemeleri ezmez.
public let varsayilanGuncellenme = Date(timeIntervalSince1970: 0)

/// İşleri paylaşan ebeveyn (karı / koca).
public struct Ebeveyn: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var ad: String
    public var rol: EbeveynRolu
    public var emoji: String
    public var guncellenme: Date

    public init(
        id: UUID = UUID(),
        ad: String,
        rol: EbeveynRolu,
        emoji: String? = nil,
        guncellenme: Date = varsayilanGuncellenme
    ) {
        self.id = id
        self.ad = ad
        self.rol = rol
        self.emoji = emoji ?? rol.varsayilanEmoji
        self.guncellenme = guncellenme
    }

    public static func varsayilan(_ rol: EbeveynRolu) -> Ebeveyn {
        Ebeveyn(id: rol.sabitKimlik, ad: rol.varsayilanAd, rol: rol)
    }
}

/// Görev kategorileri (ekranda gruplamak için).
public enum GorevKategorisi: String, Codable, CaseIterable, Identifiable, Sendable {
    case bakim
    case beslenme
    case uyku
    case saglik
    case ev

    public var id: String { rawValue }

    public var baslik: String {
        switch self {
        case .bakim: return "Bakım"
        case .beslenme: return "Beslenme"
        case .uyku: return "Uyku"
        case .saglik: return "Sağlık"
        case .ev: return "Ev İşleri"
        }
    }
}

/// Bebeğin bir ihtiyacı / ev işi ve zorluk derecesi.
public struct GorevTuru: Codable, Identifiable, Hashable, Sendable {
    public static let zorlukAraligi = 1...10

    public var id: String
    public var ad: String
    public var emoji: String
    public var kategori: GorevKategorisi
    /// 1 (çok kolay) ile 10 (çok zor) arası zorluk puanı.
    public var zorluk: Int {
        didSet { zorluk = GorevTuru.sinirla(zorluk) }
    }
    public var guncellenme: Date

    public init(
        id: String,
        ad: String,
        emoji: String,
        kategori: GorevKategorisi,
        zorluk: Int,
        guncellenme: Date = varsayilanGuncellenme
    ) {
        self.id = id
        self.ad = ad
        self.emoji = emoji
        self.kategori = kategori
        self.zorluk = GorevTuru.sinirla(zorluk)
        self.guncellenme = guncellenme
    }

    static func sinirla(_ deger: Int) -> Int {
        min(max(deger, zorlukAraligi.lowerBound), zorlukAraligi.upperBound)
    }
}

/// Bir ebeveynin bir görevi yaptığına dair kayıt.
///
/// Kazanılan puan kayıt anında saklanır; böylece görevin zorluğu sonradan
/// değiştirilse bile geçmiş puanlar değişmez. Kayıtlar oluşturulduktan sonra değişmez.
public struct GorevKaydi: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var gorevID: String
    public var ebeveynID: UUID
    public var tarih: Date
    public var kazanilanPuan: Int
    public var geceBonusu: Bool
    public var not: String?

    public init(
        id: UUID = UUID(),
        gorevID: String,
        ebeveynID: UUID,
        tarih: Date,
        kazanilanPuan: Int,
        geceBonusu: Bool,
        not: String? = nil
    ) {
        self.id = id
        self.gorevID = gorevID
        self.ebeveynID = ebeveynID
        self.tarih = tarih
        self.kazanilanPuan = kazanilanPuan
        self.geceBonusu = geceBonusu
        self.not = not
    }
}

/// Aile genelindeki ayarlar.
public struct AileAyarlari: Codable, Hashable, Sendable {
    public var bebekAdi: String
    public var kurallar: PuanKurallari
    public var guncellenme: Date

    public init(
        bebekAdi: String = "Bebek",
        kurallar: PuanKurallari = .varsayilan,
        guncellenme: Date = varsayilanGuncellenme
    ) {
        self.bebekAdi = bebekAdi
        self.kurallar = kurallar
        self.guncellenme = guncellenme
    }
}
