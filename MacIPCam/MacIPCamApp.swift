import SwiftUI

@main
struct MacIPCamApp: App {
    @StateObject private var streamManager = StreamManager()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView(streamManager: streamManager)
                .background(WindowAccessor { window in
                    appDelegate.window = window
                    window.delegate = appDelegate
                })
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
struct WindowAccessor: NSViewRepresentable {
    let callback: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                self.callback(window)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
