import Foundation
import Postbox

// Настройки AyGramm. Хранятся в UserDefaults, у всех переключателей значение по умолчанию: включено.
public enum AyGrammSettings {
    public static let hideOnlineKey = "AyGrammGhostOnline"
    public static let hideReadKey = "AyGrammGhostRead"
    public static let hideTypingKey = "AyGrammGhostTyping"
    public static let hideStoryViewsKey = "AyGrammGhostStories"
    public static let saveDeletedKey = "AyGrammSaveDeleted"

    // Метка в конце текста сообщения, которое удалили на сервере.
    public static let deletedMark = "🗑 Удалено"

    public static func value(_ key: String) -> Bool {
        return UserDefaults.standard.object(forKey: key) as? Bool ?? true
    }

    public static func setValue(_ key: String, _ value: Bool) {
        UserDefaults.standard.set(value, forKey: key)
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

    // Сообщения, удалённые собеседником, остаются в чате с меткой deletedMark.
    public static var saveDeleted: Bool {
        return value(saveDeletedKey)
    }
}

// Вместо удаления дописывает метку в конец текста. Метка идёт в конец, чтобы не сдвигать
// диапазоны форматирования (жирный, ссылки), которые отсчитываются от начала текста.
func ayGrammMarkMessagesDeleted(transaction: Transaction, ids: [MessageId]) {
    for id in ids {
        transaction.updateMessage(id, update: { currentMessage in
            if currentMessage.text.hasSuffix(AyGrammSettings.deletedMark) {
                return .skip
            }
            let text: String
            if currentMessage.text.isEmpty {
                text = AyGrammSettings.deletedMark
            } else {
                text = currentMessage.text + "\n\n" + AyGrammSettings.deletedMark
            }
            let storeForwardInfo = currentMessage.forwardInfo.flatMap(StoreMessageForwardInfo.init)
            return .update(StoreMessage(id: currentMessage.id, customStableId: nil, globallyUniqueId: currentMessage.globallyUniqueId, groupingKey: currentMessage.groupingKey, threadId: currentMessage.threadId, timestamp: currentMessage.timestamp, flags: StoreMessageFlags(currentMessage.flags), tags: currentMessage.tags, globalTags: currentMessage.globalTags, localTags: currentMessage.localTags, forwardInfo: storeForwardInfo, authorId: currentMessage.author?.id, text: text, attributes: currentMessage.attributes, media: currentMessage.media))
        })
    }
}
