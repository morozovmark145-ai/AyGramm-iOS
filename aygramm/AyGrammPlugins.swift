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
    case invalid
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

    // Код считается плагином, если выполняется без ошибки и объявляет функцию onOutgoingText.
    static func isValidScript(_ code: String) -> Bool {
        guard code.contains("onOutgoingText"), let context = JSContext() else {
            return false
        }
        _ = context.evaluateScript(code)
        if context.exception != nil {
            return false
        }
        guard let function = context.objectForKeyedSubscript("onOutgoingText"), !function.isUndefined else {
            return false
        }
        return true
    }

    // Название из первой строки-комментария: «// Мой плагин».
    static func scriptName(_ code: String) -> String? {
        for line in code.split(separator: "\n").prefix(5) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("//") {
                let name = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if !name.isEmpty {
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
                    if let url = URL(string: code), let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) {
                        code = text
                    } else {
                        subscriber.putNext(.downloadFailed)
                        subscriber.putCompletion()
                        return
                    }
                }
                if !isValidScript(code) {
                    subscriber.putNext(.invalid)
                    subscriber.putCompletion()
                    return
                }
                let id = "custom-\(Int(Date().timeIntervalSince1970))"
                let name = scriptName(code) ?? "Мой плагин"
                try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
                guard (try? code.write(to: fileUrl(id: id), atomically: true, encoding: .utf8)) != nil else {
                    subscriber.putNext(.invalid)
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
            guard let script = try? String(contentsOf: fileUrl(id: id), encoding: .utf8), let context = JSContext() else {
                continue
            }
            let name = pluginName(id: id)
            context.exceptionHandler = { _, exception in
                AyGrammPluginLog.add("Ошибка в «\(name)»: " + (exception?.toString() ?? "неизвестная ошибка"))
            }
            _ = context.evaluateScript(script)
            guard let function = context.objectForKeyedSubscript("onOutgoingText"), !function.isUndefined else {
                continue
            }
            if let value = function.call(withArguments: [result]), value.isString, let string = value.toString() {
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
func ayGrammTransformOutgoing(_ messages: [EnqueueMessage]) -> [EnqueueMessage] {
    let usePlugins = AyGrammSettings.pluginsEnabled && !AyGrammPlugins.installedIds.isEmpty
    let silent = AyGrammSettings.silentSend
    let useTokens = AyGrammSettings.value(AyGrammSettings.tokensKey)
    if !usePlugins && !silent && !useTokens {
        return messages
    }
    return messages.map { message -> EnqueueMessage in
        switch message {
        case let .message(text, attributes, inlineStickers, mediaReference, threadId, replyToMessageId, replyToStoryId, localGroupingKey, correlationId, bubbleUpEmojiOrStickersets):
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
            if useTokens && !hasEntities && text.contains("{") {
                updatedText = ayGrammReplaceTokens(updatedText)
            }
            if usePlugins && !text.isEmpty && !hasEntities {
                let transformed = AyGrammPlugins.transformOutgoingText(updatedText)
                if !transformed.isEmpty {
                    updatedText = transformed
                }
            }
            if silent && !hasNotificationInfo {
                updatedAttributes.append(NotificationInfoMessageAttribute(flags: .muted))
            }
            if updatedText == text && updatedAttributes.count == attributes.count {
                return message
            }
            return .message(text: updatedText, attributes: updatedAttributes, inlineStickers: inlineStickers, mediaReference: mediaReference, threadId: threadId, replyToMessageId: replyToMessageId, replyToStoryId: replyToStoryId, localGroupingKey: localGroupingKey, correlationId: correlationId, bubbleUpEmojiOrStickersets: bubbleUpEmojiOrStickersets)
        case .forward:
            return message
        }
    }
}
