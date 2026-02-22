import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var cameras = CameraManager()
    @StateObject private var stream = StreamManager()

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
                    }
                }
                .padding(4)
            }

            // ── Stream control ──────────────────────────────────────────
            GroupBox("Stream") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Circle()
                            .fill(stream.isStreaming ? Color.green : Color.gray)
                            .frame(width: 10, height: 10)
                        Text(stream.statusMessage)
                            .foregroundColor(stream.isStreaming ? .primary : .secondary)
                    }

                    Button(stream.isStreaming ? "Stop" : "Start") {
                        if stream.isStreaming {
                            stream.stop()
                        } else {
                            stream.start(
                                cameraIndex: cameras.selectedCameraIndex,
                                micIndex: cameras.selectedMicIndex
                            )
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(stream.isStreaming ? .red : .accentColor)

                    if stream.isStreaming {
                        Divider()

                        VStack(alignment: .leading, spacing: 6) {
                            Text("RTSP URL").font(.caption).foregroundColor(.secondary)
                            Text(stream.rtspURL)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)

                            Button("Copy URL") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(stream.rtspURL, forType: .string)
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
    }
}

#Preview {
    ContentView()
}
