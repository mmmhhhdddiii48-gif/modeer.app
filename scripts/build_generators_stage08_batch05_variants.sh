#!/usr/bin/env bash
set -euo pipefail

ROOT="${GITHUB_WORKSPACE:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$ROOT"

apply_plain_patch() {
  local patch="$1"
  git apply --check "$patch"
  git apply "$patch"
  git diff --check
}

cat build_patches_v2/stage08_batch01_v2.patch.part* > /tmp/stage08_batch01.patch
apply_plain_patch /tmp/stage08_batch01.patch

cat build_patches_v3/stage08_batch02.b64.part* | base64 --decode --ignore-garbage > /tmp/stage08_batch02.patch
echo '40e2044f25ab34308593a1faa4acaea221a92f67440e7a5fcb250c939f4922b5  /tmp/stage08_batch02.patch' | sha256sum -c -
apply_plain_patch /tmp/stage08_batch02.patch

base64 --decode --ignore-garbage build_patches_v4/stage08_batch03.patch.gz.b64 | gzip -dc > /tmp/stage08_batch03.patch
echo '64cf70f661ba135af332db6648db2a98d901812cd33b08bb11ae19157012b590  /tmp/stage08_batch03.patch' | sha256sum -c -
apply_plain_patch /tmp/stage08_batch03.patch

cat build_patches_v6/stage08_batch04.patch.gz.hex.part* > /tmp/stage08_batch04.patch.gz.hex
python - <<'PY'
from pathlib import Path
source = Path('/tmp/stage08_batch04.patch.gz.hex')
Path('/tmp/stage08_batch04.patch.gz').write_bytes(
    bytes.fromhex(''.join(source.read_text(encoding='ascii').split()))
)
PY
echo 'e4e6c89fb4b9db485a6d3cd1fe0904c0dfe79d5c54532f0d41f7df5746c92fe1  /tmp/stage08_batch04.patch.gz' | sha256sum -c -
gzip -dc /tmp/stage08_batch04.patch.gz > /tmp/stage08_batch04.patch
echo '9a5500e8e3cfa36d34a1736765ad44dcaad8cc770dacb6f741e070140128f4b5  /tmp/stage08_batch04.patch' | sha256sum -c -
apply_plain_patch /tmp/stage08_batch04.patch

echo '89e95bf0023aa42b9dac521af6173b821f0523952c16285ece26efe899668878  build_patches_v7/stage08_batch04_analyze_fix.patch' | sha256sum -c -
apply_plain_patch build_patches_v7/stage08_batch04_analyze_fix.patch

python - <<'PY'
from pathlib import Path
source = Path('build_patches_v8/stage08_batch05.patch.gz.hex')
Path('/tmp/stage08_batch05.patch.gz').write_bytes(
    bytes.fromhex(''.join(source.read_text(encoding='ascii').split()))
)
PY
echo 'a4ebe975adb644fcd2145a26eff51aaef79e877f814bc43bfe73760fcfbd52f6  /tmp/stage08_batch05.patch.gz' | sha256sum -c -
gzip -dc /tmp/stage08_batch05.patch.gz > /tmp/stage08_batch05.patch
echo '7b2fcaed090b2df8de2191a6c12e7c85d407f4c626b490addb925c6957ff881b  /tmp/stage08_batch05.patch' | sha256sum -c -
apply_plain_patch /tmp/stage08_batch05.patch

base64 --decode --ignore-garbage build_patches_v10/stage08_batch05_new_files.patch.gz.b64 > /tmp/stage08_batch05_new_files.patch.gz
echo '3ea42fd7cb9c92fd6a9663ad4b4b9a00beb8f7bdf5da46a403c1cec2df5ba9d8  /tmp/stage08_batch05_new_files.patch.gz' | sha256sum -c -
gzip -dc /tmp/stage08_batch05_new_files.patch.gz > /tmp/stage08_batch05_new_files.patch
echo '3fa619d3043d2ace6ca0e81ed35d238b25d6e3357f5d20145c25820f6135e553  /tmp/stage08_batch05_new_files.patch' | sha256sum -c -
apply_plain_patch /tmp/stage08_batch05_new_files.patch

node --test \
  tests/generators_stage08_batch01_core_flow.test.js \
  tests/generators_stage08_batch01_mobile_contract.test.js \
  tests/generators_stage08_batch02_edit_dates_alerts_contract.test.js \
  tests/generators_stage08_batch03_exit_load_contract.test.js \
  tests/generators_stage08_batch04_receipt_printing_contract.test.js \
  tests/generators_stage08_batch05_activation_variants_contract.test.js

APP="$ROOT/mobile/generators_mobile"
cd "$APP"
flutter create . --project-name nukhba_generators_mobile --org com.nukhba --platforms=android
rm -f test/widget_test.dart

python - <<'PY'
from pathlib import Path

gradle = Path('android/app/build.gradle.kts')
if gradle.exists():
    text = gradle.read_text(encoding='utf-8').replace(
        'minSdk = flutter.minSdkVersion', 'minSdk = 24'
    )
    gradle.write_text(text, encoding='utf-8')
