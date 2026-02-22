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

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Called by Cmd+Q — window is still open, safe to show alert
        return confirmQuit() ? .terminateNow : .terminateCancel
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Called when the red X is clicked — intercept before window closes
        if confirmQuit() {
            NSApplication.shared.terminate(nil)
        }
        return false  // Never let the window close on its own
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
