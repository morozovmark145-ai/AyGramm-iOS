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

echo "== Хранилище без App Group"
# После переподписи в KSign группа приложений обычно недоступна, и Telegram показывает «Error 2».
# Если группы нет, данные хранятся в папке Documents самого приложения.
DELEGATE=submodules/TelegramUI/Sources/AppDelegate.swift
perl -pi -e 's#(let maybeAppGroupUrl = FileManager\.default\.containerURL\(forSecurityApplicationGroupIdentifier: appGroupName\))$#$1 ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first#' "$DELEGATE"
grep -n "let maybeAppGroupUrl" "$DELEGATE"
grep -q "documentDirectory" <(grep -n "let maybeAppGroupUrl" "$DELEGATE")
