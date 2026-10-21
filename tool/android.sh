#!/usr/bin/env bash
# Installs the example (release) on the connected Android device, runs it once and
# writes results/android-<label>.json. Run from the repository root.
# ANDROID_SERIAL picks the device when more than one is connected. TTS_CONFIG overrides
# the configuration (default {"exit":true}).
set -euo pipefail
label=${1:-1}
adb=${ADB:-adb}
pkg=jp.kiarina.tts_pcm_example
(cd example && flutter build apk --release)
"$adb" install -r example/build/app/outputs/flutter-apk/app-release.apk
"$adb" shell am force-stop $pkg
"$adb" logcat -c
cfg=$(TTS_CONFIG=${TTS_CONFIG:-'{"exit":true}'} python3 -c "import base64,os;print(base64.urlsafe_b64encode(os.environ['TTS_CONFIG'].encode()).decode())")
"$adb" shell am start -n $pkg/.MainActivity --es config "$cfg" >/dev/null
mkdir -p results
for _ in $(seq 1 120); do
  sleep 5
  log=$("$adb" logcat -d -s flutter)
  tot=$(grep -o "TTS_PART [0-9]*/[0-9]*" <<<"$log" | head -1 | cut -d/ -f2 || true)
  n=$(grep -c "TTS_PART" <<<"$log" || true)
  if [ -n "$tot" ] && [ "$n" -ge "$tot" ]; then
    grep TTS_PART <<<"$log" | sed -E 's/^.*TTS_PART [0-9]+\/[0-9]+ //' | tr -d '\n' |
      python3 -m json.tool --no-ensure-ascii > "results/android-$label.json"
    echo "results/android-$label.json"
    exit 0
  fi
done
echo "no result" >&2
exit 1
