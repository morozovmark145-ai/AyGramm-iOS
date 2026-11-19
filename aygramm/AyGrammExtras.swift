import Foundation
import Postbox
import SwiftSignalKit
import MtProtoKit

// Функции AyGramm для отправки и чатов: возраст аккаунта, взаимный контакт, шифровка, бомба, перевод,
// отправка голосом, кружок из галереи, стирание своих сообщений, статистика чата и скриншот.
// Всё работает на телефоне через обычные запросы Telegram.

// MARK: - Возраст аккаунта

public enum AyGrammAccountAge {
    // ID пользователя и дата регистрации в секундах с 1970 года. Точки взяты из открытых таблиц
    // python-getids и telegram-id-age и сглажены так, что дата не убывает с ростом ID.
    static let knots: [(Double, Double)] = [
        (0, 1376438400), (2768409, 1383264000), (7679610, 1388448000), (11538514, 1391126400), (15835244, 1392854400), (23646077, 1393372800),
        (38015510, 1393632000), (44634663, 1399248000), (54845238, 1411171200), (63263518, 1414368000), (101260938, 1425600000),
        (103204956, 1433030400), (110306839, 1434240000), (117597704, 1438300800), (124872445, 1439856000), (127929227, 1442620800),
        (143445125, 1448928000), (152956184, 1450742400), (171295414, 1457395200), (181783990, 1460160000), (222021233, 1465344000),
        (278941742, 1473379200), (285253072, 1476748800), (294851037, 1479600000), (297621225, 1481760000), (328594461, 1482883200),
        (337808429, 1487635200), (369669043, 1490832000), (400169472, 1501372800), (805158066, 1563148800), (1974255900, 1633996800),
        (5027173742, 1638921600), (5045293264, 1642032000), (5058656439, 1645833600), (5266729977, 1648425600), (5308260177, 1650844800),
        (5387226589, 1655683200), (5474282362, 1658448000), (5531378275, 1660262400), (5578621357, 1664409600), (5767004208, 1670630400),
        (5832370132, 1674518400), (5926866061, 1676851200), (6136110037, 1682812800), (6326011828, 1688688000), (6462226143, 1698969600),
        (6540611293, 1703894400), (6694418617, 1705881600), (6909688956, 1707696000), (7002435197, 1712361600), (7091188196, 1718150400),
        (7248991615, 1721260800), (7283525500, 1723593600), (7375779833, 1725926400), (7454492493, 1727827200), (7692193285, 1736380800),
        (7824631473, 1738454400), (7866754510, 1749686400), (8045851483, 1752192000), (8200159552, 1757635200), (8330469738, 1761523200),
        (8429898445, 1764201600), (8552684006, 1768089600), (8625334644, 1778025600), (8947299429, 1784937600), (8976922282, 1788566400)
    ]

    static let monthNames = ["январь", "февраль", "март", "апрель", "май", "июнь", "июль", "август", "сентябрь", "октябрь", "ноябрь", "декабрь"]

    // Примерная дата регистрации: линейная интерполяция между соседними точками.
    // После последней точки дата растёт с тем же темпом, но не позже сегодняшнего дня.
    public static func date(userId: Int64) -> Date {
        let id = Double(userId)
        let first = knots[0]
        let last = knots[knots.count - 1]
        let value: Double
        if id <= first.0 {
            value = first.1
        } else if id >= last.0 {
            let previous = knots[knots.count - 4]
            value = last.1 + (id - last.0) * (last.1 - previous.1) / (last.0 - previous.0)
        } else {
            var found = last.1
            for index in 1 ..< knots.count where id <= knots[index].0 {
                let lower = knots[index - 1]
                let upper = knots[index]
                found = lower.1 + (id - lower.0) / (upper.0 - lower.0) * (upper.1 - lower.1)
                break
            }
            value = found
        }
        return Date(timeIntervalSince1970: min(value, Date().timeIntervalSince1970))
    }

    // «≈ март 2019». У ID после 2021 года разброс больше, поэтому там часть года: «≈ середина 2024».
    public static func describe(userId: Int64) -> String {
        let components = Calendar(identifier: .gregorian).dateComponents([.year, .month], from: date(userId: userId))
        let year = components.year ?? 2013
        let month = max(1, min(12, components.month ?? 1))
        if userId < 2_200_000_000 {
            return "≈ \(monthNames[month - 1]) \(year)"
        }
        let part: String
        if month <= 4 {
            part = "начало"
        } else if month <= 8 {
            part = "середина"
        } else {
            part = "конец"
        }
        return "≈ \(part) \(year)"
    }
}

// MARK: - Взаимный контакт

public enum AyGrammMutual {
    // Флаг mutual_contact приходит от Telegram только для людей из ваших контактов.
    // nil: человек не в контактах или это бот, тогда строки в профиле нет.
    public static func describe(user: TelegramUser, isContact: Bool) -> String? {
        if !isContact || user.botInfo != nil {
            return nil
        }
        return user.flags.contains(.mutualContact) ? "Взаимный: вы тоже у него в контактах" : "Не сохранил вас в контакты"
    }
}

// MARK: - Шифровка

