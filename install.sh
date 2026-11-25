#!/usr/bin/env bash
# Builds, installs, and grants required permissions for Fire TV Quick Settings:
#   - screen brightness control (appops WRITE_SETTINGS allow)
#   - night warmth tint & picture-off overlay (appops SYSTEM_ALERT_WINDOW allow)
#   - video format & AirPlay state logs (pm grant READ_LOGS)
#   - sleep timer standby (dpm set-active-admin)
#   - cog button takeover (pm grant WRITE_SECURE_SETTINGS, for Amazon quick_settings_lock)
#
# Usage:
#   ./install.sh                      # build, install, grant
#   ./install.sh --tv <ip>:5555       # specify target device
#   ./install.sh --mic                # enable microphone noise meter
#   ./install.sh --undo               # unregister device admin, restore lock, uninstall
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

PKG="io.github.vladislavekimtcov.firetvquick"
ADB=${ADB:-adb}

TV=""
ACTION="install"
ENABLE_MIC=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tv)
      TV="$2"
      shift 2
      ;;
    --mic)
      ENABLE_MIC=1
      shift
      ;;
    --undo)
      ACTION="undo"
      shift
      ;;
    *)
      if [[ -z $TV && "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+(:[0-9]+)?$ ]]; then
        TV="$1"
        shift
      else
        echo "Unknown option: $1" >&2
        echo "Usage: $0 [--tv <tv-ip>:5555] [--mic] [--undo]" >&2
        exit 2
      fi
      ;;
  esac
done

TV=${TV:-${ADB_SERIAL:-}}
adb_() { "$ADB" ${TV:+-s "$TV"} "$@"; }
sh_() { adb_ shell "$@" </dev/null; }

state=$(adb_ get-state 2>/dev/null || true)
[[ $state == device ]] || { echo "error: no TV connected (adb connect <tv-ip>:5555; set ADB_SERIAL if several)" >&2; exit 1; }

if [[ $ACTION == "undo" ]]; then
  if sh_ pm list packages "$PKG" | grep -q "package:$PKG\$"; then
    echo "Relinquishing device admin and removing $PKG..."
    sh_ am broadcast -n "$PKG/.Undo" >/dev/null 2>&1 || true
    sleep 1
    adb_ uninstall "$PKG" || true
  else
    echo "$PKG is not installed."
  fi
  # Restore Amazon's quick settings lock
  if [[ $(sh_ settings get secure quick_settings_lock 2>/dev/null | tr -d '\r') == "1" ]]; then
    sh_ settings delete secure quick_settings_lock >/dev/null 2>&1 || true
    echo "Amazon quick_settings_lock released."
  fi
  echo "Uninstall complete."
  exit 0
fi

if [[ ! -f build/firetv-quick-settings.apk ]]; then
  ./build.sh
fi

echo "Installing $PKG onto $TV..."
out=$(adb_ install -r build/firetv-quick-settings.apk 2>&1 | grep -m1 -E 'Success|Failure|failed' || true)
[[ $out == *Success* ]] || { echo "error: adb install failed: $out" >&2; exit 1; }

echo "Granting permissions..."
sh_ appops set "$PKG" WRITE_SETTINGS allow
sh_ appops set "$PKG" SYSTEM_ALERT_WINDOW allow
sh_ pm grant "$PKG" android.permission.READ_LOGS
sh_ pm grant "$PKG" android.permission.WRITE_SECURE_SETTINGS 2>/dev/null ||
  echo "warning: WRITE_SECURE_SETTINGS not granted; Amazon quick settings may race" >&2

if [[ $ENABLE_MIC -eq 1 ]]; then
  sh_ pm grant "$PKG" android.permission.RECORD_AUDIO 2>/dev/null || true
fi

if ! sh_ dumpsys device_policy | grep -q "$PKG/"; then
  sh_ dpm set-active-admin "$PKG/.Admin" >/dev/null 2>&1 ||
    echo "warning: device admin not granted; sleep timer will not turn TV off" >&2
fi

if [[ -f expected.conf ]]; then
  sh_ mkdir -p "/sdcard/Android/media/$PKG"
  adb_ push expected.conf "/sdcard/Android/media/$PKG/expected.conf" >/dev/null 2>&1 || true
fi

# Restart service to take on new permissions
sh_ am force-stop "$PKG"
sh_ am broadcast -n "$PKG/.Boot" >/dev/null 2>&1

echo "Success: Fire TV Quick Settings installed on $TV."
echo "Press the settings (cog) button on the Fire TV remote to open."
