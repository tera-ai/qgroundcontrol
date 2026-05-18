<p align="center">
  <img src="resources/tera_brand/Logo%20-%20Color%20(light%20type)%20on%20transparent%20background.svg" alt="Tera Ground Control" width="420">
</p>

<p align="center">
  <strong>Tera Ground Control</strong> (Teragroundcontrol) · Ground control for Tera’s hybrid navigation stack
</p>

---

**Tera Ground Control** is a fork of [QGroundControl](https://github.com/mavlink/QGroundControl) tailored for **Tera** flight operations. It keeps upstream MAVLink compatibility with **PX4** and **ArduPilot**, while adding fly-view tooling, telemetry overlays, and GCS-side workflows used with Tera’s hybrid system, odometry publishers, and companion processes.

This repository is maintained by **Ayush Zenith** (`ayushzenith` / `ayush@tera-ai.com`) for Tera AI–branded builds (application display name **TGroundControl** in installers and desktop metadata).

---

## Why this fork

- **Hybrid + vision stack**: First-class support for live **odometry** on the map, with estimator-aware styling (**mapping**, **tracking**, **propagation**).
- **GPS + odometry together**: **GPS_RAW_INT** path on the map, raw GPS telemetry readouts, and optional **GPS vs odometry error** panel (distance at each odometry update), with history sparkline and min/avg/max stats.
- **Multi-system MAVLink**: Odometry plotting prefers sys 77, with fallbacks
- **EKF insight**: **EKF control / status** panel work focused on parameters, visibility, and diagnostics for closed loop.
- **Map UX**: Velocity-style overlays, propagation plot options, hybrid **map bounds** display, and fixes for polyline / arrowhead rendering.
- **Operator controls** (fly view): MAVLink actions to **restart hybrid navigation** and **stop the camera publisher - non mcap**

Upstream docs remain useful for generic QGC behavior; Tera-specific behavior lives in this tree (notably `src/FlyView/`, `src/Vehicle/`).

---

## Prebuilt binaries (GitHub Actions)

CI is defined in [`.github/workflows/build-and-release.yml`](.github/workflows/build-and-release.yml) on [`tera-ai/qgroundcontrol`](https://github.com/tera-ai/qgroundcontrol).

### Latest release (recommended)

[GitHub **Releases** — latest](https://github.com/tera-ai/qgroundcontrol/releases/latest) — pick assets for your OS, or use direct links when those files are attached to the newest tag:

| Platform | Download |
|----------|----------|
| **macOS** (universal `.dmg`) | [TGroundControl.dmg](https://github.com/tera-ai/qgroundcontrol/releases/latest/download/TGroundControl.dmg) |
| **Windows** (x64 installer `.exe`) | [TGroundControl-installer-AMD64.exe](https://github.com/tera-ai/qgroundcontrol/releases/latest/download/TGroundControl-installer-AMD64.exe) |
| **Linux** (x86_64 `.AppImage`) | [TGroundControl-x86_64.AppImage](https://github.com/tera-ai/qgroundcontrol/releases/latest/download/TGroundControl-x86_64.AppImage) |

Additional Windows installers (ARM64, combined) and **Linux aarch64** (`.AppImage`) are listed on the [same release page](https://github.com/tera-ai/qgroundcontrol/releases/latest) when published.

If a `releases/latest/download/...` link returns **404**, there may be no tagged release yet — use the CI path below.

### Latest CI build (any branch)

[→ **Build and Release** workflow runs](https://github.com/tera-ai/qgroundcontrol/actions/workflows/build-and-release.yml)

Open the **top successful run** for the branch you care about (e.g. `master`), then scroll to **Artifacts** and download:

| Platform | Artifact name (in the run) |
|----------|------------------------------|
| macOS | `TGroundControl` (contains `TGroundControl.dmg`) |
| Windows x64 | `TGroundControl-installer-AMD64` |
| Linux x86_64 | `TGroundControl-x86_64` |
| Linux aarch64 | `TGroundControl-aarch64` |

GitHub may expire workflow artifacts after a period; tagged **Releases** keep binaries longer.

---

## Build and develop

- **Upstream developer guide**: [dev.qgroundcontrol.com](https://dev.qgroundcontrol.com/en/getting_started/) — toolchain, Qt, and platform setup still follow QGC conventions unless noted in our `CMakeLists.txt` comments (e.g. **TGroundControl** `OUTPUT_NAME` and CI packaging expectations).
- **License**: QGroundControl licensing applies to the upstream-derived code; see [`.github/COPYING.md`](.github/COPYING.md) and upstream [license](https://github.com/mavlink/qgroundcontrol/blob/master/.github/COPYING.md).
---

## Useful upstream links (still relevant)

- [QGroundControl user manual](https://docs.qgroundcontrol.com/en/)
- [QGroundControl developer guide](https://dev.qgroundcontrol.com/en/)
- [MAVLink](https://mavlink.io/en/)

---

*Tera Ground Control — forked from QGroundControl for Tera’s stack; not an official Dronecode / QGroundControl release.*
