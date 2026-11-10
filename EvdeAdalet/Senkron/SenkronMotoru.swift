import CloudKit
import Foundation
import Observation
import EvdeAdaletCore

/// İki telefon arasında iCloud (CloudKit) eşitlemesi.
///
/// - Aileyi kuran kişi verileri kendi iCloud'undaki özel "Aile" bölgesinde tutar.
/// - "Eşimi davet et" ile bu bölge bir `CKShare` ile paylaşılır.
/// - Eşi daveti kabul edince kendi telefonundaki kayıtlar paylaşılan bölgeye eklenir
///   ve iki telefon aynı veriyi görür.
///
/// Her öğe (görev kaydı, görev türü, ebeveyn, ayarlar) ayrı bir CloudKit kaydıdır.
/// Değişiklikleri göndermeyi / almayı `CKSyncEngine` yönetir.
@MainActor
@Observable
final class SenkronMotoru {
    /// `iCloud.<paket kimliği>`; project.yml'deki Info.plist ayarından okunur.
    static let konteynerKimligi = Bundle.main.object(forInfoDictionaryKey: "CloudKitKonteyneri") as? String
        ?? "iCloud.\(Bundle.main.bundleIdentifier ?? "com.example.evdeadalet")"
    static let bolgeAdi = "Aile"
    static let veriAlani = "veri"

    enum Kapsam: Codable, Equatable {
        /// Kendi iCloud'umdaki aile (ben kurdum).
        case ozel
        /// Eşimin paylaştığı aileye katıldım.
        case paylasilan(bolgeAdi: String, sahip: String)
    }

    enum Durum: Equatable {
        case hazirlaniyor
        case esitlendi(Date)
        case esitleniyor
        case iCloudYok
        case hata(String)

        var aciklama: String {
            switch self {
            case .hazirlaniyor: return "Hazırlanıyor…"
            case .esitlendi(let t): return "Eşitlendi · \(t.formatted(date: .omitted, time: .shortened))"
            case .esitleniyor: return "Eşitleniyor…"
            case .iCloudYok: return "iCloud'a giriş yapılmamış. Ayarlar > [adınız] > iCloud bölümünden giriş yapın."
            case .hata(let mesaj): return "Hata: \(mesaj)"
            }
        }
    }

    /// Diskte saklanan eşitleme bilgileri.
    private struct Kalici: Codable {
        var kapsam: Kapsam = .ozel
        var motorDurumu: CKSyncEngine.State.Serialization?
        /// recordName → sunucudaki son kaydın sistem alanları (çakışma önlemek için).
        var sistemAlanlari: [String: Data] = [:]
        var ilkGonderimYapildi = false
        var paylasimVar = false
    }

    private(set) var durum: Durum = .hazirlaniyor
    var kapsam: Kapsam { kalici.kapsam }
    var paylasimVar: Bool { kalici.paylasimVar || kalici.kapsam != .ozel }

    @ObservationIgnored private unowned let store: AileStore
    @ObservationIgnored private let konteyner = CKContainer(identifier: SenkronMotoru.konteynerKimligi)
    @ObservationIgnored private var motor: CKSyncEngine?
    @ObservationIgnored private var kalici: Kalici
    @ObservationIgnored private let dosyaURL = URL.documentsDirectory.appending(path: "senkron-durumu.json")

    init(store: AileStore) {
        self.store = store
        if let veri = try? Data(contentsOf: dosyaURL), let k = try? JSONDecoder().decode(Kalici.self, from: veri) {
            kalici = k
        } else {
            kalici = Kalici()
        }
        motoruKur()
        Task { await hesapDurumunuDenetle() }
    }

    // MARK: - Kapsam

    private var veritabani: CKDatabase {
        switch kalici.kapsam {
        case .ozel: return konteyner.privateCloudDatabase
        case .paylasilan: return konteyner.sharedCloudDatabase
        }
    }

