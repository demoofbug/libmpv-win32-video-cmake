# libmpv build

Provides builds of [libmpv](https://github.com/mpv-player/mpv) for Windows,
used by [mediax](https://github.com/demoofbug/mediax), licensed under the
LGPL so playback can be shipped in commercial applications.

## Setup

- Arch Linux (or the `ghcr.io/shinchiro/archlinux:latest` container used by CI)
- Packages: `base-devel cmake ninja meson python-pip nasm yasm git p7zip curl`
  (meson ≥ 1.3)
- Toolchain: the first build bootstraps LLVM/Clang and the MinGW-w64 runtime
  from source (see `toolchain/`). CI builds the toolchain once via the
  manual `llvm toolchain` workflow and caches it. A system MinGW-w64 GCC
  toolchain can be used instead with `-DCOMPILER_TOOLCHAIN=gcc`
  (x86 targets only).

## Build

```shell
$ cmake -DTARGET_ARCH=x86_64-w64-mingw32 -DCOMPILER_TOOLCHAIN=clang -DBUILD_VERSION=v0.41.0+1 -G Ninja -B build_x86_64
$ ninja -C build_x86_64 mpv
$ ninja -C build_x86_64 mpv-packaging
$ ls build_x86_64/*.zip
```

`-DBUILD_VERSION` is optional; when empty, the committed `version.txt`
(`develop`) is used.

Supported targets:

| `TARGET_ARCH`                | Notes                                  |
| ---------------------------- | -------------------------------------- |
| `x86_64-w64-mingw32`         | default                                |
| `x86_64-w64-mingw32` + `-DGCC_ARCH=x86-64-v3` | AVX2 baseline        |
| `i686-w64-mingw32`           | clang only                             |
| `aarch64-w64-mingw32`        | clang only                             |

Output (per architecture):

```
├── mpv-x86_64-v0.41.0+1.zip          # player
├── mpv-dev-x86_64-v0.41.0+1.zip      # libmpv: libmpv-2.dll, libmpv.dll.a, include/mpv/*.h
└── mpv-debug-x86_64-v0.41.0+1.zip    # debug symbols
```

## Naming convention

```
mpv-<kind>-<arch>[-v3]-<version>.zip
```

| Component | Notes                                                       | Value                        |
| --------- | ----------------------------------------------------------- | ---------------------------- |
| **kind**  | Package contents                                            | *(player)*, `dev`, `debug`   |
| **arch**  | Architecture                                                | `i686`, `x86_64`, `x86_64-v3`, `aarch64` |
| **version** | Engine version + build number ([Versioning](#versioning)) | `v0.41.0+1`, `develop`, …    |

## Versioning

Releases are tagged as:

```
v<engine-version>+<build-number>
```

- **engine-version** is the exact upstream version of the primary engine built
  by this repository (currently mpv), copied verbatim — including any
  pre-release suffix it may carry (`-rc1`, `-beta`, …).
- **build-number** is a counter owned by this repository, starting at `1`,
  incremented on every rebuild of the same engine version.

`-` is never used as a separator, because upstream versions already use it for
pre-release suffixes. The two parts can therefore always be split unambiguously
at `+` (semver build metadata).

| Change                                            | Version transition          |
| ------------------------------------------------- | --------------------------- |
| First build of mpv `0.41.0`                       | `v0.41.0+1`                 |
| Dependency / patch / build-config change          | `v0.41.0+1` → `v0.41.0+2`   |
| Engine upgrade (`0.41.0` → `0.42.0` or `0.41.1`)  | `v0.42.0+1` / `v0.41.1+1`   |
| Engine pre-release (`0.42.0-rc1`)                 | `v0.42.0-rc1+1`             |

Rules:

- The full tag string (e.g. `v0.41.0+1`) is the single source of truth. On a
  tag build, CI passes it to CMake as `-DBUILD_VERSION`, from where it flows
  into artifact names (see [Naming convention](#naming-convention)). Parts are
  derived from the tag, never maintained separately.
- Non-tag builds fall back to the committed `develop` version string
  (`version.txt`).
- Pushing a tag triggers CI, which builds all architectures and publishes
  them to a GitHub Release named after the tag.

## Version history

### Unreleased

- Upgraded **mpv** `0.39.0` → `0.41.0`; dropped
  `mpv-0001-remove-libass.patch` (libass is an unconditional dependency of
  mpv since `0.41`).
- Upgraded **ffmpeg** `release/7.1` (moving branch) → `n9.0.2` (pinned tag):
  - Removed `--disable-postproc` (libpostproc was dropped upstream),
    `--enable-decoder=ljpeg` (merged into `mjpeg`) and
    `--enable-protocol=hls` (never a protocol; HLS playback goes through the
    demuxer).
  - Dropped `ffmpeg-dash-base-url-escape.patch` — upstream integrated the
    equivalent XML-escaping fix in `dashdec.c`, and the patch no longer
    applied to any current ffmpeg line.
  - Enabled the video decode stack from the darwin video variant: h264,
    h263, mpeg1/2/4, msmpeg4, wmv, vp6/8/9, hevc, av1 (native + libdav1d),
    theora; 14 subtitle decoders; matching parsers and demuxers (hls, dash,
    mpegts, rtsp, ass, srt, …); `--enable-libdav1d`, `--enable-libxml2`.
    Playback-only, still LGPL.
- Pinned the subtitle/render stack to release tags: **libplacebo** `v7.360.1`,
  **libass** `0.17.5`, **dav1d** `1.5.4`, **freetype** `2.14.3`,
  **harfbuzz** `15.0.0`, **fribidi** `1.0.17`. These previously tracked the
  upstream default branches.
- Adopted the darwin versioning scheme (`v<mpv>+N`, `develop` fallback,
  `version.txt`) and CI policy (PRs build without publishing, tags publish);
  packages are `zip` archives named `mpv[-dev|-debug]-<arch>-<version>.zip`
  (previously 7z named by build date + git hash).
- Added this README.

## Minimum versions

| Arch        | Min Version         | Notes                        |
| ----------- | ------------------- | ---------------------------- |
| `i686`      | Windows Vista       | winpthreads default          |
| `x86_64`    | Windows Vista       | winpthreads default          |
| `x86_64-v3` | AVX2-capable CPU    | `-DGCC_ARCH=x86-64-v3`       |
| `aarch64`   | Windows 11 on ARM   | clang toolchain only         |

## Dependencies

Pinned to exact upstream release tags in `packages/*.cmake`:

| Package     | Version    |
| ----------- | ---------- |
| mpv         | `v0.41.0`  |
| ffmpeg      | `n9.0.2`   |
| libplacebo  | `v7.360.1` |
| libass      | `0.17.5`   |
| dav1d       | `1.5.4`    |
| freetype    | `VER-2-14-3` |
| harfbuzz    | `15.0.0`   |
| fribidi     | `v1.0.17`  |

All other dependencies (openssl, libssh, libsrt, libjxl, shaderc, spirv-*,
vulkan, angle-headers, libarchive, uchardet, lcms2, fontconfig, zlib, …)
follow the upstream default branches.

FFmpeg is configured `--disable-gpl --disable-nonfree --enable-version3`
with a decoder/demuxer/protocol whitelist: full audio set, still images,
video software decode (h264, hevc, av1 via dav1d, vp8/9, mpeg*, wmv*,
theora), subtitle codecs, and network playback (http/https, hls, dash,
rtmp, ftp, udp, …). NVIDIA cuvid/nvdec/nvenc is enabled on x86; d3d11va,
dxva2 and AMF are disabled.

## Commercial use

- mpv is built `-Dgpl=false` and FFmpeg `--disable-gpl --disable-nonfree
  --enable-version3`: the result is LGPL, optionally version 3 (the
  `--enable-version3` components, e.g. the statically linked OpenSSL, need
  the "or later" election).
- No GPL-only components (x264/x265) are linked. The GPL encoder build line
  is a separate repository in the media-kit lineage and is not built here.
- FFmpeg and all other dependencies are statically linked into
  `libmpv-2.dll`. LGPL distribution requires offering the corresponding
  source — the exact versions are the tags pinned in `packages/*.cmake`.

## CI

| Event                | Builds | Publishes                |
| -------------------- | ------ | ------------------------ |
| Push to `master`     | no     | —                        |
| Pull request         | yes (4 arches) | workflow artifacts only (`develop`) |
| Tag push             | yes (4 arches) | GitHub Release named after the tag |

The `llvm toolchain` workflow is manual (`workflow_dispatch`) and bootstraps
the clang/MinGW toolchain into CI caches consumed by the build workflow.

## Notes

- GL rendering uses ANGLE (`-Dgl=enabled -Degl-angle=enabled`) on x86/i686;
  the aarch64 build has no GL backend.
- Vulkan and D3D11 renderers are disabled at the mpv level; NVIDIA decode
  (cuvid/nvdec) is available on x86 via FFmpeg.
- The `mpv-release` target builds from the latest official mpv release
  tarball instead of the git tag.
- `libsrt` is built but not wired into FFmpeg (no `--enable-libsrt`), so SRT
  streaming is currently unavailable.

## Credits

- [media-kit/libmpv-win32-video-cmake](https://github.com/media-kit/libmpv-win32-video-cmake) — fork parent
