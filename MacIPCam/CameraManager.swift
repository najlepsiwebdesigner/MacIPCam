import AVFoundation
import Combine

class CameraManager: ObservableObject {
    @Published var cameras: [AVCaptureDevice] = []
    @Published var microphones: [AVCaptureDevice] = []
    @Published var selectedCameraIndex: Int = 0
    @Published var selectedMicIndex: Int = 0

    init() {
        refresh()
    }

    func refresh() {
        let videoSession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
            mediaType: .video,
            position: .unspecified
        )
        cameras = videoSession.devices

        let audioSession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInMicrophone, .externalUnknown],
            mediaType: .audio,
            position: .unspecified
        )
        microphones = audioSession.devices

        // Auto-select FaceTime HD Camera
        if let idx = cameras.firstIndex(where: { $0.localizedName.contains("FaceTime") }) {
            selectedCameraIndex = idx
        }
        // Auto-select MacBook Pro Microphone
        if let idx = microphones.firstIndex(where: { $0.localizedName.contains("MacBook Pro Microphone") }) {
            selectedMicIndex = idx
        }
    }
}
