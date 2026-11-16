#!/usr/bin/env bash
# Изменения AyGramm поверх открытого кода Telegram-iOS.
# Условия Telegram для своих сборок: своё имя, свой логотип, свой api_id, открытый код.
set -euo pipefail
ROOT="$1"
cd "$ROOT"

echo "== Имя приложения: AyGramm"
perl -0pi -e 's#(<key>CFBundleDisplayName</key>\s*<string>)Telegram(</string>)#${1}AyGramm${2}#' Telegram/BUILD
grep -n -A1 "CFBundleDisplayName" Telegram/BUILD | head -4
# Локализованные названия на домашнем экране.
find Telegram -name InfoPlist.strings -print0 | while IFS= read -r -d '' f; do
  perl -pi -e 's/^("?CFBundleDisplayName"?\s*=\s*)"[^"]*"/${1}"AyGramm"/' "$f"
done

echo "== Иконка: призрак AyGramm вместо логотипа Telegram"
ICON="$ROOT/aygramm/AppIcon.png"
SET="Telegram/Telegram-iOS/DefaultAppIcon.xcassets/AppIconLLC.appiconset"
for png in "$SET"/*.png; do
  w=$(sips -g pixelWidth "$png" | awk '/pixelWidth/{print $2}')
  sips -s format png -z "$w" "$w" "$ICON" --out "$png" >/dev/null
  echo "  $(basename "$png") ${w}px"
done

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

echo "== Режим призрака"
# Включён, пока в UserDefaults нет ключа AyGrammGhostMode = false.
# Сервер не получает: статус «в сети», отметки о прочтении, «печатает…», просмотры историй.
GHOST='(UserDefaults.standard.object(forKey: "AyGrammGhostMode") as? Bool ?? true)'
export GHOST
S=submodules/TelegramCore/Sources/State

# Статус: вместо «в сети» всегда отправляется «не в сети».
perl -pi -e 's/updateStatus\(offline: \.boolFalse\)/updateStatus(offline: $ENV{GHOST} ? .boolTrue : .boolFalse)/' $S/ManagedAccountPresence.swift
test "$(grep -c 'AyGrammGhostMode' $S/ManagedAccountPresence.swift)" = 1

# «Печатает…»: запрос не отправляется.
perl -pi -e 's/^(\s*)(return network\.request\(Api\.functions\.messages\.(setTyping|setEncryptedTyping)\()/$1if $ENV{GHOST} { return .complete() }\n$1$2/' $S/ManagedLocalInputActivities.swift
test "$(grep -c 'AyGrammGhostMode' $S/ManagedLocalInputActivities.swift)" = 2

# Прочтение: состояние считается отправленным, но запрос на сервер не уходит.
perl -pi -e 's/^(\s*)((?:var pushSignal: Signal<Void, NoError> = |return )network\.request\(Api\.functions\.(?:channels\.readHistory|messages\.readHistory|messages\.readEncryptedHistory)\()/$1if $ENV{GHOST} { return .single(readState) }\n$1$2/' $S/SynchronizePeerReadState.swift
test "$(grep -c 'AyGrammGhostMode' $S/SynchronizePeerReadState.swift)" = 3

# Истории: просмотр не отправляется.
perl -pi -e 's/^(\s*)(return network\.request\(Api\.functions\.stories\.readStories\()/$1if $ENV{GHOST} { return .complete() }\n$1$2/' $S/ManagedSynchronizeViewStoriesOperations.swift
test "$(grep -c 'AyGrammGhostMode' $S/ManagedSynchronizeViewStoriesOperations.swift)" = 1
grep -rn "AyGrammGhostMode" $S | cut -c1-160