// Текст уходит как «🔐 AyGramm: …». Обычный Telegram показывает набор символов, AyGramm с тем же паролем
// показывает текст с пометкой 🔓. Шифр AES-256-CTR, ключ из пароля через PBKDF2-SHA512, 8 байт проверки.
public enum AyGrammCipher {
    static let passwordKey = "AyGrammCipherPassword"
    static let prefix = "🔐 AyGramm: "
    static let lock = NSLock()
    static var cachedKeys: (String, Data, Data)?
    static let cache = NSCache<NSString, NSString>()

    public static var password: String {
        get {
            return UserDefaults.standard.string(forKey: passwordKey) ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: passwordKey)
            cache.removeAllObjects()
        }
    }

    public static func isCipherText(_ text: String) -> Bool {
        return text.hasPrefix(prefix)
    }

    // Ключ шифрования и ключ проверки. Расчёт идёт один раз на пароль.
    static func deriveKeys(_ password: String) -> (Data, Data)? {
        lock.lock()
        defer {
            lock.unlock()
        }
        if let cached = cachedKeys, cached.0 == password {
            return (cached.1, cached.2)
        }
        guard let passwordData = password.data(using: .utf8), let salt = "AyGramm.cipher.v1".data(using: .utf8), let derived = MTPBKDF2(passwordData, salt, 20000) else {
            return nil
        }
        var encryptionInput = derived
        encryptionInput.append(contentsOf: Array("enc".utf8))
        var checkInput = derived
        checkInput.append(contentsOf: Array("mac".utf8))
        let pair = (MTSha256(encryptionInput), MTSha256(checkInput))
        cachedKeys = (password, pair.0, pair.1)
        return pair
    }

    static func check(_ checkKey: Data, _ body: Data) -> Data {
        var input = checkKey
        input.append(body)
        return Data(MTSha256(input).prefix(8))
    }

    static func encode(_ data: Data) -> String {
        return data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }

    static func decode(_ string: String) -> Data? {
        var value = string.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while value.count % 4 != 0 {
            value += "="
        }
        return Data(base64Encoded: value)
    }

    // nil, если пароль не задан.
    public static func encrypt(_ text: String) -> String? {
        let password = self.password
        guard !password.isEmpty, let pair = deriveKeys(password) else {
            return nil
        }
        let iv = Data((0 ..< 16).map { _ in UInt8.random(in: 0 ... 255) })
        guard let encrypted = MTAesCtrDecrypt(Data(text.utf8), pair.0, iv) else {
            return nil
        }
        var body = iv
        body.append(encrypted)
        body.append(check(pair.1, body))
        return prefix + encode(body)
    }

    // Текст для пузыря сообщения. nil: это не шифровка или пароль другой, тогда видна сама шифровка.
    public static func displayText(_ text: String) -> String? {
        guard text.hasPrefix(prefix) else {
            return nil
        }
        if let cached = cache.object(forKey: text as NSString) {
            return cached as String
        }
        let password = self.password
        guard !password.isEmpty, let pair = deriveKeys(password), let body = decode(String(text.dropFirst(prefix.count))), body.count > 24 else {
            return nil
        }
        guard check(pair.1, Data(body.prefix(body.count - 8))) == Data(body.suffix(8)) else {
            return nil
        }
        guard let plain = MTAesCtrDecrypt(Data(body[16 ..< body.count - 8]), pair.0, Data(body.prefix(16))), let string = String(data: plain, encoding: .utf8) else {
            return nil
        }
        let result = "🔓 " + string
        cache.setObject(result as NSString, forKey: text as NSString)
        return result
    }
}

// MARK: - Перевод при отправке

public enum AyGrammTranslate {
    static let languageKey = "AyGrammTranslateLanguage"

    // Код языка и название в винительном падеже для меню: «Перевести на английский».
    public static let languages: [(String, String)] = [
        ("en", "английский"), ("ru", "русский"), ("uk", "украинский"), ("de", "немецкий"), ("es", "испанский"), ("fr", "французский"),
        ("it", "итальянский"), ("pt", "португальский"), ("tr", "турецкий"), ("pl", "польский"), ("kk", "казахский"), ("uz", "узбекский"),
        ("zh", "китайский"), ("ja", "японский"), ("ko", "корейский"), ("ar", "арабский")
    ]

    public static var language: String {
        get {
            return UserDefaults.standard.string(forKey: languageKey) ?? "en"
        }
        set {
            UserDefaults.standard.set(newValue, forKey: languageKey)
        }
    }

    public static var languageName: String {
        let code = language
        return languages.first(where: { $0.0 == code })?.1 ?? code
    }
}

// MARK: - Сообщение-бомба

// Бомба удаляет своё сообщение у всех через выбранное время. Запись о бомбе хранится на телефоне,
// поэтому после перезапуска AyGramm просроченные бомбы срабатывают сразу.
public enum AyGrammBomb {
    static let secondsKey = "AyGrammBombSeconds"
    static let pendingKey = "AyGrammBombPending"
    public static let options: [Int] = [5, 10, 30, 60, 300]
    static let queue = Queue()

    public static var seconds: Int {
        get {
            let value = UserDefaults.standard.integer(forKey: secondsKey)
            return value > 0 ? value : 30
        }
        set {
            UserDefaults.standard.set(newValue, forKey: secondsKey)
        }
    }

