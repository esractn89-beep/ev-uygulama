import SwiftUI

struct AnaGorunum: View {
    var body: some View {
        TabView {
            BugunGorunumu()
                .tabItem { Label("Görevler", systemImage: "checklist") }
            SkorGorunumu()
                .tabItem { Label("Skor", systemImage: "trophy.fill") }
            GecmisGorunumu()
                .tabItem { Label("Geçmiş", systemImage: "clock.arrow.circlepath") }
            AyarlarGorunumu()
                .tabItem { Label("Ayarlar", systemImage: "gearshape.fill") }
        }
    }
}

#Preview {
    AnaGorunum()
        .environment(AileStore(dosyaURL: FileManager.default.temporaryDirectory.appending(path: "onizleme.json")))
}
