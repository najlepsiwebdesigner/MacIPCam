# Mac IP Cam

Turns your Mac's built-in or external webcam into an RTSP stream on your local network. Any RTSP-capable client — VLC, ffplay, or a mobile IP camera app — can connect and watch the stream in real time.

![Mac IP Cam](assets/app-window.png)

## How it works

1. Select your camera and microphone
2. Click **Start**
3. Connect any RTSP client to the displayed URL:
   ```
   rtsp://<your-mac-ip>:8554/webcam
   ```

## Features

- Live H.264/AAC stream over RTSP on the local network
- Camera and microphone selection
- Optional audio — toggle microphone off for video-only stream
- **Screen light** — expands the window fullscreen and fills it with adjustable warm/cool light, useful as a fill light when the Mac faces you
- **Prevent sleep** — keeps the display and system awake while streaming

## Requirements

- macOS 13 Ventura or later
- Apple Silicon (arm64)

## Install

Download the latest DMG from the [Releases](../../releases) page, open it and drag **Mac IP Cam** to Applications.

### First launch — Gatekeeper warning

Because the app is not notarized, macOS will block it on first launch:

![Gatekeeper warning](assets/gatekeeper-warning.png)

Click **Done**, then go to **System Settings → Privacy & Security**, scroll down and click **Open Anyway**.

Alternatively, run this once in Terminal:

```bash
xattr -cr "/Applications/Mac IP Cam.app"
```

## License

MIT — see [LICENSE](LICENSE)

Third-party components: [THIRD_PARTY_LICENSES.md](THIRD_PARTY_LICENSES.md)
