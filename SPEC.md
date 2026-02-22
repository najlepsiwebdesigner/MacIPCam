# Mac IP Cam — Specification

## Overview

Mac IP Cam is a native macOS SwiftUI application that exposes the Mac's built-in (or external) webcam as an RTSP stream on the local LAN. Any RTSP-capable client (VLC, ffplay, IP camera apps) can subscribe to the stream by URL.

---

## Current Architecture (v1)

### Technology Stack

| Component | Technology | License |
|---|---|---|
| UI | SwiftUI + AppKit | Apple (proprietary) |
| Device enumeration | AVFoundation | Apple (proprietary) |
| Video capture + encode | ffmpeg (bundled binary) | GPL v2+ |
| RTSP relay server | mediamtx (bundled binary) | MIT |
| LAN IP detection | POSIX `getifaddrs()` via Darwin | LGPL |
| Sleep prevention | IOKit `IOPMAssertionCreateWithName` | Apple (proprietary) |

### Source Files

| File | Role |
|---|---|
| `MacIPCamApp.swift` | App entry point, `AppDelegate` for quit dialog, `WindowAccessor` helper |
| `ContentView.swift` | Main UI — device pickers, options, stream control, URL display |
| `StreamManager.swift` | Launches/manages ffmpeg and mediamtx processes, auto-restart logic |
| `CameraManager.swift` | Enumerates AVFoundation video and audio devices, auto-selects defaults |
| `LanIP.swift` | Detects LAN IPv4 address via `getifaddrs()`, prefers `en0`/`en1` |
| `Resources/ffmpeg` | Bundled ffmpeg binary (430 MB, GPL) |
| `Resources/mediamtx` | Bundled mediamtx binary (29 MB, MIT) |
| `Resources/mediamtx.yml` | mediamtx config: binds all interfaces on port 8554, open auth |

### Startup Sequence

1. App launches → `onAppear` kills any stale `ffmpeg`/`mediamtx` processes (pkill)
2. IOKit sleep prevention assertion activated immediately (default: on)
3. User selects camera and microphone from AVFoundation device lists
4. User clicks **Start**
5. `StreamManager.start()` copies binaries to `~/Library/Application Support/MacIPCam/` if not already present, sets `chmod 755`
6. mediamtx launched with `mediamtx.yml` config
7. After 2-second delay (mediamtx startup), ffmpeg launched
8. LAN IP detected → RTSP URL displayed (`rtsp://<LAN_IP>:8554/webcam`)
9. ffmpeg auto-restarts on crash (2-second cooldown), status shows "Reconnecting..."

### ffmpeg Command

**With audio:**
```
ffmpeg -hide_banner -loglevel error -nostats
  -f avfoundation -framerate 30 -video_size 1280x720
  -i "<camIndex>:<micIndex>"
  -c:v libx264 -preset ultrafast -tune zerolatency
  -c:a aac -b:a 128k
  -f rtsp -rtsp_transport tcp
  rtsp://localhost:8554/webcam
```

**Without audio (No audio selected):**
```
ffmpeg -hide_banner -loglevel error -nostats
  -f avfoundation -framerate 30 -video_size 1280x720
  -i "<camIndex>"
  -c:v libx264 -preset ultrafast -tune zerolatency
  -an
  -f rtsp -rtsp_transport tcp
  rtsp://localhost:8554/webcam
```

### mediamtx Configuration

```yaml
logLevel: info
rtspAddress: :8554          # binds all interfaces, not just localhost
authInternalUsers:
  - user: any
    pass:
    permissions:
      - action: publish
      - action: read
      - action: playback
paths:
  all_others:
```

### UI Layout

