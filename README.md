# Fire TV Quick Settings

A lightweight, clean Control Center overlay for Amazon Fire TV devices that triggers instantly when pressing the **settings (cog) button** on the remote, or **☰ Menu** on an active HDMI input.

---

## Why This Exists

On stock Fire OS, pressing the remote's settings (cog) button opens an overlay menu that largely duplicates what long-pressing the **HOME** button already provides. 

**Fire TV Quick Settings** replaces this redundant behavior with a dedicated, zero-bloat utility panel:
- **Instant Access (<10 ms):** Opens as an in-memory overlay without closing apps, dropping DRM playback, or pausing HDMI inputs.
- **Clean Interception via `quick_settings_lock`:** Sets Amazon's native `Settings.Secure quick_settings_lock` so Amazon's default panel never spawns, flashes, or races.
- **Stock Access Preserved:** Long-holding the **HOME** button continues to open Amazon's stock quick menu untouched.

---

## Panel Features

| Tile / Row | Left / Right | OK / Select |
|:---|:---|:---|
| **Brightness** | Adjust backlight level in 5% increments | Toggle automatic dimming after sunset |
| **Bluetooth** | Cycle through paired audio devices | Connect / disconnect device or open BT settings |
| **AirPlay** | — | Status glance (Ready / In use / Needs restart) & memory release |
| **Picture Off** | — | Screen turns black at minimum backlight; audio continues playing; any key restores |
| **Network** | — | Status glance (Wi-Fi band, signal strength, DNS filter state) |
| **Warmth (Night Mode)** | Adjust tint intensity in 10% steps | Toggle: Always on, After sunset, or Off until next sunset |
| **Sleep Timer** | Set timer in 15-minute steps (up to 4 hours) | Force-standby via Device Administrator when expired |
| **HDMI Signal Info** | — | Bottom footer displays real-time signal format (e.g. `1080p60 · SDR · HDMI` or `4K60`) |

---

## Installation

### Prerequisites
- Android Debug Bridge (`adb`) installed on your computer.
- Fire TV connected over local Wi-Fi or Ethernet with **Developer Options > ADB debugging** enabled.

### Sideload and Configure via ADB

```bash
git clone https://github.com/VladislavEkimtcov/firetv-quick-settings.git
cd firetv-quick-settings
./install.sh --tv <tv-ip>:5555
```

The script builds the APK, installs it, and grants the required elevated permissions over ADB:
- `appops WRITE_SETTINGS`: controls backlight brightness.
- `appops SYSTEM_ALERT_WINDOW`: displays the overlay without interrupting foreground apps.
- `pm grant READ_LOGS`: reads HDMI mode changes and event lifecycle.
- `pm grant WRITE_SECURE_SETTINGS`: toggles `quick_settings_lock` to cleanly intercept the cog button.
- `dpm set-active-admin`: registers device administrator to enable sleep timer standby (`lockNow()`).

### Uninstall

```bash
./install.sh --tv <tv-ip>:5555 --undo
```
Unregisters device administration, restores Amazon's native quick settings lock, and removes the package.

---

## Compatibility

- Works across all Fire TV devices running Fire OS 6, 7, and 8 (including Fire TV Stick 4K Max, Cube, Omni, and 4-Series).
- Compatible with the **stock Fire OS launcher**, **Projectivy Launcher**, **FLauncher**, and **dumbtv**.

---

## Credits & dumbtv Inspiration

Originally developed and prototyped as pull request [#217](https://github.com/humblemuzzu/dumbtv/pull/217) for [dumbtv](https://github.com/humblemuzzu/dumbtv) by [humblemuzzu](https://github.com/humblemuzzu). While `dumbtv` is designed to be a minimal launcher and debloating framework without background daemons, **Fire TV Quick Settings** is maintained as an independent project so all Fire TV users can customize their remote's settings button.
