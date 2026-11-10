import Foundation

/// Bir görevin kaç puan kazandıracağını belirleyen kurallar.
///
/// Temel puan = zorluk × `zorlukCarpani`.
/// Gece saatlerinde (varsayılan 00:00–06:00) yapılan görevler `geceCarpani` kadar fazla puan kazandırır.
public struct PuanKurallari: Codable, Hashable, Sendable {
    public var zorlukCarpani: Int
    /// Gece aralığının başladığı saat (dahil), 0–23.
    public var geceBaslangicSaati: Int
    /// Gece aralığının bittiği saat (hariç), 0–23.
    public var geceBitisSaati: Int
    public var geceCarpani: Double

    public init(
        zorlukCarpani: Int = 10,
        geceBaslangicSaati: Int = 0,
        geceBitisSaati: Int = 6,
        geceCarpani: Double = 1.5
    ) {
        self.zorlukCarpani = zorlukCarpani
        self.geceBaslangicSaati = geceBaslangicSaati
        self.geceBitisSaati = geceBitisSaati
        self.geceCarpani = geceCarpani
    }

    public static let varsayilan = PuanKurallari()

    /// Verilen tarihin gece aralığına düşüp düşmediği. Aralık gece yarısını aşabilir (ör. 22–6).
    public func geceMi(_ tarih: Date, takvim: Calendar = .current) -> Bool {
        let saat = takvim.component(.hour, from: tarih)
        if geceBaslangicSaati == geceBitisSaati { return false }
        if geceBaslangicSaati < geceBitisSaati {
            return saat >= geceBaslangicSaati && saat < geceBitisSaati
        }
        return saat >= geceBaslangicSaati || saat < geceBitisSaati
    }

    public func puan(for gorev: GorevTuru, tarih: Date, takvim: Calendar = .current) -> (puan: Int, geceBonusu: Bool) {
        let temel = gorev.zorluk * zorlukCarpani
        guard geceMi(tarih, takvim: takvim) else { return (temel, false) }
        return (Int((Double(temel) * geceCarpani).rounded()), true)
    }
}
