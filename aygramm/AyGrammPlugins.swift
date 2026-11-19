import Foundation
import Postbox
import SwiftSignalKit
import JavaScriptCore

// Плагины AyGramm: файлы JavaScript из открытого каталога aygramm/plugins в репозитории AyGramm-iOS.
// iOS запрещает подгружать в приложение новый машинный код, поэтому плагин работает в JavaScriptCore.
// Плагин видит только текст исходящего сообщения: функция onOutgoingText(text) возвращает новый текст.
// У JavaScriptCore нет доступа к сети, файлам и перепискам, поэтому плагин не может ничего отправить.
public struct AyGrammPlugin: Equatable {
    public let id: String
    public let name: String
    public let description: String
    public let scriptUrl: String
    public let sourceUrl: String
}

public struct AyGrammCustomPlugin: Equatable {
    public let id: String
    public let name: String
}

public enum AyGrammCustomPluginResult {
    case installed(String)
    case invalid(String?)
    case notJavaScript
    case tooLarge
    case downloadFailed
}

public enum AyGrammPlugins {
    public static let catalogPageUrl = "https://github.com/morozovmark145-ai/AyGramm-iOS/tree/master/aygramm/plugins"
    static let catalogUrl = "https://raw.githubusercontent.com/morozovmark145-ai/AyGramm-iOS/master/aygramm/plugins/index.json"
    static let installedKey = "AyGrammInstalledPlugins"
    static let seenKey = "AyGrammSeenPlugins"

