# Evde Adalet ⚖️👶 — Aile İş Paylaşımı (iOS)

Yenidoğan bebeğin bakımını anne ve baba arasında **adil ve eğlenceli** paylaştırmak için bir iOS uygulaması.
Her işin (bez değiştirme, uyutma, gece kalkma, banyo…) 1–10 arası bir **zorluk puanı** var. Bir işi yapan ebeveyn
tek dokunuşla kaydeder ve puan kazanır; skor tablosu kimin ne kadar katkı verdiğini gösterir.

## Özellikler

- **Görevler** — Kategorilere ayrılmış hazır görev kartları. Üstten "Bu işi kim yaptı?" seçilir, karta dokunulur, puan eklenir.
- **Zorluk puanı** — Her görevin 1–10 zorluğu vardır. Kazanılan puan = `zorluk × 10`.
- **Gece bonusu 🌙** — 00:00–06:00 arası yapılan görevler **×1.5** puan (saat aralığı ayarlardan değiştirilebilir).
- **Skor tablosu** — Bugün / Bu Hafta / Bu Ay / Tümü; iş paylaşım yüzdesi ve "sıra sende!" mesajı.
- **Geçmiş** — Günlere göre gruplanmış kayıtlar; kaydırarak silme.
- **Ayarlar** — Ebeveyn adları ve emojileri, bebeğin adı, görev zorluklarını değiştirme, yeni görev ekleme, "Bu telefon kimin?".
- **İki telefon arasında eşitleme ☁️** — Ayarlar > *Eşimi davet et* ile iCloud daveti gönderilir. Eş daveti kabul edince
  iki telefon aynı görevleri ve skor tablosunu görür; eşin telefonundaki önceki kayıtlar da kaybolmadan birleştirilir.
- Zorluğu sonradan değiştirmek geçmişte kazanılan puanları **etkilemez** (puan kayıt anında saklanır).
- Veriler cihazda JSON olarak saklanır (`Documents/aile-durumu.json`) ve iCloud'a (CloudKit) eşitlenir. İnternet yokken
  de çalışır; bağlantı gelince değişiklikler gönderilir.

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
Package.swift                 # EvdeAdaletCore Swift paketi (platformdan bağımsız iş mantığı)
Sources/EvdeAdaletCore/        # Modeller, puan kuralları, skor tablosu, kalıcı durum
Tests/EvdeAdaletCoreTests/     # XCTest birim testleri (Linux ve macOS'ta çalışır)
EvdeAdalet/                    # SwiftUI iOS uygulaması (iOS 17+)
  AileStore.swift             # @Observable durum + JSON kalıcılık
  Senkron/                    # CloudKit eşitleme (CKSyncEngine) ve eş davet etme (CKShare)
  Views/                      # Görevler, Skor, Geçmiş, Ayarlar ekranları
project.yml                   # XcodeGen proje tanımı
```

## Çalıştırma (macOS + Xcode 15+)

```bash
brew install xcodegen
xcodegen generate
open EvdeAdalet.xcodeproj
```

Xcode'da bir iPhone simülatörü seçip ▶︎ ile çalıştırın.

### iCloud eşitlemesini açmak

iCloud/CloudKit için **ücretli Apple Developer hesabı** gerekir (ücretsiz hesapla uygulama çalışır ama eşitleme çalışmaz).

1. `project.yml` içindeki `com.example.evdeadalet` paket kimliğini ve `iCloud.com.example.evdeadalet` konteyner adını
   kendinize ait benzersiz değerlerle değiştirin (ör. `com.adiniz.evdeadalet`). Konteyner adını
   `EvdeAdalet/Senkron/SenkronMotoru.swift` içindeki `konteynerKimligi` değerinde de güncelleyin.
2. `xcodegen generate` → Xcode'da hedefin *Signing & Capabilities* sekmesinde takımınızı seçin.
   iCloud (CloudKit) ve Push Notifications yetenekleri `project.yml`'den gelir; konteynerin yanında kırmızı uyarı varsa
   "+" ile oluşturun.
3. Uygulamayı **iki gerçek iPhone'a** (farklı Apple ID'ler) yükleyin. Birinde *Ayarlar → Eşimi davet et* ile daveti
   Mesajlar/WhatsApp üzerinden gönderin, diğeri bağlantıya dokunup kabul etsin.
4. Her telefonda *Ayarlar → Bu telefon kimin?* seçin; görev kaydederken varsayılan kişi bu olur.
5. App Store/TestFlight'a çıkmadan önce CloudKit Console'da şemayı *Production*'a aktarın.

### Eşitleme nasıl çalışır?

- Her görev kaydı, görev türü, ebeveyn ve aile ayarı ayrı bir CloudKit kaydıdır; iki telefon aynı anda görev
  kaydetse de hiçbir kayıt kaybolmaz.
- Aynı ayar iki telefonda değiştirilirse **son değişiklik kazanır**. Hiç düzenlenmemiş varsayılanlar asla
  düzenlenmiş değerleri ezmez; "Anne" ve "Baba" her cihazda aynı kimliği taşıdığı için çoğalmaz.
- Birleştirme mantığı `Sources/EvdeAdaletCore/Senkron.swift` içindedir ve `swift test` ile test edilir.

## Testler

İş mantığı ayrı bir Swift paketinde olduğu için Mac olmadan da (ör. Linux bulut ortamında) test edilebilir:

```bash
swift test
```