    private var bolgeKimligi: CKRecordZone.ID {
        switch kalici.kapsam {
        case .ozel: return CKRecordZone.ID(zoneName: Self.bolgeAdi, ownerName: CKCurrentUserDefaultName)
        case .paylasilan(let bolgeAdi, let sahip): return CKRecordZone.ID(zoneName: bolgeAdi, ownerName: sahip)
        }
    }

    private func motoruKur() {
        let ayar = CKSyncEngine.Configuration(
            database: veritabani,
            stateSerialization: kalici.motorDurumu,
            delegate: self
        )
        motor = CKSyncEngine(ayar)

        if !kalici.ilkGonderimYapildi {
            // İlk açılışta (veya bir aileye yeni katılınca) tüm yerel veriyi buluta gönder.
            if case .ozel = kalici.kapsam {
                motor?.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: bolgeKimligi))])
            }
            tumunuGonderimeEkle()
            kalici.ilkGonderimYapildi = true
            kaydet()
        }
    }

    private func kapsamiDegistir(_ yeni: Kapsam) {
        kalici.kapsam = yeni
        kalici.motorDurumu = nil
        kalici.sistemAlanlari = [:]
        kalici.ilkGonderimYapildi = false
        kalici.paylasimVar = false
        kaydet()
        motoruKur()
    }

    private func tumunuGonderimeEkle() {
        let adlar = store.durum.senkronDegerleri().keys
        motor?.state.add(pendingRecordZoneChanges: adlar.map { .saveRecord(kayitKimligi($0)) })
    }

    private func kayitKimligi(_ ad: String) -> CKRecord.ID {
        CKRecord.ID(recordName: ad, zoneID: bolgeKimligi)
    }

    private func hesapDurumunuDenetle() async {
        do {
            let hesap = try await konteyner.accountStatus()
            if hesap != .available { durum = .iCloudYok }
        } catch {
            durum = .hata(error.localizedDescription)
        }
    }

    // MARK: - Dışarıya açık işlemler

    /// `AileStore` yerel bir değişiklik yaptığında çağrılır.
    func yerelDegisiklikler(kaydedilecek: Set<String>, silinecek: Set<String>) {
        var degisiklikler: [CKSyncEngine.PendingRecordZoneChange] = []
        degisiklikler += kaydedilecek.map { .saveRecord(kayitKimligi($0)) }
        degisiklikler += silinecek.map { .deleteRecord(kayitKimligi($0)) }
        for ad in silinecek { kalici.sistemAlanlari[ad] = nil }
        motor?.state.add(pendingRecordZoneChanges: degisiklikler)
    }

    /// Uygulama öne geldiğinde / kullanıcı aşağı çektiğinde.
    func simdiEsitle() async {
        guard let motor else { return }
        do {
            try await motor.fetchChanges()
            try await motor.sendChanges()
            durum = .esitlendi(Date())
        } catch {
            durum = .hata(error.localizedDescription)
        }
    }

    /// Eşi davet etmek için paylaşımı hazırlar (yoksa oluşturur).
    func paylasimiHazirla() async throws -> (CKShare, CKContainer) {
        let paylasimKimligi = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: bolgeKimligi)

        if case .paylasilan = kalici.kapsam {
            // Katılımcı: mevcut paylaşımı göster (buradan ayrılabilir).
            guard let paylasim = try await veritabani.record(for: paylasimKimligi) as? CKShare else {
                throw CKError(.unknownItem)
            }
            return (paylasim, konteyner)
        }

        let db = konteyner.privateCloudDatabase
        _ = try await db.modifyRecordZones(saving: [CKRecordZone(zoneID: bolgeKimligi)], deleting: [])

        if let mevcut = try? await db.record(for: paylasimKimligi) as? CKShare {
            kalici.paylasimVar = true
            kaydet()
            return (mevcut, konteyner)
        }

        let paylasim = CKShare(recordZoneID: bolgeKimligi)
        paylasim[CKShare.SystemFieldKey.title] = "Evde Adalet – \(store.durum.bebekAdi)" as CKRecordValue
        paylasim.publicPermission = .none
        let sonuc = try await db.modifyRecords(saving: [paylasim], deleting: [])
        let kaydedilen = try sonuc.saveResults[paylasimKimligi]?.get() as? CKShare
        kalici.paylasimVar = true
        kaydet()
        return (kaydedilen ?? paylasim, konteyner)
    }

    /// Eşin gönderdiği daveti kabul eder ve paylaşılan aileye geçer.
    func paylasimiKabulEt(_ metadata: CKShare.Metadata) async {
        do {
            _ = try await konteyner.accept(metadata)
            let bolge = metadata.share.recordID.zoneID
            kapsamiDegistir(.paylasilan(bolgeAdi: bolge.zoneName, sahip: bolge.ownerName))
            await simdiEsitle()
        } catch {
            durum = .hata("Davet kabul edilemedi: \(error.localizedDescription)")
        }
    }

    /// Paylaşım kapatıldığında (sahip durdurdu veya ben ayrıldım).
    func paylasimSonaErdi() {
        if case .paylasilan = kalici.kapsam {
            kapsamiDegistir(.ozel)
        } else {
            kalici.paylasimVar = false
            kaydet()
        }
    }

    // MARK: - Kayıt dönüşümleri

    fileprivate func bulutKaydi(_ kimlik: CKRecord.ID) -> CKRecord? {
        let ad = kimlik.recordName
        guard let oge = store.durum.senkronOgesi(ad: ad) else {
            // Gönderilmeyi beklerken silinmiş.
            motor?.state.remove(pendingRecordZoneChanges: [.saveRecord(kimlik)])
            return nil
        }
        let kayit: CKRecord
        if let alanlar = kalici.sistemAlanlari[ad], let eski = Self.sistemAlanlariniCoz(alanlar) {
            kayit = eski
        } else {
            kayit = CKRecord(recordType: oge.tur.rawValue, recordID: kimlik)
        }
        kayit[Self.veriAlani] = oge.veri as CKRecordValue
        return kayit
    }

    private func ogeye(_ kayit: CKRecord) -> SenkronOgesi? {
        guard let tur = SenkronTuru(rawValue: kayit.recordType),
              let veri = kayit[Self.veriAlani] as? Data else { return nil }
        return SenkronOgesi(tur: tur, ad: kayit.recordID.recordName, veri: veri)
    }

    private func sistemAlanlariniSakla(_ kayit: CKRecord) {
        let kodlayici = NSKeyedArchiver(requiringSecureCoding: true)
        kayit.encodeSystemFields(with: kodlayici)
        kodlayici.finishEncoding()
        kalici.sistemAlanlari[kayit.recordID.recordName] = kodlayici.encodedData
    }

    private static func sistemAlanlariniCoz(_ veri: Data) -> CKRecord? {
        guard let cozucu = try? NSKeyedUnarchiver(forReadingFrom: veri) else { return nil }
        cozucu.requiresSecureCoding = true
        defer { cozucu.finishDecoding() }
        return CKRecord(coder: cozucu)
    }

    private func kaydet() {
        do {
            try JSONEncoder().encode(kalici).write(to: dosyaURL, options: .atomic)
        } catch {
            print("Eşitleme durumu kaydedilemedi: \(error)")
        }
    }

    // MARK: - Olaylar

    fileprivate func isle(_ olay: CKSyncEngine.Event) {
        switch olay {
        case .stateUpdate(let e):
            kalici.motorDurumu = e.stateSerialization
            kaydet()

        case .accountChange(let e):
            switch e.changeType {
            case .signIn:
                durum = .hazirlaniyor
                kalici.sistemAlanlari = [:]
                if case .ozel = kalici.kapsam {
                    motor?.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: bolgeKimligi))])
                }
                tumunuGonderimeEkle()
            case .signOut, .switchAccounts:
                // Veriler telefonda kalır; yeni hesapta özel aile olarak yeniden başla.
                durum = .iCloudYok
                kapsamiDegistir(.ozel)
            @unknown default:
                break
            }

        case .fetchedDatabaseChanges(let e):
            if e.deletions.contains(where: { $0.zoneID == bolgeKimligi }) {
                // Bölge silindi: paylaşım sona erdi veya kullanıcı iCloud verilerini sildi.
                paylasimSonaErdi()
                if case .ozel = kalici.kapsam {
                    kalici.sistemAlanlari = [:]
                    motor?.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: bolgeKimligi))])
                    tumunuGonderimeEkle()
                }
            }

        case .fetchedRecordZoneChanges(let e):
            var degisenler: [SenkronOgesi] = []
            for degisiklik in e.modifications where degisiklik.record.recordID.zoneID == bolgeKimligi {
                let kayit = degisiklik.record
                if kayit is CKShare {
                    kalici.paylasimVar = true
                    continue
                }
                sistemAlanlariniSakla(kayit)
                if let oge = ogeye(kayit) { degisenler.append(oge) }
            }
            let silinenler = e.deletions
                .filter { $0.recordID.zoneID == bolgeKimligi }
                .map(\.recordID.recordName)
            for ad in silinenler { kalici.sistemAlanlari[ad] = nil }
            store.uzaktanUygula(degisenler: degisenler, silinenler: silinenler)
            kaydet()

        case .sentRecordZoneChanges(let e):
            for kayit in e.savedRecords { sistemAlanlariniSakla(kayit) }
            var yenidenGonder: [CKSyncEngine.PendingRecordZoneChange] = []
            for basarisiz in e.failedRecordSaves {
                let kimlik = basarisiz.record.recordID
                let ad = kimlik.recordName
                switch basarisiz.error.code {
                case .serverRecordChanged:
                    // Diğer telefon aynı öğeyi değiştirmiş: birleştir, gerekiyorsa tekrar gönder.
                    guard let sunucu = basarisiz.error.serverRecord else { break }
                    sistemAlanlariniSakla(sunucu)
                    if let oge = ogeye(sunucu) {
                        store.uzaktanUygula(degisenler: [oge], silinenler: [])
                        if store.durum.senkronOgesi(ad: ad)?.veri != oge.veri {
                            yenidenGonder.append(.saveRecord(kimlik))
                        }
                    }
                case .zoneNotFound:
                    if case .ozel = kalici.kapsam {
                        motor?.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: bolgeKimligi))])
                    }
                    kalici.sistemAlanlari[ad] = nil
                    yenidenGonder.append(.saveRecord(kimlik))
                case .unknownItem:
                    kalici.sistemAlanlari[ad] = nil
                    yenidenGonder.append(.saveRecord(kimlik))
                case .networkFailure, .networkUnavailable, .zoneBusy, .serviceUnavailable,
                     .notAuthenticated, .operationCancelled, .requestRateLimited:
                    break // CKSyncEngine kendisi tekrar dener.
                case .quotaExceeded:
                    durum = .hata("iCloud depolama alanı dolu.")
                default:
                    durum = .hata(basarisiz.error.localizedDescription)
                }
            }
            if !yenidenGonder.isEmpty {
                motor?.state.add(pendingRecordZoneChanges: yenidenGonder)
            }
            kaydet()

        case .willFetchChanges, .willSendChanges:
            if durum != .iCloudYok { durum = .esitleniyor }

        case .didFetchChanges, .didSendChanges:
            if case .esitleniyor = durum { durum = .esitlendi(Date()) }

        default:
            break
        }
    }
}

// MARK: - CKSyncEngineDelegate

extension SenkronMotoru: CKSyncEngineDelegate {
    nonisolated func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        await isle(event)
    }

    nonisolated func nextRecordZoneChangeBatch(
        _ context: CKSyncEngine.SendChangesContext,
        syncEngine: CKSyncEngine
    ) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let kapsam = context.options.scope
        let bekleyenler = syncEngine.state.pendingRecordZoneChanges.filter { kapsam.contains($0) }
        guard !bekleyenler.isEmpty else { return nil }
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: bekleyenler) { kimlik in
            await self.bulutKaydi(kimlik)
        }
    }
}
