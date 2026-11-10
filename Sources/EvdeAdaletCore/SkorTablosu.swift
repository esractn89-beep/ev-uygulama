import Foundation

/// Skor tablosunda gösterilecek zaman aralığı.
public enum SkorDonemi: String, CaseIterable, Identifiable, Codable, Sendable {
    case bugun
    case buHafta
    case buAy
    case tumZamanlar

    public var id: String { rawValue }

    public var baslik: String {
        switch self {
        case .bugun: return "Bugün"
        case .buHafta: return "Bu Hafta"
        case .buAy: return "Bu Ay"
        case .tumZamanlar: return "Tümü"
        }
    }

    /// `nil` ise tüm zamanlar.
    public func aralik(simdi: Date = Date(), takvim: Calendar = .current) -> DateInterval? {
        switch self {
        case .bugun: return takvim.dateInterval(of: .day, for: simdi)
        case .buHafta: return takvim.dateInterval(of: .weekOfYear, for: simdi)
        case .buAy: return takvim.dateInterval(of: .month, for: simdi)
        case .tumZamanlar: return nil
        }
    }
}

/// Bir ebeveynin belirli dönemdeki skoru.
public struct EbeveynSkoru: Identifiable, Hashable, Sendable {
    public var ebeveyn: Ebeveyn
    public var toplamPuan: Int
    public var gorevSayisi: Int
    public var geceGorevSayisi: Int

    public var id: UUID { ebeveyn.id }
}

public enum SkorTablosu {
    /// Ebeveynlerin skorlarını en yüksekten en düşüğe sıralı hesaplar.
    public static func hesapla(
        kayitlar: [GorevKaydi],
        ebeveynler: [Ebeveyn],
        aralik: DateInterval?
    ) -> [EbeveynSkoru] {
        let filtreli = kayitlar.filter { kayit in
            guard let aralik else { return true }
            return kayit.tarih >= aralik.start && kayit.tarih < aralik.end
        }
        return ebeveynler.map { ebeveyn in
            let kendi = filtreli.filter { $0.ebeveynID == ebeveyn.id }
            return EbeveynSkoru(
                ebeveyn: ebeveyn,
                toplamPuan: kendi.reduce(0) { $0 + $1.kazanilanPuan },
                gorevSayisi: kendi.count,
                geceGorevSayisi: kendi.filter(\.geceBonusu).count
            )
        }
        .sorted { lhs, rhs in
            if lhs.toplamPuan != rhs.toplamPuan { return lhs.toplamPuan > rhs.toplamPuan }
            return lhs.ebeveyn.rol.rawValue < rhs.ebeveyn.rol.rawValue
        }
    }

    /// Her ebeveynin toplam puandaki payı (0...1). Hiç puan yoksa eşit pay döner.
    public static func paylar(_ skorlar: [EbeveynSkoru]) -> [UUID: Double] {
        let toplam = skorlar.reduce(0) { $0 + $1.toplamPuan }
        guard !skorlar.isEmpty else { return [:] }
        guard toplam > 0 else {
            let esit = 1.0 / Double(skorlar.count)
            return Dictionary(uniqueKeysWithValues: skorlar.map { ($0.id, esit) })
        }
        return Dictionary(uniqueKeysWithValues: skorlar.map { ($0.id, Double($0.toplamPuan) / Double(toplam)) })
    }

    /// İki kişilik paylaşımın ne kadar dengeli olduğunu söyleyen kısa mesaj.
    public static func dengeMesaji(_ skorlar: [EbeveynSkoru]) -> String {
        guard skorlar.count >= 2 else { return "" }
        let lider = skorlar[0]
        let ikinci = skorlar[1]
        if lider.toplamPuan == 0 { return "Henüz kayıt yok. İlk görevi kim yapacak? 👶" }
        let fark = lider.toplamPuan - ikinci.toplamPuan
        let pay = paylar(skorlar)[lider.id] ?? 0.5
        if pay <= 0.55 { return "Harika denge! İşler adil paylaşılıyor 🤝" }
        return "\(lider.ebeveyn.ad) \(fark) puan önde. \(ikinci.ebeveyn.ad), sıra sende! 💪"
    }
}
