# Third-Party Licenses

Mac IP Cam bundles the following third-party components:

---

## ffmpeg

**Version:** 7.1.1
**License:** GNU Lesser General Public License v2.1 or later (LGPL)
**Source:** https://git.ffmpeg.org/ffmpeg.git (tag n7.1.1)
**Build configuration:**

```
./configure --disable-gpl --disable-nonfree --disable-everything \
  --disable-xlib --enable-indev=avfoundation \
  --enable-encoder=h264_videotoolbox --enable-encoder=aac \
  --enable-muxer=rtsp --enable-muxer=rtp \
  --enable-protocol=rtp --enable-protocol=tcp \
  --enable-videotoolbox --enable-audiotoolbox \
  --enable-network --disable-doc --disable-debug \
  --disable-ffplay --disable-ffprobe \
  --target-os=darwin --arch=arm64 --cc=clang
```

Full LGPL v2.1 license text: https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html

---

## mediamtx

**Version:** see Resources/mediamtx
**License:** MIT
**Source:** https://github.com/bluenviron/mediamtx

```
MIT License

Copyright (c) 2019 aler9

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```
