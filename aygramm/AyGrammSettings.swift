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
    public static let silentSendKey = "AyGrammSilentSend"
    public static let keepAliveKey = "AyGrammKeepAlive"
    // Встроенные плагины.
    public static let keepAliveBatteryKey = "AyGrammKeepAliveBattery"
    public static let unlimitedAccountsKey = "AyGrammUnlimitedAccounts"
    public static let decorationsKey = "AyGrammDecorationsEnabled"
    public static let tokensKey = "AyGrammTokens"
    public static let readAloudKey = "AyGrammReadAloud"
    public static let secondsKey = "AyGrammSeconds"
    public static let showIdKey = "AyGrammShowId"
    public static let streamerKey = "AyGrammStreamer"
    public static let filtersKey = "AyGrammFiltersEnabled"
    public static let exportKey = "AyGrammExportEnabled"
    public static let fontButtonKey = "AyGrammFontButton"
    public static let accountAgeKey = "AyGrammAccountAge"
    public static let mutualKey = "AyGrammMutual"
    public static let chatToolsKey = "AyGrammChatTools"
    public static let bombKey = "AyGrammBomb"
    public static let translateKey = "AyGrammTranslate"
    public static let cipherKey = "AyGrammCipher"
    public static let voiceSendKey = "AyGrammVoiceSend"
    public static let autoReplyKey = "AyGrammAutoReply"
    public static let autoReplyMarkKey = "AyGrammAutoReplyMark"
    public static let autoReplyBackgroundKey = "AyGrammAutoReplyBackground"
    public static let autoReplyScheduleKey = "AyGrammAutoReplySchedule"
    static let bannedKey = "AyGrammBanned"
    // Переключатели, которые по умолчанию выключены.
    static let defaultOffKeys: Set<String> = [silentSendKey, keepAliveKey, streamerKey, autoReplyKey, autoReplyBackgroundKey, autoReplyScheduleKey]

    // Действующее значение: при бане всегда выключено.
    public static func value(_ key: String) -> Bool {
        if UserDefaults.standard.bool(forKey: bannedKey) {
            return false
        }
        return storedValue(key)
    }

    // Выбор пользователя в меню, без учёта бана.
    public static func storedValue(_ key: String) -> Bool {
        return UserDefaults.standard.object(forKey: key) as? Bool ?? !defaultOffKeys.contains(key)
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

    // Исходящие сообщения уходят без звука уведомления у получателя.
    public static var silentSend: Bool {
        return value(silentSendKey)
    }

    // Свёрнутый AyGramm держит соединение с Telegram, чтобы приходили звонки и сообщения.
    public static var keepAlive: Bool {
        return value(keepAliveKey)
    }

    // Лимит аккаунтов 1000 вместо 3, с Premium вместо 4.
    public static var unlimitedAccounts: Bool {
        return value(unlimitedAccountsKey)
    }

    // MARK: - Профили настроек «Работа» и «Дом»

    // Все переключатели AyGramm, которые сохраняет профиль.
    public static let profileKeys: [String] = [hideOnlineKey, hideReadKey, hideTypingKey, hideStoryViewsKey, saveDeletedKey, saveEditsKey, pluginsEnabledKey, silentSendKey, keepAliveKey, keepAliveBatteryKey, unlimitedAccountsKey, decorationsKey, tokensKey, readAloudKey, secondsKey, showIdKey, streamerKey, filtersKey, exportKey, fontButtonKey, accountAgeKey, mutualKey, chatToolsKey, bombKey, translateKey, cipherKey, voiceSendKey, autoReplyKey, autoReplyMarkKey, autoReplyBackgroundKey, autoReplyScheduleKey]

    // «14:05» → «14:05:37», «2:05 PM» → «2:05:37 PM». Секунды встают после первого времени в строке.
    public static func addSeconds(_ text: String, timestamp: Int32) -> String {
        var moment = time_t(timestamp)
        var info = tm()
        localtime_r(&moment, &info)
        guard let range = text.range(of: "\\d{1,2}:\\d{2}", options: .regularExpression) else {
            return text
        }
        return text.replacingCharacters(in: range, with: String(text[range]) + String(format: ":%02d", Int(info.tm_sec)))
    }

    static func profileStorageKey(_ name: String) -> String {
        return "AyGrammProfile." + name
    }

    public static func hasProfile(_ name: String) -> Bool {
        return UserDefaults.standard.dictionary(forKey: profileStorageKey(name)) != nil
    }

    public static func saveProfile(_ name: String) {
        var values: [String: Bool] = [:]
        for key in profileKeys {
            values[key] = storedValue(key)
        }
        UserDefaults.standard.set(values, forKey: profileStorageKey(name))
    }

    public static func applyProfile(_ name: String) -> Bool {
        guard let values = UserDefaults.standard.dictionary(forKey: profileStorageKey(name)) as? [String: Bool] else {
            return false
        }
        for (key, value) in values {
            setValue(key, value)
        }
        return true
    }

    // Номер версии AyGramm: номер сборки на GitHub. CFBundleVersion = номер сборки × 100.
    public static var currentVersion: Int {
        let build = Int(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "") ?? 0
        return build / 100
    }
}