```
┌─ Devices ──────────────────────────────────┐
│  Camera:     [ FaceTime HD Camera     ▼ ]  │
│  Microphone: [ MacBook Pro Microphone ▼ ]  │
│                            [ No audio ]    │
└────────────────────────────────────────────┘

☑ Prevent sleep & screen saver

┌─ Stream ───────────────────────────────────┐
│  ● Streaming                               │
│  [ Stop ]                                  │
│  ─────────────────────────────────────     │
│  RTSP URL                                  │
│  rtsp://192.168.1.x:8554/webcam            │
│  [ Copy URL ]                              │
└────────────────────────────────────────────┘
```

### Process Lifecycle

- **On launch:** stale processes killed via `pkill -x ffmpeg` / `pkill -x mediamtx`
- **On Stop button:** `Process.terminate()` called on both, references nilled
- **On window close (red X):** `windowShouldClose` intercepts, shows confirmation alert, calls `NSApplication.terminate` if confirmed
- **On Cmd+Q:** `applicationShouldTerminate` shows same confirmation alert
- **On terminate:** `willTerminateNotification` triggers stream stop, process kill, IOKit assertion release
- **On crash/force quit:** `deinit` on `StreamManager` calls `killStaleBinaries()`

### Device Selection Logic

- `AVCaptureDevice.DiscoverySession` enumerates `.builtInWideAngleCamera` + `.externalUnknown` for video
- `.builtInMicrophone` + `.externalUnknown` for audio
- Auto-selects first device whose `localizedName` contains `"FaceTime"` (camera) and `"MacBook Pro Microphone"` (mic)
- Falls back to index 0 if not found
- Microphone index `-1` = "No audio" (synthetic picker entry, not a real device)

### LAN IP Detection

- Iterates network interfaces via `getifaddrs()` C API
- Prefers `en0` then `en1` (Wi-Fi / Ethernet)
- Filters for `AF_INET` (IPv4) only
- Returns `"unknown"` if no suitable interface found

### Entitlements

```xml
com.apple.security.app-sandbox = NO
com.apple.security.device.camera = YES
com.apple.security.device.microphone = YES
com.apple.security.network.server = YES
com.apple.security.network.client = YES
```

Sandbox is disabled — required to launch child processes (`Process()`).

---

## License Status (Current v1)

| Component | License | Distributable? |
|---|---|---|
| Swift app code | yours (no license set) | yes |
| mediamtx binary | MIT | yes, include LICENSE |
| ffmpeg binary (Homebrew) | **GPL v2+** | only with source / open-source app |

**Current v1 cannot be sold on the Mac App Store** due to:
1. ffmpeg GPL incompatibility with App Store DRM
2. App sandbox prohibition on `Process()` / child executables

**Current v1 can be sold outside the App Store** (direct `.dmg`, Gumroad, Paddle) if:
- The Swift app source is published under GPL (to comply with ffmpeg GPL)
- ffmpeg and mediamtx license files are bundled

---

## Roadmap to Commercial / App Store Version (v2)

### Goal

Replace all GPL and child-process dependencies with native Apple APIs, enabling:
- Mac App Store distribution
- Closed-source commercial licensing
- App sandbox compliance

### What to Replace

#### 1. ffmpeg → AVFoundation + VideoToolbox + custom RTSP output

**Capture (replaces `-f avfoundation`):**
```swift
// AVCaptureSession with AVCaptureDeviceInput for camera and mic
// AVCaptureVideoDataOutput for raw frames
// AVCaptureAudioDataOutput for raw audio samples
```

**Encode (replaces `-c:v libx264`):**
```swift
// VTCompressionSession with VideoToolbox
// kVTProfileLevel_H264_Baseline_AutoLevel
// kVTCompressionPropertyKey_RealTime = true
// kVTCompressionPropertyKey_AllowFrameReordering = false
```

**Audio encode (replaces `-c:a aac`):**
```swift
// AVAudioConverter or AudioToolbox AudioConverter
// kAudioFormatMPEG4AAC at 128kbps
```

**RTSP output (replaces mediamtx + ffmpeg RTSP muxer):**

