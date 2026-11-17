#!/usr/bin/env bash
# Изменения AyGramm поверх открытого кода Telegram-iOS.
# Условия Telegram для своих сборок: своё имя, свой логотип, свой api_id, открытый код.
set -euo pipefail
ROOT="$1"
cd "$ROOT"

echo "== Имя приложения: AyGramm"
perl -0pi -e 's#(<key>CFBundleDisplayName</key>\s*<string>)Telegram(</string>)#${1}AyGramm${2}#g' Telegram/BUILD
grep -n -A1 "CFBundleDisplayName" Telegram/BUILD
if grep -A1 "CFBundleDisplayName" Telegram/BUILD | grep -q "<string>Telegram</string>"; then echo "name not replaced"; exit 1; fi
# Локализованные названия на домашнем экране.
find Telegram -name InfoPlist.strings -print0 | while IFS= read -r -d '' f; do
  perl -pi -e 's/^("?CFBundleDisplayName"?\s*=\s*)"[^"]*"/${1}"AyGramm"/' "$f"
done

echo "== Иконка AyGramm вместо логотипа Telegram"
ICON="$ROOT/aygramm/AppIcon.png"
# Все PNG-иконки: основная, запасные и альтернативные из настроек.
find Telegram/Telegram-iOS/DefaultAppIcon.xcassets Telegram/Telegram-iOS/AppIcons.xcassets Telegram/Telegram-iOS -maxdepth 2   \( -path '*.appiconset/*.png' -o -path '*.alticon/*.png' \) -print0 | sort -zu | while IFS= read -r -d '' png; do
  w=$(sips -g pixelWidth "$png" | awk '/pixelWidth/{print $2}')
  sips -s format png -z "$w" "$w" "$ICON" --out "$png" >/dev/null
  echo "  $png ${w}px"
done
# Основная иконка iOS 26+ собирается из Telegram.icon (Icon Composer): самолёт и круг заменяются одним слоем с картинкой AyGramm.
IC=Telegram/Telegram-iOS/Telegram.icon
rm -f "$IC"/Assets/*
cp "$ICON" "$IC/Assets/AppIcon.png"
cat > "$IC/icon.json" <<'JSON'
{
  "fill" : "system-light",
  "groups" : [
    {
      "layers" : [
        {
          "glass" : false,
          "image-name" : "AppIcon.png",
          "name" : "AppIcon"
        }
      ]
    }
  ],
  "supported-platforms" : {
    "squares" : "shared"
  }
}
JSON
ls -la "$IC" "$IC/Assets"

echo "== Срок тестовых профилей подписи"
# Профили в build-system/fake-codesigning истекли 30.10.2026, а их сертификат действует до 2030.
# Приложение всё равно переподписывается в KSign, поэтому проверка срока профиля отключена.
PT=build-system/bazel-rules/rules_apple/tools/plisttool/plisttool.py
perl -pi -e 's/if expire and expire < datetime\.datetime\.now\(\):/if False and expire and expire < datetime.datetime.now():/' "$PT"
grep -n "if False and expire" "$PT"

echo "== Хранилище без App Group"
# После переподписи в KSign группа приложений обычно недоступна, и Telegram показывает «Error 2».
# Если группы нет, данные хранятся в папке Documents самого приложения.
DELEGATE=submodules/TelegramUI/Sources/AppDelegate.swift
perl -pi -e 's#(let maybeAppGroupUrl = FileManager\.default\.containerURL\(forSecurityApplicationGroupIdentifier: appGroupName\))$#$1 ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first#' "$DELEGATE"
grep -n "let maybeAppGroupUrl" "$DELEGATE"
grep -q "documentDirectory" <(grep -n "let maybeAppGroupUrl" "$DELEGATE")

echo "== Без iCloud"
# Telegram при запуске читает запасной адрес сервера из iCloud (CKContainer.default()).
# После подписи в KSign у приложения нет права на iCloud, и CloudKit аварийно закрывает приложение.
# Чтение пропускается, пока в Info.plist нет ключа AyGrammCloudKit.
# Сигнал ничего не отдаёт и не завершается: мгновенная ошибка зацикливает restart в CloudDataPrefixContext и переполняет стек.
CD=submodules/CloudData/Sources/CloudData.swift
perl -pi -e 's/^(\s*)(let container = CKContainer\.default\(\))$/$1if Bundle.main.object(forInfoDictionaryKey: "AyGrammCloudKit") == nil {\n$1    return EmptyDisposable\n$1}\n$1$2/' "$CD"
grep -n -B5 "CKContainer.default" "$CD"
test "$(grep -c 'AyGrammCloudKit' "$CD")" = 1

echo "== Без Siri"
# После подписи в KSign у приложения нет права на Siri, и любой вызов INPreferences бросает исключение.
# Проверка статуса уже зависит от enable_siri в конфигурации, запрос разрешения тоже ставится за эту проверку.
perl -pi -e 's/^(\s*)(\}, requestSiriAuthorization: \{ completion in)$/$1$2\n$1    if !buildConfig.isSiriEnabled { completion(false); return }/' "$DELEGATE"
grep -n -A2 "requestSiriAuthorization: { completion in" "$DELEGATE"
grep -q "if !buildConfig.isSiriEnabled { completion(false); return }" "$DELEGATE"

echo "== Режим призрака, удалённые сообщения, меню AyGramm"
python3 aygramm/features.py "$ROOT"
