import SwiftUI

@main
struct BebekPuanApp: App {
    @State private var store = AileStore()

    var body: some Scene {
        WindowGroup {
            AnaGorunum()
                .environment(store)
        }
    }
}
