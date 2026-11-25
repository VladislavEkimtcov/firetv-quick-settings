#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

WORK=$(mktemp -d "${TMPDIR:-/tmp}/firetv-quick-tests.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

SDK=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}
if [[ -z $SDK ]]; then
  for d in /opt/homebrew/share/android-commandlinetools "$HOME/Library/Android/sdk"; do
    if [[ -f $d/platforms/android-25/android.jar ]]; then SDK=$d; break; fi
  done
fi
JAR=$SDK/platforms/android-25/android.jar

javac -cp "$JAR:src" -d "$WORK" src/io/github/vladislavekimtcov/firetvquick/{AirPlay,Health,LogLines,Sun,Video,Compat}.java tests/*.java

echo "Running unit tests..."
java -cp "$JAR:$WORK" io.github.vladislavekimtcov.firetvquick.AirPlayTest
java -cp "$JAR:$WORK" io.github.vladislavekimtcov.firetvquick.HealthTest
java -cp "$JAR:$WORK" io.github.vladislavekimtcov.firetvquick.LogLinesTest
java -cp "$JAR:$WORK" io.github.vladislavekimtcov.firetvquick.SunTest
java -cp "$JAR:$WORK" io.github.vladislavekimtcov.firetvquick.VideoTest
echo "All quick settings unit tests passed!"
