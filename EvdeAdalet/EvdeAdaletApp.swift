import CloudKit
import SwiftUI
import UIKit

/// Uygulama genelinde tek durum nesnesi (sahne temsilcisi de paylaşım davetleri için erişir).
@MainActor
enum Uygulama {
    static let store = AileStore()
}

@main
struct EvdeAdaletApp: App {
    @UIApplicationDelegateAdaptor(UygulamaTemsilcisi.self) private var temsilci
    @Environment(\.scenePhase) private var sahneDurumu

    var body: some Scene {
        WindowGroup {
            AnaGorunum()
                .environment(Uygulama.store)
        }
        .onChange(of: sahneDurumu) { _, yeni in
            if yeni == .active {
                Task { await Uygulama.store.senkron?.simdiEsitle() }
            }
        }
    }
}

final class UygulamaTemsilcisi: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // CKSyncEngine, diğer telefondaki değişiklikleri sessiz bildirimlerle öğrenir.
        application.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let ayar = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        ayar.delegateClass = SahneTemsilcisi.self
        return ayar
    }
}

/// iCloud paylaşım davetlerini (eşin gönderdiği bağlantı) karşılar.
final class SahneTemsilcisi: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let metadata = connectionOptions.cloudKitShareMetadata {
            kabulEt(metadata)
        }
    }

    func windowScene(_ windowScene: UIWindowScene, userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata) {
        kabulEt(cloudKitShareMetadata)
    }

    private func kabulEt(_ metadata: CKShare.Metadata) {
        Task { @MainActor in
            await Uygulama.store.senkron?.paylasimiKabulEt(metadata)
        }
    }
}
