import SwiftUI
import AppKit
import IOKit.pwr_mgt

struct ContentView: View {
    @StateObject private var cameras = CameraManager()
    @ObservedObject var streamManager: StreamManager
    var appDelegate: AppDelegate
    @State private var sleepAssertionID: IOPMAssertionID = 0
    @State private var preventSleep = true

    // ── Screen light ────────────────────────────────────────────────────
    @State private var screenLight = false
    @State private var intensity: Double = 1.0
    @State private var temperature: Double = 0.5   // 0 = warm, 1 = cool
    @State private var savedWindowFrame: NSRect? = nil

    private var lightColor: Color {
        // 0 = ~2700K warm (255, 197, 143), 1 = ~6500K cool white (255, 255, 255)
        let r = 1.0
        let g = 0.773 + temperature * 0.227
        let b = 0.561 + temperature * 0.439
        return Color(red: r * intensity, green: g * intensity, blue: b * intensity)
    }

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

    private func applyScreenLight(_ enabled: Bool, window: NSWindow?) {
        guard let window else { return }
        if enabled {
            savedWindowFrame = window.frame
            let sf = (window.screen ?? NSScreen.main!).frame
            window.setFrame(sf, display: true, animate: false)
        } else {
            if let saved = savedWindowFrame {
                window.setFrame(saved, display: true, animate: false)
            }
        }
    }

    var body: some View {
        ZStack {
            // ── Light background ─────────────────────────────────────────
            if screenLight {
                lightColor
                    .ignoresSafeArea()
            }

            // ── Main content — always fixed width, always centered ────────
            VStack {
                if screenLight { Spacer() }

                VStack(alignment: .leading, spacing: 16) {

                    // ── Device pickers ───────────────────────────────────
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

                    // ── Options ──────────────────────────────────────────
                    Toggle(isOn: Binding(
                        get: { preventSleep },
                        set: { setSleepPrevention($0) }
                    )) {
                        Label("Prevent sleep & screen saver", systemImage: preventSleep ? "moon.zzz.fill" : "moon.zzz")
                    }
                    .toggleStyle(.checkbox)

                    // ── Screen light ──────────────────────────────────────
                    GroupBox("Screen light") {
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle(isOn: $screenLight) {
                                Label("Enable", systemImage: screenLight ? "sun.max.fill" : "sun.max")
                            }
                            .toggleStyle(.checkbox)

                            if screenLight {
                                HStack {
                                    Text("Intensity").frame(width: 90, alignment: .leading)
                                    Slider(value: $intensity, in: 0...1)
                                }
                                HStack {
                                    Text("Temperature").frame(width: 90, alignment: .leading)
                                    Slider(value: $temperature, in: 0...1)
                                }
                                HStack(spacing: 6) {
                                    Text("Warm").font(.caption).foregroundColor(.secondary)
                                    Spacer()
                                    Text("Cool").font(.caption).foregroundColor(.secondary)
                                }
                                .padding(.leading, 96)
                            }
                        }
                        .padding(4)
                    }

                    // ── Stream control ────────────────────────────────────
                    GroupBox("Stream") {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Circle()
                                    .fill(streamManager.isStreaming ? Color.green : Color.gray)
                                    .frame(width: 10, height: 10)
                                Text(streamManager.statusMessage)
                                    .foregroundColor(streamManager.isStreaming ? .primary : .secondary)
                            }

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
                .frame(width: 420)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: screenLight ? 16 : 0))
                .padding(screenLight ? 20 : 0)

                if screenLight { Spacer() }
            }
        }
        .background(WindowAccessor(
            callback: { window in
                appDelegate.window = window
                window.delegate = appDelegate
            },
            onScreenLight: { window, enabled in
                applyScreenLight(enabled, window: window)
            },
            screenLight: screenLight
        ))
        .onAppear {
            streamManager.killStaleBinaries()
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
    ContentView(streamManager: StreamManager(), appDelegate: AppDelegate())
}
