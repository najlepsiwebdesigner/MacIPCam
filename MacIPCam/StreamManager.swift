import Foundation
import Combine

class StreamManager: ObservableObject {
    @Published var isStreaming = false
    @Published var rtspURL = ""
    @Published var statusMessage = "Stopped"

    private var mediamtxProcess: Process?
    private var ffmpegProcess: Process?
    private var restartTask: Task<Void, Never>?
    private var cameraIndex = 0
    private var micIndex = 0
    private var includeAudio = true

    private let supportDir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("MacIPCam")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    // MARK: - Public

    func start(cameraIndex: Int, micIndex: Int, includeAudio: Bool) {
        self.cameraIndex = cameraIndex
        self.micIndex = micIndex
        self.includeAudio = includeAudio

        guard prepareBinaries() else {
            statusMessage = "Error: could not prepare binaries"
            return
        }

        startMediaMTX()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self else { return }
            self.startFFmpeg()
            let ip = getLanIP()
            self.rtspURL = "rtsp://\(ip):8554/webcam"
            self.isStreaming = true
            self.statusMessage = "Streaming"
        }
    }

    func stop() {
        restartTask?.cancel()
        ffmpegProcess?.terminate()
        mediamtxProcess?.terminate()
        ffmpegProcess = nil
        mediamtxProcess = nil
        isStreaming = false
        rtspURL = ""
        statusMessage = "Stopped"
    }

    deinit {
        killStaleBinaries()
    }

    /// Kill any leftover ffmpeg/mediamtx processes by name.
    func killStaleBinaries() {
        for name in ["ffmpeg", "mediamtx"] {
            let kill = Process()
            kill.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
            kill.arguments = ["-x", name]
            try? kill.run()
            kill.waitUntilExit()
        }
    }

    // MARK: - Private

    private func prepareBinaries() -> Bool {
        let binaries = ["ffmpeg", "mediamtx"]
        for name in binaries {
            guard let src = Bundle.main.url(forResource: name, withExtension: nil) else {
                print("Binary not found in bundle: \(name)")
                return false
            }
            let dst = supportDir.appendingPathComponent(name)
            if !FileManager.default.fileExists(atPath: dst.path) {
                do {
                    try FileManager.default.copyItem(at: src, to: dst)
                } catch {
                    print("Failed to copy \(name): \(error)")
                    return false
                }
            }
            // Ensure executable
            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dst.path)
        }

        // Copy mediamtx.yml
        if let src = Bundle.main.url(forResource: "mediamtx", withExtension: "yml") {
            let dst = supportDir.appendingPathComponent("mediamtx.yml")
            if !FileManager.default.fileExists(atPath: dst.path) {
                try? FileManager.default.copyItem(at: src, to: dst)
            }
        }
        return true
    }

    private func startMediaMTX() {
        let proc = Process()
        proc.executableURL = supportDir.appendingPathComponent("mediamtx")
        proc.arguments = [supportDir.appendingPathComponent("mediamtx.yml").path]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        try? proc.run()
        mediamtxProcess = proc
    }

    private func startFFmpeg() {
        let proc = Process()
        proc.executableURL = supportDir.appendingPathComponent("ffmpeg")
        let input = includeAudio ? "\(cameraIndex):\(micIndex)" : "\(cameraIndex)"
        var args = [
            "-hide_banner", "-loglevel", "error", "-nostats",
            "-f", "avfoundation",
            "-framerate", "30",
            "-video_size", "1280x720",
            "-i", input,
            "-c:v", "libx264",
            "-preset", "ultrafast",
            "-tune", "zerolatency",
        ]
        if includeAudio {
            args += ["-c:a", "aac", "-b:a", "128k"]
        } else {
            args += ["-an"]
        }
        args += ["-f", "rtsp", "-rtsp_transport", "tcp", "rtsp://localhost:8554/webcam"]
        proc.arguments = args
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        try? proc.run()
        ffmpegProcess = proc

        // Auto-restart if ffmpeg dies
        restartTask = Task { [weak self] in
            proc.waitUntilExit()
            guard let self, self.isStreaming, !Task.isCancelled else { return }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { self.statusMessage = "Reconnecting..." }
            self.startFFmpeg()
            await MainActor.run { self.statusMessage = "Streaming" }
        }
    }
}
