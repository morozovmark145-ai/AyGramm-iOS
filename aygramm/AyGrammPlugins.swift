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

    // Пропускает текст через все включённые плагины по порядку установки.
    public static func transformOutgoingText(_ text: String) -> String {
        var result = text
        for id in installedIds {
            guard let script = try? String(contentsOf: fileUrl(id: id), encoding: .utf8), let context = JSContext() else {
                continue
            }
            _ = context.evaluateScript(script)
            guard let function = context.objectForKeyedSubscript("onOutgoingText"), !function.isUndefined else {
                continue
            }
            if let value = function.call(withArguments: [result]), value.isString, let string = value.toString() {
                result = string
            }
        }
        return result
    }
}

// Исходящие текстовые сообщения без форматирования проходят через плагины перед отправкой.
// Сообщения с форматированием не меняются: новый текст сдвинул бы диапазоны жирного шрифта и ссылок.
func ayGrammTransformOutgoing(_ messages: [EnqueueMessage]) -> [EnqueueMessage] {
    if !AyGrammSettings.pluginsEnabled || AyGrammPlugins.installedIds.isEmpty {
        return messages
    }
    return messages.map { message -> EnqueueMessage in
        switch message {
        case let .message(text, attributes, inlineStickers, mediaReference, threadId, replyToMessageId, replyToStoryId, localGroupingKey, correlationId, bubbleUpEmojiOrStickersets):
            if text.isEmpty {
                return message
            }
            for attribute in attributes {
                if let attribute = attribute as? TextEntitiesMessageAttribute, !attribute.entities.isEmpty {
                    return message
                }
            }
            let updatedText = AyGrammPlugins.transformOutgoingText(text)
            if updatedText == text || updatedText.isEmpty {
                return message
            }
            return .message(text: updatedText, attributes: attributes, inlineStickers: inlineStickers, mediaReference: mediaReference, threadId: threadId, replyToMessageId: replyToMessageId, replyToStoryId: replyToStoryId, localGroupingKey: localGroupingKey, correlationId: correlationId, bubbleUpEmojiOrStickersets: bubbleUpEmojiOrStickersets)
        case .forward:
            return message
        }
    }
}
