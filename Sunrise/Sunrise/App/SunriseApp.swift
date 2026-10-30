import SwiftUI

@main
struct SunriseApp: App {
    @State private var model = SunriseModel()

    var body: some Scene {
        WindowGroup {
            // Unit tests run inside the app; keep HomeKit's permission prompt out of them.
            if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
                ContentView()
                    .environment(model)
            } else {
                Text("Running tests")
            }
        }
    }
}
