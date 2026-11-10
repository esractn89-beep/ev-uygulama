---
name: gorev-ekle
description: Varsayılan görev listesine yeni bir görev ekler (VarsayilanGorevler.swift + README tablosu + test). "/gorev-ekle <ad>, <zorluk>, <kategori> [emoji]" veya "yeni varsayılan görev ekle", "listeye görev ekle" isteğinde kullan.
argument-hint: "<ad>, <zorluk>, <kategori> [emoji]"
allowed-tools: Read, Edit, Grep, Bash(swift test:*), Bash(git diff:*), Bash(git log:*), Bash(grep:*)
---

# /gorev-ekle — yeni varsayılan görev

Örnek: `/gorev-ekle Mama hazırlama, 3, beslenme, 🥣`

## 1. Argümanları ayrıştır (`$ARGUMENTS`, virgülle ayrılmış)

- **ad**: boş olamaz; baş/son boşlukları kırp.
- **zorluk**: 1–10 arası tam sayı. Aralık dışıysa **reddet** — koddaki `sinirla` sessizce sınırlar, ona güvenme.
- **kategori**: `GorevKategorisi` ham değeri veya görünen adı; büyük/küçük harf ve Türkçe karakter duyarsız:
  `bakim` (Bakım), `beslenme` (Beslenme), `uyku` (Uyku), `saglik` (Sağlık), `ev` (Ev İşleri).
  Başka bir değerse geçerli listeyi göstererek reddet.
- **emoji** (isteğe bağlı): verilmediyse uygun bir tane öner; mevcut görevlerde kullanılanlardan kaçın.

Eksik/hatalı argümanda kullanıcıya sor; tahminle ilerleme.

## 2. Kimlik (id) üret

- Türkçe harfleri çevir: ı→i, İ→i, ğ→g, ü→u, ş→s, ö→o, ç→c. Küçük harf, kebab-case, 1–2 kelime
  (mevcutlar gibi: `bez-islak`, `gece-uyanma`). Desen: `^[a-z0-9]+(-[a-z0-9]+)*$`.
- Benzersiz olmalı: `grep -n 'id: "' Sources/EvdeAdaletCore/VarsayilanGorevler.swift` ve geçmişte kullanılmış
  kimlikler için `git log -S'id: "<aday>"' --oneline`.
- **Mevcut bir kimliği asla değiştirme veya silme**: CloudKit kayıt adı `gorev_<id>` olarak telefonlar arasında paylaşılır.

## 3. Koda ekle

`Sources/EvdeAdaletCore/VarsayilanGorevler.swift` içinde ilgili kategori yorum bloğunun **sonuna**, aynı biçimde ekle:

```swift
GorevTuru(id: "<id>", ad: "<ad>", emoji: "<emoji>", kategori: .<kategori>, zorluk: <z>),
```

Dizinin son elemanında virgül kuralına dikkat et (son eleman virgülsüz).

## 4. README tablosu

`README.md` → "Varsayılan zorluk puanları" tablosunda aynı kategori sırasına satır ekle:

```
| <emoji> <ad> | <z> | <z*10> | <Int((z*10*1.5).rounded())> |
```

Örnek: zorluk 7 → `| … | 7 | 70 | 105 |`; zorluk 3 → `| … | 3 | 30 | 45 |`.

## 5. Test

`Tests/EvdeAdaletCoreTests/EvdeAdaletCoreTests.swift` içine, yeni görevin varlığını, kategorisini ve zorluğunu
doğrulayan bir test ekle. Görev sayısına bağlı testler (`SenkronTests.testKayitAdlariVeTurleri`) listeyi otomatik
izler; sabit sayı güncellemeye gerek yok.

## 6. Doğrula ve raporla

1. `swift test` — yeşil olmalı.
2. `git diff` özetini göster.
3. Kullanıcıya hatırlat: mevcut telefonlar yeni görevi uygulama güncellenince alır; eşitleme sayesinde iki telefon da
   görür ve düzenlenmemiş varsayılanlar asla düzenlenmiş değerleri ezmez.
4. Commit/push ve iOS derlemesi için `/ios-derle` öner.

Varsayılan görev silmek bu skill'in kapsamı dışındadır (kimlik kalıcılığı nedeniyle önerilmez).
