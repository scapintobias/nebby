import SwiftUI

@main
struct MyApp: App {
    @StateObject private var selection = ParentSelection()

    var body: some Scene {
        WindowGroup {
            ContentView(selection: selection)
        }
        .defaultSize(width: 390, height: 510)
    }
}
