Place `ffmpeg.exe` in this directory for Windows builds.

Expected path:

```text
apps/zhixuan_main/windows/third_party/ffmpeg/ffmpeg.exe
```

Build behavior:

- `flutter build windows`
- `flutter run -d windows`

Both commands install the binary to the app runtime directory as:

```text
<app bundle>/tools/ffmpeg.exe
```

Runtime lookup order already checks this bundled location, so no global PATH setup
is required once the file is present here.