    public static func title(_ seconds: Int) -> String {
        return seconds >= 60 ? "\(seconds / 60) мин" : "\(seconds) с"
    }

    public static var secondsTitle: String {
        return title(seconds)
    }

    static func load() -> [[String: Any]] {
        return UserDefaults.standard.array(forKey: pendingKey) as? [[String: Any]] ?? []
    }

    static func save(_ entries: [[String: Any]]) {
        UserDefaults.standard.set(entries, forKey: pendingKey)
    }

    // Запоминает случайный ID каждого сообщения: после отправки у сообщения новый номер, а случайный ID тот же.
    static func schedule(account: Account, ids: [MessageId], seconds: Int) {
        if ids.isEmpty {
            return
        }
        let _ = (account.postbox.transaction { transaction -> [(PeerId, Int64)] in
            var result: [(PeerId, Int64)] = []
            for id in ids {
                if let message = transaction.getMessage(id), let globallyUniqueId = message.globallyUniqueId {
                    result.append((id.peerId, globallyUniqueId))
                }
            }
            return result
        }
        |> deliverOn(queue)).start(next: { items in
            let fireAt = Date().timeIntervalSince1970 + Double(seconds)
            var entries = load()
            for item in items {
                entries.append(["a": account.peerId.toInt64(), "p": item.0.toInt64(), "g": item.1, "t": fireAt])
            }
            save(entries)
            queue.after(Double(seconds), {
                fire(account: account)
            })
        })
    }

    // Удаляет у всех сообщения, у которых вышло время. Сообщение, которое ещё отправляется, ждёт до 10 минут.
    static func fire(account: Account) {
        let now = Date().timeIntervalSince1970
        let accountId = account.peerId.toInt64()
        var due: [(PeerId, Int64, Double)] = []
        var rest: [[String: Any]] = []
        for entry in load() {
            guard let owner = entry["a"] as? Int64, let peer = entry["p"] as? Int64, let globallyUniqueId = entry["g"] as? Int64, let fireAt = entry["t"] as? Double else {
                continue
            }
            if owner == accountId && fireAt <= now + 0.5 {
                due.append((PeerId(peer), globallyUniqueId, fireAt))
            } else {
                rest.append(entry)
            }
        }
        if due.isEmpty {
            return
        }
        save(rest)
        let _ = (account.postbox.transaction { transaction -> ([MessageId], [(PeerId, Int64, Double)]) in
            var ready: [MessageId] = []
            var waiting: [(PeerId, Int64, Double)] = []
            for item in due {
                guard let id = transaction.messageIdForGloballyUniqueMessageId(peerId: item.0, id: item.1) else {
                    continue
                }
                if id.namespace == Namespaces.Message.Cloud {
                    ready.append(id)
                } else if now - item.2 < 600.0 {
                    waiting.append(item)
                }
            }
            return (ready, waiting)
        }
        |> deliverOn(queue)).start(next: { result in
            if !result.0.isEmpty {
                let _ = TelegramEngine(account: account).messages.deleteMessagesInteractively(messageIds: result.0, type: .forEveryone).start()
            }
            if !result.1.isEmpty {
                var entries = load()
                for item in result.1 {
                    entries.append(["a": accountId, "p": item.0.toInt64(), "g": item.1, "t": item.2])
                }
                save(entries)
                queue.after(5.0, {
                    fire(account: account)
                })
            }
        })
    }

    // При входе в аккаунт: просроченные бомбы срабатывают, для остальных ставится таймер.
    public static func resume(account: Account) {
        queue.async {
            fire(account: account)
            let now = Date().timeIntervalSince1970
            let accountId = account.peerId.toInt64()
            for entry in load() {
                if let owner = entry["a"] as? Int64, owner == accountId, let fireAt = entry["t"] as? Double, fireAt > now {
                    queue.after(fireAt - now, {
                        fire(account: account)
                    })
                }
            }
        }
    }
}

// MARK: - Особая отправка из меню «Отправить»

public enum AyGrammSendMode {
    case bomb
    case translate
    case cipher
    case voice
}

public struct AyGrammSendMenuItem {
    public let id: String
    public let title: String
    public let icon: String
    public let mode: AyGrammSendMode
}

public enum AyGrammOutgoing {
    static let lock = NSLock()
    static var armed: (AyGrammSendMode, PeerId, Double)?

    // Озвучка текста для «Отправить голосом». Её ставит TelegramUI при запуске, там есть кодек Opus.
    // Результат: файл OGG/Opus, длительность в секундах и волна для пузыря. nil: озвучить не вышло.
    public static var voiceRenderer: ((String, @escaping ((Data, Int, Data?)?) -> Void) -> Void)?

    public static func arm(_ mode: AyGrammSendMode, peerId: PeerId) {
        lock.lock()
        armed = (mode, peerId, Date().timeIntervalSince1970)
        lock.unlock()
    }

    static func isArmed(peerId: PeerId) -> Bool {
        lock.lock()
        defer {
            lock.unlock()
        }
        guard let current = armed else {
            return false
        }
        return current.1 == peerId && Date().timeIntervalSince1970 - current.2 <= 5.0
    }

