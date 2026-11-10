---
name: ios-derle
description: Değişiklikleri commit+push edip GitHub Actions'ta (bulut Mac) iOS derlemesini izler; hata varsa düzeltip yeşil olana kadar tekrarlar. Kullanıcı "iOS'ta derle", "CI'yı kontrol et", "Actions yeşil mi", "derleme geçti mi" dediğinde veya EvdeAdalet/ ya da project.yml değiştiğinde kullan.
argument-hint: "[commit mesajı]"
allowed-tools: Bash, Read, Edit, Grep, Glob, mcp__github__actions_list, mcp__github__actions_get, mcp__github__get_job_logs, mcp__github__actions_run_trigger
---

# /ios-derle — Mac olmadan iOS derlemesi

Linux'ta iOS uygulaması (SwiftUI, CloudKit) derlenemez. Tek doğrulama yolu `.github/workflows/ios.yml` iş akışının
"Test ve derleme" işidir. Depo: `esractn89-beep/ev-uygulama` (herkese açık).

```bash
API=https://api.github.com/repos/esractn89-beep/ev-uygulama
```

## 1. Ön kontrol

1. `swift test` — kırmızıysa dur, önce düzelt.
2. `git status` — dosyaları **adlarıyla** ekle (`git add <dosya>`); `.build/`, `Destek/`, `*.xcodeproj` gibi üretilmiş
   dosyaları ekleme.
3. Commit mesajı Türkçe olsun. `$ARGUMENTS` verildiyse onu kullan.

## 2. Push

- `git push -u origin <geçerli dal>`. Yalnızca ağ hatasında 4 kez yeniden dene (2, 4, 8, 16 sn bekleyerek).
- `SHA=$(git rev-parse HEAD)`
- Asla `--force` veya `--no-verify` kullanma.

## 3. Çalışmayı (run) bul

Run'ın görünmesi 10–60 sn sürebilir; arka planda bekle:

```bash
until RUN_ID=$(curl -s "$API/actions/runs?head_sha=$SHA&event=push" | jq -r '.workflow_runs[0].id // empty') && [ -n "$RUN_ID" ]; do sleep 15; done; echo $RUN_ID
```

## 4. Bekle

Bash'i `run_in_background: true` ve ~40 dk zaman aşımıyla çalıştır; **asla ön planda `sleep` kullanma**:

```bash
until [ "$(curl -s $API/actions/runs/$RUN_ID | jq -r .status)" = completed ]; do sleep 60; done
curl -s $API/actions/runs/$RUN_ID | jq '{conclusion, html_url}'
```

Kimliksiz API sınırı saatte 60 istektir; 30–60 sn aralıkla sorgula ya da MCP araçlarını (`mcp__github__actions_get`) kullan.

## 5. Sonucu sınıflandır

```bash
curl -s $API/actions/runs/$RUN_ID/jobs | jq '.jobs[] | {id, name, conclusion, steps: [.steps[] | {name, conclusion}]}'
curl -s $API/check-runs/<job_id>/annotations | jq -r '.[] | "\(.annotation_level): \(.message)"'
```

| Durum | Belirti | Yapılacak |
|---|---|---|
| ✅ Başarılı | `conclusion: success` | Rapora geç. |
| ⏳ Kapasite | `cancelled`, hiç adım yok, not: "not acquired by Runner" | Kod değiştirme. `mcp__github__actions_run_trigger` → `rerun_failed_jobs`. İkinci kez olursa kullanıcıya depo değişkeni `MACOS_RUNNER`'ı değiştirmesini öner (`macos-15-intel` ↔ `macos-15`). |
| ↪️ Yerine geçildi | `cancelled`, daha yeni bir push var (concurrency) | Yeni run'ı izle. |
| ❌ Hata | `failure` | 6. adım. |

## 6. Düzelt

1. `mcp__github__get_job_logs` (`run_id`, `failed_only: true`, `return_content: true`, `tail_lines: 300`).
2. `error:` ve `BUILD FAILED` satırlarını bul, `dosya:satır` ile eşle. Not: derleme adımı çıktıyı `grep ... || true`
   ile süzer ve sonra `BUILD SUCCEEDED` arar; asıl hata bundan önceki satırlardadır. Test adımı başarısızsa `swift test`
   çıktısına bak.
3. En küçük düzeltmeyi yap. Linux iOS hatalarını yakalayamaz; iOS 17 API'lerini dikkatle düşün.
4. `swift test` → commit (`CI: <ne> düzelt`) → push → 3. adıma dön.
5. **En fazla 5 deneme**; sonra dur ve kullanıcıya durumu açıkla.

İş akışını sırf yeşil olsun diye değiştirme (adım atlamak, hatayı yutmak yasak).

## 7. Rapor (Türkçe)

- SHA, run bağlantısı (`html_url`), deneme sayısı
- Düzeltilen hatalar (`dosya:satır` — kısa açıklama)
- Sonuç: ✅ derlendi / ❌ hâlâ hata var / ⏳ kapasite nedeniyle çalışmadı

TestFlight yüklemesini (`workflow_dispatch`, `testflight=true`) yalnızca kullanıcı isterse öner veya başlat.
