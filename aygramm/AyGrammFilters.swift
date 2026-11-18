import Foundation
import Postbox
import SwiftSignalKit

// Фильтры в группах и каналах: сообщения со словами из списка и сообщения скрытых людей
// не попадают в ленту чата. Личные и секретные чаты, свои сообщения и реклама не фильтруются.
public enum AyGrammFilters {
    static let wordsKey = "AyGrammFilterWords"
    static let authorsKey = "AyGrammFilterAuthors"

    public static var words: [String] {
        return UserDefaults.standard.stringArray(forKey: wordsKey) ?? []
    }

    // Слова через запятую или с новой строки. Возвращает, сколько слов добавлено.
    public static func addWords(from text: String) -> Int {
        var list = words
        var added = 0
        for part in text.components(separatedBy: CharacterSet(charactersIn: ",\n")) {
            let word = part.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !word.isEmpty && word.count <= 100 && !list.contains(word) {
                list.append(word)
                added += 1
            }
        }
        UserDefaults.standard.set(list, forKey: wordsKey)
        return added
    }

    public static func removeWord(_ word: String) {
        UserDefaults.standard.set(words.filter { $0 != word }, forKey: wordsKey)
    }

    // Скрытые люди: ID → имя на момент скрытия.
    public static var authors: [(Int64, String)] {
        let stored = UserDefaults.standard.dictionary(forKey: authorsKey) as? [String: String] ?? [:]
        return stored.compactMap { key, value -> (Int64, String)? in
            guard let id = Int64(key) else {
                return nil
            }
            return (id, value)
        }.sorted { $0.1 < $1.1 }
    }

    public static func hideAuthor(id: Int64, name: String) {
        var stored = UserDefaults.standard.dictionary(forKey: authorsKey) as? [String: String] ?? [:]
        stored["\(id)"] = name
        UserDefaults.standard.set(stored, forKey: authorsKey)
    }

    public static func showAuthor(id: Int64) {
        var stored = UserDefaults.standard.dictionary(forKey: authorsKey) as? [String: String] ?? [:]
        stored["\(id)"] = nil
        UserDefaults.standard.set(stored, forKey: authorsKey)
    }

    public static func shouldHide(_ message: Message) -> Bool {
        if !AyGrammSettings.value(AyGrammSettings.filtersKey) {
            return false
        }
        let namespace = message.id.peerId.namespace
        if namespace == Namespaces.Peer.CloudUser || namespace == Namespaces.Peer.SecretChat {
            return false
        }
        if !message.flags.contains(.Incoming) {
            return false
        }
        if let author = message.author {
            let stored = UserDefaults.standard.dictionary(forKey: authorsKey) ?? [:]
            if stored["\(author.id.id._internalGetInt64Value())"] != nil {
                return true
            }
        }
        let list = words
        if list.isEmpty || message.text.isEmpty {
            return false
        }
        let text = message.text.lowercased()
        for word in list where text.contains(word) {
            return true
        }
        return false
    }
}

// Экспорт чата: сообщения, которые уже скачаны на телефон, в текстовый файл.
// Чат с запретом копирования не экспортируется.
public enum AyGrammExport {
    public static func chatFile(account: Account, peerId: PeerId) -> Signal<URL?, NoError> {
        return account.postbox.transaction { transaction -> URL? in
            var messages: [Message] = []
            transaction.scanTopMessages(peerId: peerId, namespace: Namespaces.Message.Cloud, limit: 50000, { message in
                messages.append(message)
                return true
            })
            if messages.isEmpty || messages.contains(where: { $0.isCopyProtected() }) {
                return nil
            }
            messages.sort { $0.index < $1.index }
            let formatter = DateFormatter()
            formatter.dateFormat = "dd.MM.yyyy HH:mm:ss"
            let title = transaction.getPeer(peerId)?.debugDisplayTitle ?? "Чат"
            var lines: [String] = ["Чат «\(title)», сообщений: \(messages.count). Экспорт из AyGramm.", ""]
            for message in messages {
                let date = formatter.string(from: Date(timeIntervalSince1970: Double(message.timestamp)))
                let author = message.author?.debugDisplayTitle ?? title
                var parts: [String] = []
                for media in message.media {
                    if media is TelegramMediaImage {
                        parts.append("[фото]")
                    } else if let file = media as? TelegramMediaFile {
                        parts.append(file.fileName.map { "[файл \($0)]" } ?? "[файл]")
                    } else {
                        parts.append("[вложение]")
                    }
                }
                if !message.text.isEmpty {
                    parts.append(message.text)
                }
                lines.append("[\(date)] \(author): " + parts.joined(separator: " "))
            }
            let safeTitle = title.components(separatedBy: CharacterSet(charactersIn: "/\\:?*\"<>|")).joined(separator: "_")
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(String(safeTitle.prefix(60)) + ".txt")
            do {
                try lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
            } catch {
                return nil
            }
            return url
        }
    }
}