    static var directory: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("aygramm-plugins", isDirectory: true)
    }

    public static var installedIds: [String] {
        return UserDefaults.standard.stringArray(forKey: installedKey) ?? []
    }

    static func fileUrl(id: String) -> URL {
        return directory.appendingPathComponent(id + ".js")
    }

    // Каталог из index.json: [{"id", "name", "description", "script", "source"}].
    public static func catalog() -> Signal<[AyGrammPlugin], NoError> {
        return Signal { subscriber in
            Queue.concurrentDefaultQueue().async {
                var plugins: [AyGrammPlugin] = []
                if let url = URL(string: catalogUrl), let data = try? Data(contentsOf: url), let items = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [[String: Any]] {
                    for item in items {
                        if let id = item["id"] as? String, let name = item["name"] as? String, let script = item["script"] as? String {
                            let description = item["description"] as? String ?? ""
                            let source = item["source"] as? String ?? script
                            plugins.append(AyGrammPlugin(id: id, name: name, description: description, scriptUrl: script, sourceUrl: source))
                        }
                    }
                }
                subscriber.putNext(plugins)
                subscriber.putCompletion()
            }
            return EmptyDisposable
        }
    }

    // Скачивает скрипт и включает плагин. false, если скрипт не скачался.
    public static func install(_ plugin: AyGrammPlugin) -> Signal<Bool, NoError> {
        return Signal { subscriber in
            Queue.concurrentDefaultQueue().async {
                var success = false
                if let url = URL(string: plugin.scriptUrl), let data = try? Data(contentsOf: url) {
                    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
                    if (try? data.write(to: fileUrl(id: plugin.id), options: .atomic)) != nil {
                        var ids = installedIds
                        if !ids.contains(plugin.id) {
                            ids.append(plugin.id)
                        }
                        UserDefaults.standard.set(ids, forKey: installedKey)
                        success = true
                    }
                }
                subscriber.putNext(success)
                subscriber.putCompletion()
            }
            return EmptyDisposable
        }
    }

    public static func uninstall(id: String) {
        try? FileManager.default.removeItem(at: fileUrl(id: id))
        UserDefaults.standard.set(installedIds.filter { $0 != id }, forKey: installedKey)
    }

    // Плагины каталога, о которых пользователю ещё не рассказывали.
    public static func unseen(in catalog: [AyGrammPlugin]) -> [AyGrammPlugin] {
        let seen = Set(UserDefaults.standard.stringArray(forKey: seenKey) ?? [])
        return catalog.filter { !seen.contains($0.id) && !installedIds.contains($0.id) }
    }

    public static func markSeen(_ ids: [String]) {
        var seen = UserDefaults.standard.stringArray(forKey: seenKey) ?? []
        for id in ids where !seen.contains(id) {
            seen.append(id)
        }
        UserDefaults.standard.set(seen, forKey: seenKey)
    }

    // MARK: - Свои плагины

    // Свои плагины: id → название. Файл лежит рядом с плагинами каталога, включение — через installedIds.
    static let customKey = "AyGrammCustomPlugins"

    public static var customPlugins: [AyGrammCustomPlugin] {
        let names = UserDefaults.standard.dictionary(forKey: customKey) as? [String: String] ?? [:]
        return names.keys.sorted().map { AyGrammCustomPlugin(id: $0, name: names[$0] ?? $0) }
    }

    // Плагин AyGramm: код на JavaScript с функцией, которая получает текст сообщения и возвращает новый.
    // Функция может называться onOutgoingText или похоже и объявляться через function, const, let, var,
    // export или module.exports. console, window, require и import плагин не ломают.
    static let prelude = "var console = { log: function () {}, info: function () {}, warn: function () {}, error: function () {}, debug: function () {} }; var window = this; var self = this; var module = { exports: {} }; var exports = module.exports; function require() { return {}; }"

    static let resolverScript = """
    (function () {
      var names = ["onOutgoingText", "onOutgoingMessage", "onSendMessage", "onSend", "onMessage", "transformText", "transform", "__aygrammDefault"];
      for (var i = 0; i < names.length; i++) {
        try { var f = eval(names[i]); if (typeof f === "function") { return f; } } catch (e) {}
      }
      var m = module.exports;
      if (typeof m === "function") { return m; }
      if (m && typeof m === "object") {
        for (var j = 0; j < names.length; j++) { if (typeof m[names[j]] === "function") { return m[names[j]]; } }
        if (typeof m["default"] === "function") { return m["default"]; }
      }
      return undefined;
    })()
    """

    // Убирает то, что JavaScriptCore не понимает в обычном скрипте: import и export.
    static func prepareScript(_ code: String) -> String {
        var script = code.replacingOccurrences(of: "\r\n", with: "\n")
        if script.hasPrefix("\u{FEFF}") {
            script.removeFirst()
        }
        let replacements: [(String, String)] = [
            ("(?m)^[ \\t]*import[ \\t][^\\n]*$", ""),
            ("(?m)^[ \\t]*export[ \\t]*\\{[^}]*\\}[ \\t]*;?", ""),
            ("export[ \\t]+default[ \\t]+(async[ \\t]+)?function[ \\t]*\\(", "$1function onOutgoingText("),
            ("export[ \\t]+default[ \\t]+", "var __aygrammDefault = "),
            ("(?m)^([ \\t]*)export[ \\t]+(?=(async[ \\t]+)?(function|const|let|var|class)\\b)", "$1")
        ]
        for (pattern, template) in replacements {
            script = script.replacingOccurrences(of: pattern, with: template, options: .regularExpression)
        }
        return script
    }

    // Запускает код и находит функцию плагина. onError получает ошибки кода, они не мешают найти функцию.
    static func loadPlugin(_ code: String, onError: ((String) -> Void)? = nil) -> (context: JSContext, function: JSValue)? {
        guard let context = JSContext() else {
            return nil
        }
        context.exceptionHandler = { _, exception in
            onError?(exception?.toString() ?? "неизвестная ошибка")
        }
        _ = context.evaluateScript(prelude)
        _ = context.evaluateScript(prepareScript(code))
        guard let function = context.evaluateScript(resolverScript), function.isObject else {
            return nil
        }
        return (context, function)
    }

    // Плагин может вернуть строку или объект с полем text. Пустой ответ не стирает сообщение.
    static func runPlugin(_ function: JSValue, text: String) -> String? {
        guard let value = function.call(withArguments: [text]) else {
            return nil
        }
        if value.isString {
            return value.toString()
        }
        if value.isObject, let field = value.objectForKeyedSubscript("text"), field.isString {
            return field.toString()
        }
        return nil
    }

    static func isValidScript(_ code: String) -> Bool {
        return loadPlugin(code) != nil
    }

    // Плагины exteraGram и других Android-клиентов написаны на Python.
    static func isPythonPlugin(_ code: String) -> Bool {
        return code.range(of: "(?m)^(from [\\w.]+ import |def \\w+\\(|class \\w+\\(BasePlugin\\))", options: .regularExpression) != nil
    }

    // Текст файла в частых кодировках: UTF-8, UTF-16, Windows-1251.
    public static func decodeText(_ data: Data) -> String? {
        var text: String?
        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]) {
            text = String(data: data, encoding: .utf16)
        } else {
            for encoding in [String.Encoding.utf8, .windowsCP1251, .isoLatin1] {
                if let value = String(data: data, encoding: encoding) {
                    text = value
                    break
                }
            }
        }
        if let value = text, value.hasPrefix("\u{FEFF}") {
            return String(value.dropFirst())
        }
        return text
    }

    // Название из первых строк-комментариев: «// Мой плагин» или «// @name Мой плагин».
    // Строки делятся по любым переводам строки, поэтому файлы из Windows тоже подходят.
    static func scriptName(_ code: String) -> String? {
        for line in code.components(separatedBy: .newlines).prefix(8) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("//") {
                var name = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
                if name.hasPrefix("@name") {
                    name = String(name.dropFirst(5)).trimmingCharacters(in: .whitespacesAndNewlines)
                }
                if !name.isEmpty && !name.hasPrefix("@") && !name.hasPrefix("==") {
                    return String(name.prefix(40))
                }
            }
        }
        return nil
    }

    // Добавляет свой плагин из текста буфера обмена: это либо код, либо ссылка на файл .js.
    public static func addCustom(from clipboard: String) -> Signal<AyGrammCustomPluginResult, NoError> {
        return Signal { subscriber in
            Queue.concurrentDefaultQueue().async {
                var code = clipboard.trimmingCharacters(in: .whitespacesAndNewlines)
                if code.hasPrefix("https://") || code.hasPrefix("http://") {
                    var link = code
                    if link.hasPrefix("https://github.com/") && link.contains("/blob/") {
                        link = link.replacingOccurrences(of: "https://github.com/", with: "https://raw.githubusercontent.com/").replacingOccurrences(of: "/blob/", with: "/")
                    }
                    if let url = URL(string: link), let data = try? Data(contentsOf: url), let text = decodeText(data) {
                        code = text
                    } else {
                        subscriber.putNext(.downloadFailed)
                        subscriber.putCompletion()
                        return
                    }
                }
                if code.utf8.count > 1_000_000 {
                    subscriber.putNext(.tooLarge)
                    subscriber.putCompletion()
                    return
                }
                var firstError: String?
                let loaded = loadPlugin(code, onError: { error in
                    if firstError == nil {
                        firstError = error
                    }
                })
                if loaded == nil {
                    subscriber.putNext(isPythonPlugin(code) ? .notJavaScript : .invalid(firstError))
                    subscriber.putCompletion()
                    return
                }
                // Секунды и случайное число: два плагина, добавленные за одну секунду, не затирают друг друга.
                let id = "custom-\(Int(Date().timeIntervalSince1970))-\(Int.random(in: 100 ... 999))"
                let name = scriptName(code) ?? "Мой плагин"
                try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
                guard (try? code.write(to: fileUrl(id: id), atomically: true, encoding: .utf8)) != nil else {
                    subscriber.putNext(.invalid(nil))
                    subscriber.putCompletion()
                    return
                }
                var names = UserDefaults.standard.dictionary(forKey: customKey) as? [String: String] ?? [:]
                names[id] = name
                UserDefaults.standard.set(names, forKey: customKey)
                setEnabled(id: id, enabled: true)
                subscriber.putNext(.installed(name))
                subscriber.putCompletion()
            }
            return EmptyDisposable
        }
    }

    public static func setEnabled(id: String, enabled: Bool) {
        var ids = installedIds.filter { $0 != id }
        if enabled {
            ids.append(id)
        }
        UserDefaults.standard.set(ids, forKey: installedKey)
    }

    // Удаляет все свои плагины, которые сейчас выключены.
    public static func removeDisabledCustom() {
        var names = UserDefaults.standard.dictionary(forKey: customKey) as? [String: String] ?? [:]
        for id in names.keys where !installedIds.contains(id) {
            try? FileManager.default.removeItem(at: fileUrl(id: id))
            names[id] = nil
        }
        UserDefaults.standard.set(names, forKey: customKey)
    }

    // Пропускает текст через все включённые плагины по порядку установки.
    public static func transformOutgoingText(_ text: String) -> String {
        var result = text
        for id in installedIds {
            guard let data = try? Data(contentsOf: fileUrl(id: id)), let script = decodeText(data) else {
                continue
            }
            let name = pluginName(id: id)
            guard let plugin = loadPlugin(script, onError: { error in
                AyGrammPluginLog.add("Ошибка в «\(name)»: " + error)
            }) else {
                continue
            }
            if let string = runPlugin(plugin.function, text: result), !string.isEmpty {
                if string != result {
                    AyGrammPluginLog.add("«\(name)»: " + result + " → " + string)
                }
                result = string
            }
        }
        return result
    }

    // Название для журнала: у своего плагина из первой строки, у плагина каталога его id.
    static func pluginName(id: String) -> String {
        let names = UserDefaults.standard.dictionary(forKey: customKey) as? [String: String] ?? [:]
        return names[id] ?? id
    }
}

