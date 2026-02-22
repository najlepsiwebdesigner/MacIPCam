import SwiftUI

@main
struct MacIPCamApp: App {
    @StateObject private var streamManager = StreamManager()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView(streamManager: streamManager, appDelegate: appDelegate)
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    weak var window: NSWindow?
    private var userConfirmedQuit = false

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if userConfirmedQuit { return .terminateNow }
        return confirmQuit() ? .terminateNow : .terminateCancel
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if confirmQuit() {
            userConfirmedQuit = true
            NSApplication.shared.terminate(nil)
        }
        return false
    }

    private func confirmQuit() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Quit Mac IP Cam?"
        alert.informativeText = "The stream will be stopped."
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        return alert.runModal() == .alertFirstButtonReturn
    }
}

/// Gives access to the underlying NSWindow from SwiftUI.
/// Fires onScreenLight only when the screenLight value actually changes.
struct WindowAccessor: NSViewRepresentable {
    let callback: (NSWindow) -> Void
    let onScreenLight: (NSWindow, Bool) -> Void
    let screenLight: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                self.callback(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard context.coordinator.lastScreenLight != screenLight else { return }
        context.coordinator.lastScreenLight = screenLight
        DispatchQueue.main.async {
            if let window = nsView.window {
                self.onScreenLight(window, self.screenLight)
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        var lastScreenLight: Bool? = nil
    }
}
