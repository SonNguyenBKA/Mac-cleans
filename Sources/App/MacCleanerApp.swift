import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        model.fans.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.fans.prepareForQuit()
    }
}

@main
struct MacCleanerApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView(model: delegate.model)
                .frame(minWidth: 960, minHeight: 640)
        }
        .windowStyle(.hiddenTitleBar)

        MenuBarExtra {
            MenuBarContent(model: delegate.model.fans)
        } label: {
            MenuBarLabel(model: delegate.model.fans)
        }
    }
}