// Журнал плагинов: что плагин изменил в сообщении и ошибки в коде плагина. Последние 100 записей.
public enum AyGrammPluginLog {
    static let key = "AyGrammPluginLog"

    public static func entries() -> [String] {
        return UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    static func add(_ text: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM HH:mm"
        var list = entries()
        list.insert(formatter.string(from: Date()) + "  " + String(text.prefix(300)), at: 0)
        UserDefaults.standard.set(Array(list.prefix(100)), forKey: key)
    }

    public static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}

// Встроенный плагин «Подстановки»: {дата}, {время} и {день} заменяются на текущие значения.
func ayGrammReplaceTokens(_ text: String) -> String {
    let now = Date()
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ru_RU")
    var result = text
    formatter.dateFormat = "dd.MM.yyyy"
    result = result.replacingOccurrences(of: "{дата}", with: formatter.string(from: now))
    formatter.dateFormat = "HH:mm"
    result = result.replacingOccurrences(of: "{время}", with: formatter.string(from: now))
    formatter.dateFormat = "EEEE"
    result = result.replacingOccurrences(of: "{день}", with: formatter.string(from: now))
    return result
}

// Исходящие сообщения перед отправкой:
// 1. текст без форматирования проходит через плагины (с форматированием не меняется: новый текст
//    сдвинул бы диапазоны жирного шрифта и ссылок);
// 2. при «Тихой отправке» сообщение получает флаг «без звука».
func ayGrammTransformOutgoing(_ messages: [EnqueueMessage], peerId: PeerId? = nil) -> [EnqueueMessage] {
    // Режим из меню «Отправить» сначала получает исходный текст: перевод, шифровка и голос
    // работают с ним, шрифт и плагины применятся при повторной отправке уже готового текста.
    if let peerId = peerId, AyGrammOutgoing.isArmed(peerId: peerId) {
        return messages
    }
    let usePlugins = AyGrammSettings.pluginsEnabled && !AyGrammPlugins.installedIds.isEmpty
    let silent = AyGrammSettings.silentSend
    let useTokens = AyGrammSettings.value(AyGrammSettings.tokensKey)
    let fontStyle = AyGrammFonts.selected
    let useSnippets = !AyGrammSnippets.isEmpty
    if !usePlugins && !silent && !useTokens && fontStyle == nil && !useSnippets {
        return messages
    }
    return messages.map { message -> EnqueueMessage in
        switch message {
        case let .message(text, attributes, inlineStickers, mediaReference, threadId, replyToMessageId, replyToStoryId, localGroupingKey, correlationId, bubbleUpEmojiOrStickersets):
            // Шифровку нельзя менять: шрифт или плагин испортят шифр.
            if AyGrammCipher.isCipherText(text) {
                return message
            }
            var updatedText = text
            var updatedAttributes = attributes
            var hasEntities = false
            var hasNotificationInfo = false
            for attribute in attributes {
                if let attribute = attribute as? TextEntitiesMessageAttribute, !attribute.entities.isEmpty {
                    hasEntities = true
                }
                if attribute is NotificationInfoMessageAttribute {
                    hasNotificationInfo = true
                }
            }
            // Сокращения «;слово» раньше подстановок, чтобы текст сокращения мог содержать {дата}.
            if useSnippets && !hasEntities && text.contains(";") {
                updatedText = AyGrammSnippets.expand(updatedText)
            }
            if useTokens && !hasEntities && updatedText.contains("{") {
                updatedText = ayGrammReplaceTokens(updatedText)
            }
            if usePlugins && !text.isEmpty && !hasEntities {
                let transformed = AyGrammPlugins.transformOutgoingText(updatedText)
                if !transformed.isEmpty {
                    updatedText = transformed
                }
            }
            // Встроенный плагин «Шрифт сообщений».
            var fontChanged = false
            if let fontStyle = fontStyle, !updatedText.isEmpty && !hasEntities {
                if fontStyle.entity != nil {
                    updatedAttributes = updatedAttributes.filter { !($0 is TextEntitiesMessageAttribute) }
                    updatedAttributes.append(TextEntitiesMessageAttribute(entities: AyGrammFonts.entities(for: updatedText, style: fontStyle)))
                    fontChanged = true
                } else {
                    updatedText = AyGrammFonts.apply(updatedText, style: fontStyle)
                }
            }
            if silent && !hasNotificationInfo {
                updatedAttributes.append(NotificationInfoMessageAttribute(flags: .muted))
            }
            if updatedText == text && updatedAttributes.count == attributes.count && !fontChanged {
                return message
            }
            return .message(text: updatedText, attributes: updatedAttributes, inlineStickers: inlineStickers, mediaReference: mediaReference, threadId: threadId, replyToMessageId: replyToMessageId, replyToStoryId: replyToStoryId, localGroupingKey: localGroupingKey, correlationId: correlationId, bubbleUpEmojiOrStickersets: bubbleUpEmojiOrStickersets)
        case .forward:
            return message
        }
    }
}
