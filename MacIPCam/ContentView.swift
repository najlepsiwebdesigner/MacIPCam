import SwiftUI
import AppKit
import IOKit.pwr_mgt

struct ContentView: View {
    @StateObject private var cameras = CameraManager()
    @ObservedObject var streamManager: StreamManager
    @State private var sleepAssertionID: IOPMAssertionID = 0
    @State private var preventSleep = true

    private func setSleepPrevention(_ enabled: Bool) {
        if enabled {
            IOPMAssertionCreateWithName(
                kIOPMAssertionTypeNoDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "Mac IP Cam streaming" as CFString,
                &sleepAssertionID
            )
        } else {
            IOPMAssertionRelease(sleepAssertionID)
            sleepAssertionID = 0
        }
        preventSleep = enabled
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            // ── Device pickers ──────────────────────────────────────────
            GroupBox("Devices") {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("Camera", selection: $cameras.selectedCameraIndex) {
                        ForEach(cameras.cameras.indices, id: \.self) { i in
                            Text(cameras.cameras[i].localizedName).tag(i)
                        }
                    }

                    Picker("Microphone", selection: $cameras.selectedMicIndex) {
                        ForEach(cameras.microphones.indices, id: \.self) { i in
                            Text(cameras.microphones[i].localizedName).tag(i)
                        }
                        Text("No audio").tag(-1)
                    }
                }
                .padding(4)
            }

            // ── Options ──────────────────────────────────────────────────
            Toggle(isOn: Binding(
                get: { preventSleep },
                set: { setSleepPrevention($0) }
            )) {
                Label("Prevent sleep & screen saver", systemImage: preventSleep ? "moon.zzz.fill" : "moon.zzz")
            }
            .toggleStyle(.checkbox)

            // ── Stream control ──────────────────────────────────────────
            GroupBox("Stream") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Circle()
                            .fill(streamManager.isStreaming ? Color.green : Color.gray)
                            .frame(width: 10, height: 10)
                        Text(streamManager.statusMessage)
                            .foregroundColor(streamManager.isStreaming ? .primary : .secondary)
                    }

                    HStack {
                        Button(streamManager.isStreaming ? "Stop" : "Start") {
                            if streamManager.isStreaming {
                                streamManager.stop()
                            } else {
                                streamManager.start(
                                    cameraIndex: cameras.selectedCameraIndex,
                                    micIndex: cameras.selectedMicIndex,
                                    includeAudio: cameras.selectedMicIndex >= 0
                                )
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(streamManager.isStreaming ? .red : .accentColor)
                    }

                    if streamManager.isStreaming {
                        Divider()

                        VStack(alignment: .leading, spacing: 6) {
                            Text("RTSP URL").font(.caption).foregroundColor(.secondary)
                            Text(streamManager.rtspURL)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)

                            Button("Copy URL") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(streamManager.rtspURL, forType: .string)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding(4)
            }
        }
        .padding(20)
        .frame(minWidth: 380, idealWidth: 420)
        .onAppear {
            streamManager.killStaleBinaries()
            // Activate assertion to match the default checked state
            IOPMAssertionCreateWithName(
                kIOPMAssertionTypeNoDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "Mac IP Cam streaming" as CFString,
                &sleepAssertionID
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            if preventSleep { setSleepPrevention(false) }
            streamManager.stop()
            streamManager.killStaleBinaries()
        }
    }
}

#Preview {
    ContentView(streamManager: StreamManager())
}
