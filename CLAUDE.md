# Evde Adalet — Claude için proje notları

## Proje özeti

Yenidoğan bebeği olan anne-baba için iOS (SwiftUI, iOS 17+) iş paylaşımı uygulaması. Her görevin 1–10 zorluğu var;
kazanılan puan `zorluk × 10`, gece (varsayılan 00:00–06:00, ayarlardan değişir) ×1.5. Puan kayıt anında saklanır:
zorluk sonradan değişse de geçmiş puanlar değişmez. İki telefon iCloud (CloudKit, CKSyncEngine + CKShare) ile eşitlenir.

## Dizin yapısı

- `Sources/EvdeAdaletCore/` — platformdan bağımsız iş mantığı (modeller, puanlama, skor, eşitleme birleştirmesi). Linux'ta derlenir.
- `Tests/EvdeAdaletCoreTests/` — XCTest birim testleri.
- `EvdeAdalet/` — SwiftUI uygulaması, `AileStore` (@Observable), `Senkron/` (CloudKit). Linux'ta **derlenemez**.
- `project.yml` — XcodeGen tanımı; `.xcodeproj` depoya konmaz. Info.plist anahtarları ve yetkiler (entitlements) buradadır.
- `.github/workflows/ios.yml` — bulut Mac'te derleme ve TestFlight yüklemesi.

## Komutlar

- `swift test` — çekirdek testleri (her değişiklikten sonra yeşil olmalı).
- `swift build` — yalnızca çekirdek paketi derler.
- iOS uygulamasını derlemek için: `/ios-derle` (GitHub Actions üzerinden).
- Yeni varsayılan görev eklemek için: `/gorev-ekle <ad>, <zorluk>, <kategori> [emoji]`.

## Kurallar

- Tüm tanımlayıcılar, yorumlar, arayüz metinleri ve commit mesajları **Türkçe**; mevcut Türkçe karakterleri koru.
- Platformdan bağımsız mantık Core'a yazılır ve testi eklenir. Uygulama hedefi yalnızca arayüz, CloudKit ve store içerir.
- Core içinde asla `import SwiftUI`, `import CloudKit`, `import UIKit` yapma (Linux derlemesini bozar).
- Varsayılan görev kimlikleri kalıcıdır: kebab-case ASCII; **asla yeniden adlandırma veya silme** — CloudKit kayıt adları
  `gorev_<id>` biçimindedir ve cihazlar arasında paylaşılır.
- Ebeveyn kimlikleri sabittir (`EbeveynRolu.sabitKimlik`, …A1 / …B1); değiştirme.
- CloudKit kayıt türleri `Ebeveyn`, `Gorev`, `Kayit`, `Ayarlar` (alan: `veri`, Bytes). Yeni tür eklenirse README'deki
  şema adımını da güncelle (kullanıcı şemayı CloudKit Console'dan elle oluşturuyor).
- Dağıtım hedefi iOS 17.0: daha yeni API'leri `if #available` ile koru.
- Yeni Info.plist anahtarı / yetki gerekiyorsa `project.yml`'e ekle; elle plist dosyası oluşturma (`Destek/` üretilir ve git'e girmez).

## Doğrulama akışı

1. `swift test` yeşil olmalı.
2. `EvdeAdalet/` veya `project.yml` değiştiyse `/ios-derle` ile bulut Mac'te derle.
3. İsteğe bağlı: arayüz/CloudKit değişikliklerinden sonra `swiftui-inceleyici` ajanıyla incele.

## CI notları

- İş akışı `iOS`; işler: "Test ve derleme" (her push) ve "TestFlight'a yükle" (yalnızca elle tetiklenince, `testflight=true`).
- "The job was not acquired by Runner" ile iptal = GitHub'da macOS kapasite sorunu, kod hatası değil. Yeniden çalıştır
  veya depo değişkeni `MACOS_RUNNER`'ı değiştir (`macos-15-intel` ↔ `macos-15`).
- Gizli anahtarları (ASC_*) asla koda, log'a veya commit'e yazma.

## Kullanıcı bağlamı

Kullanıcının Mac'i yok; uygulamayı TestFlight ile telefona kuruyor. Açıklamaları Türkçe ve sade yap.
