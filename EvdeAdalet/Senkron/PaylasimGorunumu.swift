import CloudKit
import SwiftUI
import UIKit

/// Apple'ın standart "kişi davet et / paylaşımı yönet" ekranı.
struct PaylasimGorunumu: UIViewControllerRepresentable {
    let paylasim: CKShare
    let konteyner: CKContainer
    let paylasimDurdu: () -> Void

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let denetleyici = UICloudSharingController(share: paylasim, container: konteyner)
        denetleyici.availablePermissions = [.allowPrivate, .allowReadWrite]
        denetleyici.delegate = context.coordinator
        denetleyici.modalPresentationStyle = .formSheet
        return denetleyici
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    func makeCoordinator() -> Koordinator { Koordinator(paylasim: paylasim, paylasimDurdu: paylasimDurdu) }

    final class Koordinator: NSObject, UICloudSharingControllerDelegate {
        let paylasim: CKShare
        let paylasimDurdu: () -> Void

        init(paylasim: CKShare, paylasimDurdu: @escaping () -> Void) {
            self.paylasim = paylasim
            self.paylasimDurdu = paylasimDurdu
        }

        func itemTitle(for csc: UICloudSharingController) -> String? {
            paylasim[CKShare.SystemFieldKey.title] as? String ?? "Evde Adalet"
        }

        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            print("Paylaşım kaydedilemedi: \(error)")
        }

        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            paylasimDurdu()
        }
    }
}