    // Режим действует на одну следующую отправку в этот чат в течение 5 секунд.
    static func take(peerId: PeerId) -> AyGrammSendMode? {
        lock.lock()
        defer {
            lock.unlock()
        }
        guard let current = armed else {
            return nil
        }
        if Date().timeIntervalSince1970 - current.2 > 5.0 {
            armed = nil
            return nil
        }
        if current.1 != peerId {
            return nil
        }
        armed = nil
        return current.0
    }

    // Пункты для меню долгого нажатия на «Отправить».
    public static func menuItems(peerId: PeerId) -> [AyGrammSendMenuItem] {
        if AyGrammSettings.isBanned {
            return []
        }
        var items: [AyGrammSendMenuItem] = []
        let isSecret = peerId.namespace == Namespaces.Peer.SecretChat
        if AyGrammSettings.value(AyGrammSettings.bombKey) && !isSecret {
            items.append(AyGrammSendMenuItem(id: "bomb", title: "Бомба: удалить у всех через \(AyGrammBomb.secondsTitle)", icon: "flame.fill", mode: .bomb))
        }
        if AyGrammSettings.value(AyGrammSettings.translateKey) {
            items.append(AyGrammSendMenuItem(id: "translate", title: "Перевести на \(AyGrammTranslate.languageName) и отправить", icon: "globe", mode: .translate))
        }
        if AyGrammSettings.value(AyGrammSettings.cipherKey) && !AyGrammCipher.password.isEmpty {
            items.append(AyGrammSendMenuItem(id: "cipher", title: "Отправить шифровкой", icon: "lock.fill", mode: .cipher))
        }
        if AyGrammSettings.value(AyGrammSettings.voiceSendKey) && voiceRenderer != nil {
            let title = AyGrammVoice.selectedIndex == 0 ? "Отправить голосом" : "Отправить голосом · \(AyGrammVoice.selectedName)"
            items.append(AyGrammSendMenuItem(id: "voice", title: title, icon: "waveform", mode: .voice))
        }
        return items
    }
}

// Вызывается в начале enqueueMessages. nil: обычная отправка. Иначе выбранный режим меняет сообщения
// и отправляет их снова через enqueueMessages, режим к этому моменту уже снят.
func ayGrammSpecialSend(account: Account, peerId: PeerId, messages: [EnqueueMessage]) -> Signal<[MessageId?], NoError>? {
    guard let mode = AyGrammOutgoing.take(peerId: peerId) else {
        return nil
    }
    switch mode {
    case .bomb:
        let seconds = AyGrammBomb.seconds
        return enqueueMessages(account: account, peerId: peerId, messages: messages)
        |> afterNext { ids in
            AyGrammBomb.schedule(account: account, ids: ids.compactMap { $0 }, seconds: seconds)
        }
    case .cipher:
        let updated = messages.map { message -> EnqueueMessage in
            guard case let .message(text, attributes, inlineStickers, mediaReference, threadId, replyToMessageId, replyToStoryId, localGroupingKey, correlationId, bubbleUpEmojiOrStickersets) = message, !text.isEmpty, let encrypted = AyGrammCipher.encrypt(text) else {
                return message
            }
            return .message(text: encrypted, attributes: attributes.filter { !($0 is TextEntitiesMessageAttribute) }, inlineStickers: inlineStickers, mediaReference: mediaReference, threadId: threadId, replyToMessageId: replyToMessageId, replyToStoryId: replyToStoryId, localGroupingKey: localGroupingKey, correlationId: correlationId, bubbleUpEmojiOrStickersets: bubbleUpEmojiOrStickersets)
        }
        return enqueueMessages(account: account, peerId: peerId, messages: updated)
    case .translate:
        let language = AyGrammTranslate.language
        let engine = TelegramEngine(account: account)
        let signals: [Signal<EnqueueMessage, NoError>] = messages.map { message -> Signal<EnqueueMessage, NoError> in
            guard case let .message(text, attributes, inlineStickers, mediaReference, threadId, replyToMessageId, replyToStoryId, localGroupingKey, correlationId, bubbleUpEmojiOrStickersets) = message, !text.isEmpty else {
                return .single(message)
            }
            var entities: [MessageTextEntity] = []
            for attribute in attributes {
                if let attribute = attribute as? TextEntitiesMessageAttribute {
                    entities = attribute.entities
                }
            }
            return engine.messages.translate(text: text, toLang: language, entities: entities)
            |> map { result -> EnqueueMessage in
                guard let result = result, !result.0.isEmpty else {
                    return message
                }
                var updatedAttributes = attributes.filter { !($0 is TextEntitiesMessageAttribute) }
                if !result.1.isEmpty {
                    updatedAttributes.append(TextEntitiesMessageAttribute(entities: result.1))
                }
                return .message(text: result.0, attributes: updatedAttributes, inlineStickers: inlineStickers, mediaReference: mediaReference, threadId: threadId, replyToMessageId: replyToMessageId, replyToStoryId: replyToStoryId, localGroupingKey: localGroupingKey, correlationId: correlationId, bubbleUpEmojiOrStickersets: bubbleUpEmojiOrStickersets)
            }
            |> `catch` { _ -> Signal<EnqueueMessage, NoError> in
                return .single(message)
            }
        }
        return combineLatest(signals)
        |> take(1)
        |> mapToSignal { translated -> Signal<[MessageId?], NoError> in
            return enqueueMessages(account: account, peerId: peerId, messages: translated)
        }
    case .voice:
        guard messages.count == 1, case let .message(text, _, _, mediaReference, threadId, replyToMessageId, _, _, _, _) = messages[0], mediaReference == nil, !text.isEmpty, let renderer = AyGrammOutgoing.voiceRenderer else {
            return enqueueMessages(account: account, peerId: peerId, messages: messages)
        }
        let rendered = Signal<(Data, Int, Data?)?, NoError> { subscriber in
            renderer(text, { result in
                subscriber.putNext(result)
                subscriber.putCompletion()
            })
            return EmptyDisposable
        }
        return rendered
        |> take(1)
        |> mapToSignal { result -> Signal<[MessageId?], NoError> in
            guard let result = result else {
                return enqueueMessages(account: account, peerId: peerId, messages: messages)
            }
            let file = AyGrammMediaSend.voiceFile(account: account, data: result.0, duration: result.1, waveform: result.2)
            return enqueueMessages(account: account, peerId: peerId, messages: [.message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: file), threadId: threadId, replyToMessageId: replyToMessageId, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])])
        }
    }
}

