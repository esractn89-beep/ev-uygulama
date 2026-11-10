import Foundation

public extension GorevTuru {
    /// Yenidoğan bakımı için hazır gelen görev listesi ve zorluk puanları.
    static let varsayilanlar: [GorevTuru] = [
        // Bakım
        GorevTuru(id: "bez-islak", ad: "Bez değiştirme (ıslak)", emoji: "💧", kategori: .bakim, zorluk: 2),
        GorevTuru(id: "bez-kaka", ad: "Bez değiştirme (kakalı)", emoji: "💩", kategori: .bakim, zorluk: 4),
        GorevTuru(id: "banyo", ad: "Banyo yaptırma", emoji: "🛁", kategori: .bakim, zorluk: 5),
        GorevTuru(id: "tirnak", ad: "Tırnak kesme", emoji: "✂️", kategori: .bakim, zorluk: 4),
        GorevTuru(id: "kiyafet", ad: "Kıyafet değiştirme", emoji: "👕", kategori: .bakim, zorluk: 2),

        // Beslenme
        GorevTuru(id: "emzirme", ad: "Emzirme", emoji: "🤱", kategori: .beslenme, zorluk: 5),
        GorevTuru(id: "biberon", ad: "Biberonla besleme", emoji: "🍼", kategori: .beslenme, zorluk: 3),
        GorevTuru(id: "gaz", ad: "Gaz çıkarma", emoji: "🫧", kategori: .beslenme, zorluk: 2),
        GorevTuru(id: "sterilizasyon", ad: "Biberon yıkama / sterilizasyon", emoji: "🧼", kategori: .beslenme, zorluk: 2),

        // Uyku
        GorevTuru(id: "uyutma", ad: "Uyutma", emoji: "😴", kategori: .uyku, zorluk: 6),
        GorevTuru(id: "gece-uyanma", ad: "Gece uyanmasına kalkma", emoji: "🌙", kategori: .uyku, zorluk: 7),
        GorevTuru(id: "aglama", ad: "Ağlama krizini sakinleştirme", emoji: "😭", kategori: .uyku, zorluk: 8),

        // Sağlık
        GorevTuru(id: "doktor", ad: "Doktor / aşı randevusu", emoji: "🩺", kategori: .saglik, zorluk: 6),
        GorevTuru(id: "ilac", ad: "İlaç / vitamin verme", emoji: "💊", kategori: .saglik, zorluk: 2),
        GorevTuru(id: "kusma", ad: "Kusma sonrası temizlik", emoji: "🧻", kategori: .saglik, zorluk: 3),

        // Ev işleri
        GorevTuru(id: "camasir", ad: "Bebek çamaşırı yıkama", emoji: "🧺", kategori: .ev, zorluk: 3),
        GorevTuru(id: "gezinti", ad: "Puset gezintisi", emoji: "🚼", kategori: .ev, zorluk: 3),
        GorevTuru(id: "alisveris", ad: "Bez / mama alışverişi", emoji: "🛒", kategori: .ev, zorluk: 3)
    ]
}
