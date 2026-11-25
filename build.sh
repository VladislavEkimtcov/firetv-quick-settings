#!/usr/bin/env bash
# Builds build/firetv-quick-settings.apk with Android SDK CLI tools.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

MIN_SDK=25
VERSION_CODE=1
VERSION_NAME=1.0.0

SDK=${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}
if [[ -z $SDK ]]; then
  for d in /opt/homebrew/share/android-commandlinetools "$HOME/Library/Android/sdk"; do
    if [[ -f $d/platforms/android-$MIN_SDK/android.jar ]]; then SDK=$d; break; fi
  done
fi
[[ -n $SDK ]] || { echo "error: Android SDK not found. Set ANDROID_HOME or ANDROID_SDK_ROOT." >&2; exit 1; }

JAR=$SDK/platforms/android-$MIN_SDK/android.jar
BT=$(find "$SDK/build-tools" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort -V | tail -1 || true)
[[ -f $JAR ]] || { echo "error: $JAR missing — sdkmanager 'platforms;android-$MIN_SDK'" >&2; exit 1; }
[[ -x $BT/aapt2 ]] || { echo "error: no build-tools in $SDK — sdkmanager 'build-tools;34.0.0'" >&2; exit 1; }

if [[ -z ${JAVA_HOME:-} || ! -x ${JAVA_HOME:-}/bin/javac ]]; then
  for j in /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home /usr/lib/jvm/java-17-openjdk \
           "$(/usr/libexec/java_home -v 17 2>/dev/null || true)"; do
    if [[ -n $j && -x $j/bin/javac ]]; then JAVA_HOME=$j; break; fi
  done
fi
[[ -x ${JAVA_HOME:-}/bin/javac ]] || { echo "error: JDK 17 required — brew install openjdk@17" >&2; exit 1; }
export JAVA_HOME

KEYSTORE=${KEYSTORE:-$PWD/release.keystore}
KEYPASS=${KEYPASS:-firetvquick}
if [[ ! -f $KEYSTORE ]]; then
  echo "Generating release keystore at $KEYSTORE..."
  keytool -genkeypair -keystore "$KEYSTORE" -storepass "$KEYPASS" -keypass "$KEYPASS" \
    -alias firetvquick -keyalg RSA -keysize 2048 -validity 10000 \
    -dname "CN=Fire TV Quick Settings, O=FireTvQuickSettings, C=US"
fi

WORK=$(mktemp -d "${TMPDIR:-/tmp}/firetv-quick.XXXXXX")
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/gen" "$WORK/classes" build

"$BT/aapt2" compile --dir res -o "$WORK/res.zip"
"$BT/aapt2" link -I "$JAR" --manifest AndroidManifest.xml "$WORK/res.zip" \
  --min-sdk-version "$MIN_SDK" --target-sdk-version 28 \
  --version-code "$VERSION_CODE" --version-name "$VERSION_NAME" --java "$WORK/gen" -o "$WORK/app.apk"

find src "$WORK/gen" -name '*.java' > "$WORK/sources.txt"
"$JAVA_HOME/bin/javac" --release 8 -Xlint:all -Xlint:-options -Werror -encoding UTF-8 \
  -classpath "$JAR" -d "$WORK/classes" @"$WORK/sources.txt"

find "$WORK/classes" -name '*.class' > "$WORK/classes.txt"
"$BT/d8" --release --min-api "$MIN_SDK" --lib "$JAR" --output "$WORK" @"$WORK/classes.txt"
(cd "$WORK" && zip -q -X app.apk classes.dex)

"$BT/zipalign" -f -p 4 "$WORK/app.apk" "$WORK/aligned.apk"
"$BT/apksigner" sign --ks "$KEYSTORE" --ks-pass "pass:$KEYPASS" --key-pass "pass:$KEYPASS" \
  --out build/firetv-quick-settings.apk "$WORK/aligned.apk"
"$BT/apksigner" verify build/firetv-quick-settings.apk
printf 'Built build/firetv-quick-settings.apk (%s bytes)\n' "$(wc -c < build/firetv-quick-settings.apk | tr -d ' ')"