// MARK: - Голосовое и кружок

public enum AyGrammMediaSend {
    static func voiceFile(account: Account, data: Data, duration: Int, waveform: Data?) -> TelegramMediaFile {
        let randomId = Int64.random(in: Int64.min ... Int64.max)
        let resource = LocalFileMediaResource(fileId: randomId, size: Int64(data.count))
        account.postbox.mediaBox.storeResourceData(resource.id, data: data)
        return TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: randomId), partialReference: nil, resource: resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "audio/ogg", size: Int64(data.count), attributes: [.Audio(isVoice: true, duration: duration, title: nil, performer: nil, waveform: waveform)], alternativeRepresentations: [])
    }

    // Готовый квадратный mp4 уходит круглым видеосообщением. Файл переносится в хранилище Telegram.
    public static func roundVideo(account: Account, peerId: PeerId, path: String, duration: Double, side: Int32) -> Signal<Void, NoError> {
        var fileSize: Int64?
        if let attributes = try? FileManager.default.attributesOfItem(atPath: path), let value = attributes[.size] as? NSNumber {
            fileSize = value.int64Value
        }
        let randomId = Int64.random(in: Int64.min ... Int64.max)
        let resource = LocalFileMediaResource(fileId: randomId, size: fileSize)
        account.postbox.mediaBox.moveResourceData(resource.id, fromTempPath: path)
        let file = TelegramMediaFile(fileId: MediaId(namespace: Namespaces.Media.LocalFile, id: randomId), partialReference: nil, resource: resource, previewRepresentations: [], videoThumbnails: [], immediateThumbnailData: nil, mimeType: "video/mp4", size: fileSize, attributes: [.FileName(fileName: "video.mp4"), .Video(duration: duration, size: PixelDimensions(width: side, height: side), flags: [.instantRoundVideo], preloadSize: nil, coverTime: nil, videoCodec: nil)], alternativeRepresentations: [])
        return enqueueMessages(account: account, peerId: peerId, messages: [.message(text: "", attributes: [], inlineStickers: [:], mediaReference: .standalone(media: file), threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: [])])
        |> map { _ -> Void in
            return Void()
        }
    }
}

// MARK: - Стереть свои сообщения

public enum AyGrammCleaner {
    static func location(account: Account, peerId: PeerId) -> SearchMessagesLocation {
        return .peer(peerId: peerId, fromId: account.peerId, tags: nil, reactions: nil, threadId: nil, minDate: nil, maxDate: nil)
    }

    // Число своих сообщений в чате по данным сервера.
    public static func count(account: Account, peerId: PeerId) -> Signal<Int, NoError> {
        return TelegramEngine(account: account).messages.searchMessages(location: location(account: account, peerId: peerId), query: "", state: nil, limit: 1)
        |> take(1)
        |> map { result -> Int in
            return Int(result.0.totalCount)
        }
    }

    // Удаляет у всех свои сообщения страницами по 100. progress получает число удалённых после каждой страницы,
    // сигнал отдаёт итог. Не больше 20 000 сообщений за один запуск.
    public static func deleteAll(account: Account, peerId: PeerId, progress: @escaping (Int) -> Void) -> Signal<Int, NoError> {
        let engine = TelegramEngine(account: account)
        let searchLocation = location(account: account, peerId: peerId)
        func page(state: SearchMessagesState?, done: Set<MessageId>, pages: Int) -> Signal<Int, NoError> {
            return engine.messages.searchMessages(location: searchLocation, query: "", state: state, limit: 100)
            |> take(1)
            |> mapToSignal { result -> Signal<Int, NoError> in
                let fresh = result.0.messages.map { $0.id }.filter { !done.contains($0) }
                if fresh.isEmpty {
                    return .single(done.count)
                }
                var updatedDone = done
                for id in fresh {
                    updatedDone.insert(id)
                }
                let total = updatedDone.count
                let next: Signal<Int, NoError>
                if result.0.completed || pages >= 200 {
                    next = .single(total)
                } else {
                    next = page(state: result.1, done: updatedDone, pages: pages + 1)
                }
                return engine.messages.deleteMessagesInteractively(messageIds: fresh, type: .forEveryone)
                |> mapToSignal { _ -> Signal<Int, NoError> in
                    return .complete()
                }
                |> afterCompleted {
                    progress(total)
                }
                |> then(next)
            }
        }
        return page(state: nil, done: Set(), pages: 0)
    }
}

