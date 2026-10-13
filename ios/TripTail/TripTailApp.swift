import SwiftUI

@main
struct TripTailApp: App {
    @State private var library = DraftLibrary()
    var body: some Scene {
        WindowGroup {
            TabView {
                NavigationStack { ComposerView(library: library) }
                    .tabItem { Label("새 여행", systemImage: "square.and.pencil") }
                NavigationStack { LibraryView(library: library) }
                    .tabItem { Label("여행 보관함", systemImage: "books.vertical") }
                NavigationStack { PrivacyView() }
                    .tabItem { Label("안내", systemImage: "info.circle") }
            }
            .tint(Color(red: 0.19, green: 0.36, blue: 0.29))
            .preferredColorScheme(.light)
        }
    }
}
