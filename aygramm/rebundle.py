# Меняет Bundle ID и название в IPA, чтобы AyGramm ставился рядом с официальным Telegram.
# ph.telegra.Telegraph -> com.personal.aygramm, у расширений тот же хвост (.Share, .Widget и т.д.).
# Подпись после правки неверна, KSign переподписывает приложение заново.
# Запуск: python scripts/rebundle.py вход.ipa выход.ipa
import plistlib
import sys
import zipfile

OLD = "ph.telegra.Telegraph"
NEW = "com.personal.aygramm"

src, dst = sys.argv[1], sys.argv[2]
changed = 0
with zipfile.ZipFile(src) as zin, zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED) as zout:
    for item in zin.infolist():
        data = zin.read(item.filename)
        if item.filename.endswith("Info.plist") and ".app/" in item.filename:
            p = plistlib.loads(data)
            bid = p.get("CFBundleIdentifier", "")
            if bid.startswith(OLD):
                p["CFBundleIdentifier"] = NEW + bid[len(OLD):]
                if item.filename.count("/") == 2:
                    p["CFBundleDisplayName"] = "AyGramm"
                    p["CFBundleName"] = "AyGramm"
                data = plistlib.dumps(p, fmt=plistlib.FMT_BINARY)
                changed += 1
                print(item.filename, "->", p["CFBundleIdentifier"])
        zout.writestr(item, data)
print("plists changed:", changed)
