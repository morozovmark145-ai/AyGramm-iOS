import Foundation
import Postbox

// Настройки AyGramm в UserDefaults. У переключателей значение по умолчанию: включено.
// Если автор AyGramm забанил аккаунт в канале @augrammipa, все функции AyGramm выключены.
public enum AyGrammSettings {
    public static let hideOnlineKey = "AyGrammGhostOnline"
    public static let hideReadKey = "AyGrammGhostRead"
    public static let hideTypingKey = "AyGrammGhostTyping"
    public static let hideStoryViewsKey = "AyGrammGhostStories"
    public static let saveDeletedKey = "AyGrammSaveDeleted"
    public static let saveEditsKey = "AyGrammSaveEdits"
    public static let pluginsEnabledKey = "AyGrammPluginsEnabled"
    static let bannedKey = "AyGrammBanned"

    // Действующее значение: при бане всегда выключено.
    public static func value(_ key: String) -> Bool {
        if UserDefaults.standard.bool(forKey: bannedKey) {
            return false
        }
        return storedValue(key)
    }

    // Выбор пользователя в меню, без учёта бана.
    public static func storedValue(_ key: String) -> Bool {
        return UserDefaults.standard.object(forKey: key) as? Bool ?? true
    }

    public static func setValue(_ key: String, _ value: Bool) {
        UserDefaults.standard.set(value, forKey: key)
    }

    public static var isBanned: Bool {
        get {
            return UserDefaults.standard.bool(forKey: bannedKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: bannedKey)
        }
    }

    // Сервер не получает статус «в сети».
    public static var hideOnline: Bool {
        return value(hideOnlineKey)
    }

    // Сервер не получает отметки о прочтении.
    public static var hideRead: Bool {
        return value(hideReadKey)
    }

    // Сервер не получает «печатает…».
    public static var hideTyping: Bool {
        return value(hideTypingKey)
    }

    // Сервер не получает просмотры историй.
    public static var hideStoryViews: Bool {
        return value(hideStoryViewsKey)
    }

    // Сообщения, удалённые собеседником, остаются в чате с меткой AyGrammDeletedMessageAttribute.
    public static var saveDeleted: Bool {
        return value(saveDeletedKey)
    }

    // Прежний текст сообщения сохраняется при каждой правке.
    public static var saveEdits: Bool {
        return value(saveEditsKey)
    }

    // Плагины из каталога меняют текст исходящих сообщений.
    public static var pluginsEnabled: Bool {
        return value(pluginsEnabledKey)
    }
}

// Метка удалённого сообщения. Хранится внутри сообщения в базе на устройстве и на сервер не уходит.
public class AyGrammDeletedMessageAttribute: MessageAttribute {
    public let date: Int32

    public init(date: Int32) {
        self.date = date
    }

    required public init(decoder: PostboxDecoder) {
        self.date = decoder.decodeInt32ForKey("d", orElse: 0)
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32(self.date, forKey: "d")
    }
}

// Прежние версии текста: dates[i] — когда версия была актуальна, texts[i] — её текст.
public class AyGrammEditHistoryMessageAttribute: MessageAttribute {
    public let dates: [Int32]
    public let texts: [String]

    public init(dates: [Int32], texts: [String]) {
        self.dates = dates
        self.texts = texts
    }

    required public init(decoder: PostboxDecoder) {
        self.dates = decoder.decodeInt32ArrayForKey("d")
        self.texts = decoder.decodeStringArrayForKey("t")
    }

    public func encode(_ encoder: PostboxEncoder) {
        encoder.encodeInt32Array(self.dates, forKey: "d")
        encoder.encodeStringArray(self.texts, forKey: "t")
    }
}

public extension Message {
    var ayGrammIsDeleted: Bool {
        return self.attributes.contains(where: { $0 is AyGrammDeletedMessageAttribute })
    }
}

// Вместо удаления сообщение получает метку AyGrammDeletedMessageAttribute. Текст и медиа остаются.
func ayGrammMarkMessagesDeleted(transaction: Transaction, ids: [MessageId]) {
    let date = Int32(Date().timeIntervalSince1970)
    for id in ids {
        transaction.updateMessage(id, update: { currentMessage in
            if currentMessage.ayGrammIsDeleted {
                return .skip
            }
            var attributes = currentMessage.attributes
            attributes.append(AyGrammDeletedMessageAttribute(date: date))
            let storeForwardInfo = currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init)
            return .update(StoreMessage(id: currentMessage.id, customStableId: nil, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: currentMessage.text, attributes: attributes, media: currentMessage.media))
        })
    }
}

// Правка с сервера: прежний текст уходит в историю, метки AyGramm переносятся в новую версию сообщения.
func ayGrammWithEditHistory(previous: Message, updated: StoreMessage) -> StoreMessage {
    var dates: [Int32] = []
    var texts: [String] = []
    var deletedAttribute: AyGrammDeletedMessageAttribute?
    for attribute in previous.attributes {
        if let attribute = attribute as? AyGrammEditHistoryMessageAttribute {
            dates = attribute.dates
            texts = attribute.texts
        } else if let attribute = attribute as? AyGrammDeletedMessageAttribute {
            deletedAttribute = attribute
        }
    }
    if AyGrammSettings.saveEdits && previous.text != updated.text {
        dates.append(previous.editedTime ?? previous.timestamp)
        texts.append(previous.text)
    }
    if texts.isEmpty && deletedAttribute == nil {
        return updated
    }
    var attributes = updated.attributes.filter { !($0 is AyGrammEditHistoryMessageAttribute) && !($0 is AyGrammDeletedMessageAttribute) }
    if !texts.isEmpty {
        attributes.append(AyGrammEditHistoryMessageAttribute(dates: dates, texts: texts))
    }
    if let deletedAttribute = deletedAttribute {
        attributes.append(deletedAttribute)
    }
    return StoreMessage(id: previous.id, customStableId: updated.customStableId, globallyUniqueId: updated.globallyUniqueId, groupingKey: updated.groupingKey, threadId: updated.threadId, timestamp: updated.timestamp, flags: updated.flags, tags: updated.tags, globalTags: updated.globalTags, localTags: updated.localTags, forwardInfo: updated.forwardInfo, authorId: updated.authorId, text: updated.text, attributes: attributes, media: updated.media)
}

// Текст для окна «История изменений»: все прежние версии и текущая. nil, если правок не было.
public func ayGrammEditHistoryDescription(_ message: Message) -> String? {
    var history: AyGrammEditHistoryMessageAttribute?
    for attribute in message.attributes {
        if let attribute = attribute as? AyGrammEditHistoryMessageAttribute {
            history = attribute
        }
    }
    guard let history = history, !history.texts.isEmpty else {
        return nil
    }
    let formatter = DateFormatter()
    formatter.dateFormat = "dd.MM.yyyy HH:mm"
    var parts: [String] = []
    for (index, text) in history.texts.enumerated() {
        let date = index < history.dates.count ? history.dates[index] : 0
        parts.append(formatter.string(from: Date(timeIntervalSince1970: TimeInterval(date))) + "\n" + text)
    }
    parts.append("Сейчас\n" + message.text)
    return parts.joined(separator: "\n\n")
}