// Журнал удалённых сообщений для списка в меню AyGramm и для копирования в буфер обмена.
// Хранится в файле aygramm-deleted.json в папке приложения, последние 1000 записей.
public struct AyGrammDeletedLogEntry: Equatable {
    public let date: Int32
    public let chat: String
    public let author: String
    public let text: String
}

public enum AyGrammDeletedLog {
    static let lock = NSLock()
    static let limit = 1000

    static var fileUrl: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("aygramm-deleted.json")
    }

    static func load() -> [AyGrammDeletedLogEntry] {
        guard let data = try? Data(contentsOf: fileUrl), let items = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [[String: Any]] else {
            return []
        }
        return items.map { item in
            return AyGrammDeletedLogEntry(date: Int32(item["d"] as? Int ?? 0), chat: item["c"] as? String ?? "", author: item["a"] as? String ?? "", text: item["t"] as? String ?? "")
        }
    }

    static func save(_ entries: [AyGrammDeletedLogEntry]) {
        let items: [[String: Any]] = entries.map { entry in
            return ["d": Int(entry.date), "c": entry.chat, "a": entry.author, "t": entry.text]
        }
        if let data = try? JSONSerialization.data(withJSONObject: items, options: []) {
            try? data.write(to: fileUrl, options: .atomic)
        }
    }

    static func append(_ newEntries: [AyGrammDeletedLogEntry]) {
        if newEntries.isEmpty {
            return
        }
        lock.lock()
        defer { lock.unlock() }
        var entries = load()
        entries.append(contentsOf: newEntries)
        if entries.count > limit {
            entries.removeFirst(entries.count - limit)
        }
        save(entries)
    }

    // Записи от новых к старым.
    public static func entries() -> [AyGrammDeletedLogEntry] {
        lock.lock()
        defer { lock.unlock() }
        return Array(load().reversed())
    }

    public static func clear() {
        lock.lock()
        defer { lock.unlock() }
        try? FileManager.default.removeItem(at: fileUrl)
    }

    public static func describe(_ entry: AyGrammDeletedLogEntry) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        var header = formatter.string(from: Date(timeIntervalSince1970: TimeInterval(entry.date))) + " · " + entry.chat
        if !entry.author.isEmpty && entry.author != entry.chat {
            header += " · " + entry.author
        }
        return header + "\n" + entry.text
    }

    public static func exportText() -> String {
        return entries().map { describe($0) }.joined(separator: "\n\n")
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
    var logEntries: [AyGrammDeletedLogEntry] = []
    defer {
        AyGrammDeletedLog.append(logEntries)
    }
    for id in ids {
        transaction.updateMessage(id, update: { currentMessage in
            if currentMessage.ayGrammIsDeleted {
                return .skip
            }
            let chat = currentMessage.peers[currentMessage.id.peerId]?.debugDisplayTitle ?? ""
            let author = currentMessage.author?.debugDisplayTitle ?? ""
            logEntries.append(AyGrammDeletedLogEntry(date: currentMessage.timestamp, chat: chat, author: author, text: currentMessage.text.isEmpty ? "[медиа]" : currentMessage.text))
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