// MARK: - Статистика чата

public struct AyGrammChatStatsResult {
    public var total: Int = 0
    public var mine: Int = 0
    public var photos: Int = 0
    public var videos: Int = 0
    public var voice: Int = 0
    public var round: Int = 0
    public var files: Int = 0
    public var links: Int = 0
    public var gifs: Int = 0
    public var music: Int = 0
    public var firstMessageId: EngineMessage.Id?
    public var firstDate: Int32?
    public var activeHour: Int?
    public var activeWeekday: Int?
    public var topEmoji: [String] = []
    public var topWords: [String] = []
    public var scanned: Int = 0

    public init() {
    }
}

public enum AyGrammChatStats {
    static let stopWords: Set<String> = ["если", "когда", "тоже", "меня", "тебя", "тебе", "чтобы", "только", "сейчас", "просто", "будет", "очень", "можно", "надо", "есть", "было", "была", "были", "этот", "этого", "этом", "этой", "потом", "тогда", "даже", "всех", "всего", "вообще", "который", "которые", "себя", "себе", "свой", "нету", "пока", "блин", "that", "this", "with", "have", "just", "what", "your"]

    // Счётчики берутся с сервера и точны. Час, день недели, эмодзи и слова считаются
    // по сообщениям, которые уже скачаны на телефон (до 20 000 последних).
    public static func compute(account: Account, peerId: PeerId) -> Signal<AyGrammChatStatsResult, NoError> {
        let engine = TelegramEngine(account: account)
        func count(_ fromId: PeerId?, _ tags: MessageTags?) -> Signal<Int, NoError> {
            return engine.messages.searchMessages(location: .peer(peerId: peerId, fromId: fromId, tags: tags, reactions: nil, threadId: nil, minDate: nil, maxDate: nil), query: "", state: nil, limit: 1)
            |> take(1)
            |> map { result -> Int in
                return Int(result.0.totalCount)
            }
        }
        let counters = combineLatest([
            count(nil, nil), count(account.peerId, nil), count(nil, .photo), count(nil, .video), count(nil, .voice),
            count(nil, .roundVideo), count(nil, .file), count(nil, .webPage), count(nil, .gif), count(nil, .music)
        ])
        let first = engine.messages.searchMessageIdByTimestamp(peerId: peerId, threadId: nil, timestamp: 1)
        |> take(1)
        |> mapToSignal { id -> Signal<(EngineMessage.Id?, Int32?), NoError> in
            guard let id = id else {
                return .single((nil, nil))
            }
            return engine.messages.downloadMessage(messageId: id)
            |> take(1)
            |> map { message -> (EngineMessage.Id?, Int32?) in
                return (id, message?.timestamp)
            }
        }
        let local = account.postbox.transaction { transaction -> AyGrammChatStatsResult in
            var result = AyGrammChatStatsResult()
            var hours = [Int](repeating: 0, count: 24)
            var weekdays = [Int](repeating: 0, count: 7)
            var emoji: [String: Int] = [:]
            var words: [String: Int] = [:]
            var scanned = 0
            let calendar = Calendar.current
            transaction.scanTopMessages(peerId: peerId, namespace: Namespaces.Message.Cloud, limit: 20000, { message in
                scanned += 1
                let date = Date(timeIntervalSince1970: Double(message.timestamp))
                hours[calendar.component(.hour, from: date)] += 1
                weekdays[(calendar.component(.weekday, from: date) + 6) % 7] += 1
                if !message.text.isEmpty && !AyGrammCipher.isCipherText(message.text) {
                    for character in message.text where character.unicodeScalars.first?.properties.isEmojiPresentation == true {
                        emoji[String(character), default: 0] += 1
                    }
                    for word in message.text.lowercased().split(whereSeparator: { !$0.isLetter }) where word.count >= 4 {
                        let value = String(word)
                        if !stopWords.contains(value) {
                            words[value, default: 0] += 1
                        }
                    }
                }
                return true
            })
            result.scanned = scanned
            if scanned > 0 {
                result.activeHour = hours.firstIndex(of: hours.max() ?? 0)
                result.activeWeekday = weekdays.firstIndex(of: weekdays.max() ?? 0)
            }
            result.topEmoji = emoji.sorted(by: { $0.value > $1.value }).prefix(5).map { $0.key }
            result.topWords = words.sorted(by: { $0.value > $1.value }).prefix(5).map { $0.key }
            return result
        }
        return combineLatest(counters, first, local)
        |> take(1)
        |> map { counters, first, local -> AyGrammChatStatsResult in
            var result = local
            if counters.count == 10 {
                result.total = counters[0]
                result.mine = counters[1]
                result.photos = counters[2]
                result.videos = counters[3]
                result.voice = counters[4]
                result.round = counters[5]
                result.files = counters[6]
                result.links = counters[7]
                result.gifs = counters[8]
                result.music = counters[9]
            }
            result.firstMessageId = first.0
            result.firstDate = first.1
            return result
        }
    }
}

