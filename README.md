# Bebek Puan 👶 — Aile İş Paylaşımı (iOS)

Yenidoğan bebeğin bakımını anne ve baba arasında **adil ve eğlenceli** paylaştırmak için bir iOS uygulaması.
Her işin (bez değiştirme, uyutma, gece kalkma, banyo…) 1–10 arası bir **zorluk puanı** var. Bir işi yapan ebeveyn
tek dokunuşla kaydeder ve puan kazanır; skor tablosu kimin ne kadar katkı verdiğini gösterir.

## Özellikler

- **Görevler** — Kategorilere ayrılmış hazır görev kartları. Üstten "Bu işi kim yaptı?" seçilir, karta dokunulur, puan eklenir.
- **Zorluk puanı** — Her görevin 1–10 zorluğu vardır. Kazanılan puan = `zorluk × 10`.
- **Gece bonusu 🌙** — 00:00–06:00 arası yapılan görevler **×1.5** puan (saat aralığı ayarlardan değiştirilebilir).
- **Skor tablosu** — Bugün / Bu Hafta / Bu Ay / Tümü; iş paylaşım yüzdesi ve "sıra sende!" mesajı.
- **Geçmiş** — Günlere göre gruplanmış kayıtlar; kaydırarak silme.
- **Ayarlar** — Ebeveyn adları ve emojileri, bebeğin adı, görev zorluklarını değiştirme, yeni görev ekleme.
- Zorluğu sonradan değiştirmek geçmişte kazanılan puanları **etkilemez** (puan kayıt anında saklanır).
- Veriler cihazda JSON olarak saklanır (`Documents/aile-durumu.json`), şifreli dosya korumasıyla.

### Varsayılan zorluk puanları

| Görev | Zorluk | Gündüz | Gece |
|---|---|---|---|
| 💧 Bez değiştirme (ıslak) | 2 | 20 | 30 |
| 💩 Bez değiştirme (kakalı) | 4 | 40 | 60 |
| 🛁 Banyo yaptırma | 5 | 50 | 75 |
| ✂️ Tırnak kesme | 4 | 40 | 60 |
| 👕 Kıyafet değiştirme | 2 | 20 | 30 |
| 🤱 Emzirme | 5 | 50 | 75 |
| 🍼 Biberonla besleme | 3 | 30 | 45 |
| 🫧 Gaz çıkarma | 2 | 20 | 30 |
| 🧼 Biberon yıkama / sterilizasyon | 2 | 20 | 30 |
| 😴 Uyutma | 6 | 60 | 90 |
| 🌙 Gece uyanmasına kalkma | 7 | 70 | 105 |
| 😭 Ağlama krizini sakinleştirme | 8 | 80 | 120 |
| 🩺 Doktor / aşı randevusu | 6 | 60 | 90 |
| 💊 İlaç / vitamin verme | 2 | 20 | 30 |
| 🧻 Kusma sonrası temizlik | 3 | 30 | 45 |
| 🧺 Bebek çamaşırı yıkama | 3 | 30 | 45 |
| 🚼 Puset gezintisi | 3 | 30 | 45 |
| 🛒 Bez / mama alışverişi | 3 | 30 | 45 |

## Proje yapısı

```
Package.swift                 # BebekPuanCore Swift paketi (platformdan bağımsız iş mantığı)
Sources/BebekPuanCore/        # Modeller, puan kuralları, skor tablosu, kalıcı durum
Tests/BebekPuanCoreTests/     # XCTest birim testleri (Linux ve macOS'ta çalışır)
BebekPuan/                    # SwiftUI iOS uygulaması (iOS 17+)
  AileStore.swift             # @Observable durum + JSON kalıcılık
  Views/                      # Görevler, Skor, Geçmiş, Ayarlar ekranları
project.yml                   # XcodeGen proje tanımı
```

## Çalıştırma (macOS + Xcode 15+)

```bash
brew install xcodegen
xcodegen generate
open BebekPuan.xcodeproj
```

Xcode'da bir iPhone simülatörü seçip ▶︎ ile çalıştırın. Gerçek cihaz için *Signing & Capabilities* altından kendi
Apple ID / takımınızı seçin ve gerekirse `PRODUCT_BUNDLE_IDENTIFIER` değerini değiştirin.

## Testler

İş mantığı ayrı bir Swift paketinde olduğu için Mac olmadan da (ör. Linux bulut ortamında) test edilebilir:

```bash
swift test
```
