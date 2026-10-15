#!/bin/bash
# Проверка Xcode, сборка и запуск приложения в симуляторах iPhone, iPad и Apple TV.
# Запускается на Mac (локально или в GitHub Actions). Скриншоты кладёт в $OUT.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${OUT:-build/screenshots}"
mkdir -p "$OUT"
REPORT="$OUT/xcode-report.txt"

{
  echo "== Xcode";            xcodebuild -version
  echo "== Путь к Xcode";      xcode-select -p
  echo "== Command Line Tools"; pkgutil --pkg-info=com.apple.pkg.CLTools_Executables 2>/dev/null || echo "отдельный пакет CLT не установлен (инструменты берутся из Xcode)"
  echo "== swift";            swift --version 2>&1 | head -1
  echo "== SDK";              xcodebuild -showsdks | grep -E "iphone|appletv"
  echo "== Рантаймы симуляторов"; xcrun simctl list runtimes | grep -E "iOS|tvOS"
} | tee "$REPORT"

pick() { # $1 = шаблон имени устройства, $2 = шаблон рантайма
  xcrun simctl list devices available -j | python3 -c '
import json,sys,re
name_re, rt_re = sys.argv[1], sys.argv[2]
best=None
for rt, devs in json.load(sys.stdin)["devices"].items():
    if not re.search(rt_re, rt): continue
    for d in devs:
        if re.search(name_re, d["name"]):
            best=(rt,d["udid"],d["name"])
print(best[1] if best else "")
' "$1" "$2"
}

run_on() { # $1 = метка, $2 = UDID, $3 = sdk, $4 = папка продукта
  local label="$1" udid="$2" sdk="$3" prod="$4"
  echo "== $label: сборка ($udid)" | tee -a "$REPORT"
  xcodebuild -project MoiDela.xcodeproj -scheme MoiDela -configuration Debug \
    -sdk "$sdk" -destination "id=$udid" -derivedDataPath build/dd \
    CODE_SIGNING_ALLOWED=NO build -quiet
  local app="build/dd/Build/Products/Debug-$prod/MoiDela.app"
  local bid; bid=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$app/Info.plist")
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b
  xcrun simctl install "$udid" "$app"
  xcrun simctl launch "$udid" "$bid" | tee -a "$REPORT"
  sleep 8
  xcrun simctl io "$udid" screenshot "$OUT/$label.png"
  # Проверяем, что процесс жив (приложение не упало после запуска)
  xcrun simctl spawn "$udid" launchctl list | grep -q "$bid" \
    && echo "== $label: приложение запущено и работает" | tee -a "$REPORT" \
    || { echo "== $label: приложение не работает!" | tee -a "$REPORT"; exit 1; }
  xcrun simctl shutdown "$udid" || true
}

IPHONE=$(pick '^iPhone' 'iOS')
IPAD=$(pick '^iPad' 'iOS')
TV=$(pick '^Apple TV' 'tvOS')
[ -n "$IPHONE" ] && [ -n "$IPAD" ] && [ -n "$TV" ] || { echo "Нет нужного симулятора" | tee -a "$REPORT"; exit 1; }

run_on iPhone  "$IPHONE" iphonesimulator iphonesimulator
run_on iPad    "$IPAD"   iphonesimulator iphonesimulator
run_on AppleTV "$TV"     appletvsimulator appletvsimulator
echo "== ГОТОВО: всё собрано и запущено" | tee -a "$REPORT"