Option A — Write a minimal RTSP/RTP server in Swift using `Network.framework`:
- RTSP server on TCP port 8554 (DESCRIBE, SETUP, PLAY, TEARDOWN)
- RTP packetizer for H.264 NAL units (RFC 6184)
- RTP packetizer for AAC audio (RFC 3640)
- Supports multiple simultaneous clients

Option B — Use an LGPL-built ffmpeg (see below) just as an RTSP sink, keeping AVFoundation for capture and VideoToolbox for encoding, piping encoded data to ffmpeg via stdin.

#### 2. LGPL ffmpeg build (simpler intermediate step)

Build ffmpeg from source with only LGPL components:

```bash
./configure \
  --disable-gpl \
  --disable-nonfree \
  --disable-everything \
  --enable-protocol=rtsp,rtp,tcp \
  --enable-muxer=rtsp,rtp \
  --enable-encoder=aac \
  --enable-videotoolbox \
  --enable-encoder=h264_videotoolbox \
  --enable-indev=avfoundation \
  --enable-filter=null \
  --disable-doc \
  --disable-programs \   # build as library only, or keep ffmpeg binary
  --target-os=darwin \
  --arch=arm64
```

Result: ~5–15 MB binary, LGPL license, no libx264. Replace the bundled ffmpeg binary, update the ffmpeg command to use `-c:v h264_videotoolbox` instead of `-c:v libx264 -preset ultrafast`.

This alone resolves the GPL issue for **direct (non-App Store) distribution**.

#### 3. mediamtx → keep or replace

mediamtx is MIT — it is not a blocker for direct distribution or licensing. For App Store, `Process()` is the blocker, not the license. Replace with a native Swift RTSP server (Option A above).

### Migration Path

| Step | Effort | Unlocks |
|---|---|---|
| 1. Build LGPL ffmpeg, swap binary | ~1 day | Direct commercial sale, closed source |
| 2. Replace ffmpeg with AVFoundation + VideoToolbox + LGPL ffmpeg as RTSP sink | ~1 week | Smaller binary, better integration |
| 3. Write native Swift RTSP server, remove all binaries | ~3–4 weeks | App Store, full sandbox compliance |

### Files to Create in v2

| File | Purpose |
|---|---|
| `CaptureEngine.swift` | AVCaptureSession setup, video/audio data output delegates |
| `VideoEncoder.swift` | VTCompressionSession wrapper, outputs H.264 NAL units |
| `AudioEncoder.swift` | AudioToolbox AAC encoder wrapper |
| `RTSPServer.swift` | NWListener-based RTSP server, session management |
| `RTPPacketizer.swift` | RFC 6184 (H.264) and RFC 3640 (AAC) RTP packetizers |
| `SDPBuilder.swift` | Generates SDP for DESCRIBE response |

### Files Removed in v2

- `Resources/ffmpeg`
- `Resources/mediamtx`
- `Resources/mediamtx.yml`
- `StreamManager.swift` (replaced by `CaptureEngine` + `RTSPServer`)

### Entitlements Changes for App Store

```xml
com.apple.security.app-sandbox = YES   <!-- must be YES for App Store -->
com.apple.security.device.camera = YES
com.apple.security.device.microphone = YES
com.apple.security.network.server = YES
com.apple.security.network.client = YES
<!-- remove: no child processes -->
```

### Known Challenges in v2

- **RTSP is a stateful protocol** — each client goes through DESCRIBE → SETUP → PLAY, requiring session tracking per client
- **RTP timestamp management** — video and audio must share a common clock base
- **H.264 SPS/PPS** — must be extracted from VideoToolbox output and included in SDP and RTP stream
- **Multiple clients** — each client needs its own RTP send loop; frames must be broadcast to all active sessions
- **NAL unit fragmentation** — H.264 NAL units larger than MTU (~1400 bytes) must be split into FU-A RTP packets (RFC 6184 §5.8)