// MARK: - Скриншот сообщений

public enum AyGrammShot {
    // Сообщение anchor и до count - 1 следующих за ним, от старых к новым.
    public static func messages(account: Account, anchor: EngineMessage.Id, count: Int) -> Signal<[EngineMessage], NoError> {
        return account.postbox.transaction { transaction -> [EngineMessage] in
            guard let anchorMessage = transaction.getMessage(anchor) else {
                return []
            }
            if count <= 1 {
                return [EngineMessage(anchorMessage)]
            }
            var newer: [Message] = []
            var reached = false
            transaction.scanTopMessages(peerId: anchor.peerId, namespace: anchor.namespace, limit: 5000, { message in
                if message.index <= anchorMessage.index {
                    reached = true
                    return false
                }
                newer.append(message)
                if newer.count > count - 1 {
                    newer.removeFirst()
                }
                return true
            })
            if !reached {
                return [EngineMessage(anchorMessage)]
            }
            return ([anchorMessage] + newer.reversed()).map { EngineMessage($0) }
        }
    }
}

// MARK: - Что нового

// Список для шапки меню AyGramm и для окна после обновления.
public enum AyGrammWhatsNew {
    public static let text = "• Автоответ: расписание, кому отвечать, шаблоны, умные ответы по словам, журнал.\n• Все 213 шрифтов пишут и русскими буквами, слово меняет шрифт сразу при наборе.\n• 21 эффект голоса, при выборе звучит образец.\n• Меню «Отправить»: бомба, перевод, шифровка, отправка голосом.\n• Меню сообщения → AyGramm: статистика, скриншот, кружок, «Напомнить», заметка о человеке, голосовое файлом.\n• Профиль: дата регистрации, взаимный контакт, ваша заметка.\n• Сокращения: ;адрес превращается в ваш текст.\n• Призрак: «Призрак целиком» и обычный режим для выбранных чатов.\n• Экранное время и новое меню AyGramm с логотипом."
    static let seenKey = "AyGrammLastSeenVersion"

    // true один раз после обновления на новую сборку. Первый запуск только запоминает версию.
    public static func shouldShow() -> Bool {
        let current = AyGrammSettings.currentVersion
        let seen = UserDefaults.standard.integer(forKey: seenKey)
        UserDefaults.standard.set(current, forKey: seenKey)
        return seen < current && UserDefaults.standard.bool(forKey: "AyGrammConsentShown")
    }

    public static func markSeen() {
        UserDefaults.standard.set(AyGrammSettings.currentVersion, forKey: seenKey)
    }
}

// MARK: - Экранное время

// Сколько времени AyGramm открыт на экране и сколько раз отправлялись сообщения, по дням.
// Хранится на телефоне за последние 14 дней.
public enum AyGrammScreenTime {
    static let secondsKey = "AyGrammScreenSeconds"
    static let sentKey = "AyGrammScreenSent"
    static var activeSince: Double?

    static func dayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func add(_ key: String, _ value: Double, at date: Date) {
        var table = UserDefaults.standard.dictionary(forKey: key) as? [String: Double] ?? [:]
        let day = dayKey(date)
        table[day] = (table[day] ?? 0.0) + value
        if table.count > 14 {
            for old in table.keys.sorted().prefix(table.count - 14) {
                table.removeValue(forKey: old)
            }
        }
        UserDefaults.standard.set(table, forKey: key)
    }

    // Вызывается при сворачивании и разворачивании AyGramm.
    public static func setActive(_ active: Bool) {
        let now = Date().timeIntervalSince1970
        if active {
            if activeSince == nil {
                activeSince = now
            }
        } else if let since = activeSince {
            activeSince = nil
            add(secondsKey, max(0.0, now - since), at: Date(timeIntervalSince1970: since))
        }
    }

    public static func countSent() {
        add(sentKey, 1.0, at: Date())
    }

    // Сумма за последние days дней, включая сегодня и открытый сейчас сеанс.
    static func total(_ key: String, days: Int) -> Double {
        let table = UserDefaults.standard.dictionary(forKey: key) as? [String: Double] ?? [:]
        var sum = 0.0
        for back in 0 ..< days {
            if let date = Calendar.current.date(byAdding: .day, value: -back, to: Date()) {
                sum += table[dayKey(date)] ?? 0.0
            }
        }
        if key == secondsKey, let since = activeSince {
            sum += max(0.0, Date().timeIntervalSince1970 - since)
        }
        return sum
    }

    static func duration(_ seconds: Double) -> String {
        let minutes = Int(seconds / 60.0)
        if minutes < 60 {
            return "\(minutes) мин"
        }
        return "\(minutes / 60) ч \(minutes % 60) мин"
    }

    public static var todayTitle: String {
        return duration(total(secondsKey, days: 1)) + " · отправок \(Int(total(sentKey, days: 1)))"
    }

    public static var weekTitle: String {
        return duration(total(secondsKey, days: 7)) + " · отправок \(Int(total(sentKey, days: 7)))"
    }
}