else:
    gradle = Path('android/app/build.gradle')
    text = gradle.read_text(encoding='utf-8').replace(
        'minSdkVersion flutter.minSdkVersion', 'minSdkVersion 24'
    )
    gradle.write_text(text, encoding='utf-8')

manifest = Path('android/app/src/main/AndroidManifest.xml')
text = manifest.read_text(encoding='utf-8')
permissions = [
    '    <uses-permission android:name="android.permission.INTERNET" />',
    '    <uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />',
    '    <uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />',
    '    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />',
    '    <uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />',
]
missing = [
    line for line in permissions
    if line.split('android:name="', 1)[1].split('"', 1)[0] not in text
]
if missing:
    end = text.find('>') + 1
    text = text[:end] + '\n' + '\n'.join(missing) + text[end:]
    manifest.write_text(text, encoding='utf-8')
PY

flutter pub get
dart format lib test
flutter analyze --no-fatal-infos
flutter test

mkdir -p android/app/src/main/res/drawable
cat > android/app/src/main/res/drawable/nukhba_owner_launcher.xml <<'XML'
<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">
  <path android:fillColor="#081C24" android:pathData="M0,0h108v108h-108z" />
  <path android:fillColor="#24B8B1" android:pathData="M22,66h13v20h-13zM42,51h13v35h-13zM62,34h13v52h-13z" />
  <path android:fillColor="#F28C28" android:pathData="M30,53l9,-9l12,12l28,-29l9,9l-37,38z" />
</vector>
XML
cat > android/app/src/main/res/drawable/nukhba_collector_launcher.xml <<'XML'
<vector xmlns:android="http://schemas.android.com/apk/res/android" android:width="108dp" android:height="108dp" android:viewportWidth="108" android:viewportHeight="108">
  <path android:fillColor="#081C24" android:pathData="M0,0h108v108h-108z" />
  <path android:fillColor="#24B8B1" android:pathData="M22,61h13v19h-13zM42,47h13v33h-13zM62,31h13v49h-13z" />
  <path android:fillColor="#F28C28" android:pathData="M30,49l9,-9l12,12l28,-29l9,9l-37,38zM0,88h108v20h-108z" />
</vector>
XML

configure_identity() {
  local package_id="$1"
  local label="$2"
  local icon="$3"
  PACKAGE_ID="$package_id" APP_LABEL="$label" APP_ICON="$icon" python - <<'PY'
from pathlib import Path
import os, re

gradle = Path('android/app/build.gradle.kts')
if not gradle.exists():
    gradle = Path('android/app/build.gradle')
text = gradle.read_text(encoding='utf-8')
text = re.sub(r'applicationId\s*=\s*"[^"]+"', f'applicationId = "{os.environ["PACKAGE_ID"]}"', text)
text = re.sub(r'applicationId\s+"[^"]+"', f'applicationId "{os.environ["PACKAGE_ID"]}"', text)
gradle.write_text(text, encoding='utf-8')

manifest = Path('android/app/src/main/AndroidManifest.xml')
text = manifest.read_text(encoding='utf-8')
text = re.sub(r'android:label="[^"]+"', f'android:label="{os.environ["APP_LABEL"]}"', text, count=1)
text = re.sub(r'android:icon="[^"]+"', f'android:icon="@drawable/{os.environ["APP_ICON"]}"', text, count=1)
manifest.write_text(text, encoding='utf-8')
PY
}

OUT=/tmp/nukhba_generators_stage08_batch05
rm -rf "$OUT"
mkdir -p "$OUT"

configure_identity com.nukhba.generators.owner 'النخبة للمولدات' nukhba_owner_launcher
flutter build apk --release --dart-define=APP_VARIANT=owner
cp build/app/outputs/flutter-apk/app-release.apk "$OUT/Nukhba_Generators_Owner_Stage08_Batch05.apk"

flutter clean
flutter pub get
configure_identity com.nukhba.generators.collector 'النخبة للجابي' nukhba_collector_launcher
flutter build apk --release --dart-define=APP_VARIANT=collector
cp build/app/outputs/flutter-apk/app-release.apk "$OUT/Nukhba_Generators_Collector_Stage08_Batch05.apk"

RELEASE="$APP/release/stage08_batch05"
rm -rf "$RELEASE"
mkdir -p "$RELEASE"
cp "$OUT"/*.apk "$RELEASE"/
cd "$RELEASE"
sha256sum Nukhba_Generators_Owner_Stage08_Batch05.apk > Nukhba_Generators_Owner_Stage08_Batch05_SHA256.txt
sha256sum Nukhba_Generators_Collector_Stage08_Batch05.apk > Nukhba_Generators_Collector_Stage08_Batch05_SHA256.txt
sha256sum Nukhba_Generators_*_Stage08_Batch05.apk > Nukhba_Generators_Stage08_Batch05_All_SHA256.txt