// MARK: - Заметки о людях

// Своя заметка о человеке или чате. Видна только на этом телефоне, в профиле и в меню AyGramm.
public enum AyGrammNotes {
    static let key = "AyGrammNotes"

    public static func note(_ peerId: PeerId) -> String? {
        let table = UserDefaults.standard.dictionary(forKey: key) as? [String: String] ?? [:]
        return table["\(peerId.toInt64())"]
    }

    public static func setNote(_ peerId: PeerId, _ text: String) {
        var table = UserDefaults.standard.dictionary(forKey: key) as? [String: String] ?? [:]
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            table.removeValue(forKey: "\(peerId.toInt64())")
        } else {
            table["\(peerId.toInt64())"] = String(trimmed.prefix(500))
        }
        UserDefaults.standard.set(table, forKey: key)
    }
}

// MARK: - Напомнить о сообщении

// Отложенное сообщение самому себе в «Избранное»: в назначенное время Telegram пришлёт уведомление,
// даже если AyGramm закрыт. Шрифты и плагины к напоминанию не применяются.
public enum AyGrammRemind {
    public static func text(message: EngineMessage, peer: EnginePeer?) -> String {
        var body = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if body.isEmpty {
            body = "медиа без подписи"
        }
        if body.count > 300 {
            body = String(body.prefix(300)) + "…"
        }
        var result = "🔔 Напоминание\n«\(body)»"
        if case let .channel(channel)? = peer {
            if let username = channel.addressName, !username.isEmpty {
                result += "\nhttps://t.me/\(username)/\(message.id.id)"
            } else {
                result += "\nhttps://t.me/c/\(message.id.peerId.id._internalGetInt64Value())/\(message.id.id)"
            }
        } else if let peer = peer {
            result += "\nЧат: \(peer.debugDisplayTitle)"
        }
        return result
    }

    public static func schedule(account: Account, text: String, at time: Int32) -> Signal<Bool, NoError> {
        return account.postbox.transaction { transaction -> Bool in
            let ids = enqueueMessages(transaction: transaction, account: account, peerId: account.peerId, messages: [(false, .message(text: text, attributes: [OutgoingScheduleInfoMessageAttribute(scheduleTime: time, repeatPeriod: nil)], inlineStickers: [:], mediaReference: nil, threadId: nil, replyToMessageId: nil, replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: []))])
            return ids.contains(where: { $0 != nil })
        }
    }
}

// MARK: - Голосовое файлом

public enum AyGrammFiles {
    // Путь к скачанному файлу сообщения или nil, если файл ещё не скачан.
    public static func completedPath(account: Account, file: TelegramMediaFile) -> String? {
        return account.postbox.mediaBox.completedResourcePath(file.resource)
    }
}

// MARK: - Сокращения

// Свои сокращения: «;адрес» отдельным словом при отправке заменяется сохранённым текстом.
public enum AyGrammSnippets {
    static let key = "AyGrammSnippets"

    static var table: [String: String] {
        get {
            return UserDefaults.standard.dictionary(forKey: key) as? [String: String] ?? [:]
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }

    public static var isEmpty: Bool {
        return table.isEmpty
    }

    // Сокращения по алфавиту: «;слово» и текст.
    public static var all: [(String, String)] {
        let current = table
        return current.keys.sorted().map { (";" + $0, current[$0] ?? "") }
    }

    static func clean(_ word: String) -> String {
        var name = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        while name.hasPrefix(";") {
            name.removeFirst()
        }
        return name
    }

    public static func set(_ word: String, _ text: String) {
        let name = clean(word)
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty || value.isEmpty || name.contains(" ") {
            return
        }
        var current = table
        current[name] = value
        table = current
    }

    public static func remove(_ word: String) {
        var current = table
        current.removeValue(forKey: clean(word))
        table = current
    }

    public static func expand(_ text: String) -> String {
        let current = table
        if current.isEmpty || !text.contains(";") {
            return text
        }
        var lines: [String] = []
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            var words: [String] = []
            for word in line.split(separator: " ", omittingEmptySubsequences: false) {
                if word.hasPrefix(";"), let value = current[String(word.dropFirst()).lowercased()] {
                    words.append(value)
                } else {
                    words.append(String(word))
                }
            }
            lines.append(words.joined(separator: " "))
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Исключения режима призрака

// Чаты, где прочтение и «печатает…» отправляются как обычно, даже когда режим призрака включён.
public enum AyGrammGhost {
    static let key = "AyGrammGhostExceptions"

    public static var exceptions: Set<Int64> {
        get {
            let stored = UserDefaults.standard.array(forKey: key) as? [NSNumber] ?? []
            return Set(stored.map { $0.int64Value })
        }
        set {
            UserDefaults.standard.set(newValue.map { NSNumber(value: $0) }, forKey: key)
        }
    }

    public static func isException(_ peerId: PeerId) -> Bool {
        return exceptions.contains(peerId.toInt64())
    }

    public static func setException(_ peerId: PeerId, _ value: Bool) {
        var current = exceptions
        if value {
            current.insert(peerId.toInt64())
        } else {
            current.remove(peerId.toInt64())
        }
        exceptions = current
    }
}
