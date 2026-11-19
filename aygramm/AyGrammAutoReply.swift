import Foundation
import Postbox
import SwiftSignalKit

// Автоответ в личных чатах. Работает, пока AyGramm запущен: в свёрнутом виде нужен переключатель «Звонки в фоне».
// Порядок проверки нового сообщения:
// 1. Автоответ включён, подходит расписание и режим «только когда свёрнут».
// 2. Сообщение входящее, из личного чата с человеком: боты, Telegram 777000 и поддержка пропускаются.
// 3. Сообщение не старше 10 минут: после долгого офлайна старые сообщения не получают ответ.
// 4. Сообщение начинается не с 🤖: два автоответа не отвечают друг другу.
// 5. Человек не в исключениях, подходит выбор «кому отвечать».
// 6. Пауза: один ответ человеку раз в выбранный срок, умные ответы раз в 2 минуты на каждое слово.
// 7. Лимит: не больше 30 автоответов в час на все чаты.
// 8. После задержки: если хозяин уже ответил сам или прочитал чат, автоответ не уходит.
public struct AyGrammAutoReplyRule: Equatable {
    public let keyword: String
    public let answer: String

    public init(keyword: String, answer: String) {
        self.keyword = keyword
        self.answer = answer
    }
}

public enum AyGrammAutoReply {
    static let textKey = "AyGrammAutoReplyText"
    static let fromHourKey = "AyGrammAutoReplyFrom"
    static let toHourKey = "AyGrammAutoReplyTo"
    static let audienceKey = "AyGrammAutoReplyAudience"
    static let cooldownKey = "AyGrammAutoReplyCooldown"
    static let delayKey = "AyGrammAutoReplyDelay"
    static let rulesKey = "AyGrammAutoReplyRules"
    static let excludedKey = "AyGrammAutoReplyExcluded"
    static let logKey = "AyGrammAutoReplyLog"
    static let countKey = "AyGrammAutoReplyCount"

    public static let defaultText = "Привет, {имя}! Сейчас не могу ответить, напишу, как освобожусь."
    public static let audiences: [String] = ["Всем", "Только контактам", "Только незнакомым"]
    public static let cooldowns: [(Int, String)] = [(15, "раз в 15 минут"), (60, "раз в час"), (180, "раз в 3 часа"), (360, "раз в 6 часов"), (1440, "раз в день")]
    public static let delays: [(Int, String)] = [(0, "сразу"), (10, "через 10 секунд"), (30, "через 30 секунд"), (60, "через минуту"), (300, "через 5 минут")]
    static let maxPerHour = 30
    static let maxMessageAge: Int32 = 600
    static let rulePause: Double = 120.0

    // TelegramUI пишет сюда true, пока AyGramm открыт на экране.
    public static var isAppActive = true

    static let queue = Queue()
    static var attached: [PeerId: Disposable] = [:]
    static var lastReply: [String: Double] = [:]
    static var recentReplies: [Double] = []
    static var handledIds = Set<MessageId>()

    // MARK: Настройки

    public static var text: String {
        get {
            return UserDefaults.standard.string(forKey: textKey) ?? defaultText
        }
        set {
            UserDefaults.standard.set(newValue, forKey: textKey)
        }
    }

    public static var fromHour: Int {
        get {
            return UserDefaults.standard.object(forKey: fromHourKey) as? Int ?? 23
        }
        set {
            UserDefaults.standard.set(newValue, forKey: fromHourKey)
        }
    }

    public static var toHour: Int {
        get {
            return UserDefaults.standard.object(forKey: toHourKey) as? Int ?? 8
        }
        set {
            UserDefaults.standard.set(newValue, forKey: toHourKey)
        }
    }

    // 0: всем, 1: только контактам, 2: только незнакомым.
    public static var audience: Int {
        get {
            let value = UserDefaults.standard.integer(forKey: audienceKey)
            return value >= 0 && value < audiences.count ? value : 0
        }
        set {
            UserDefaults.standard.set(newValue, forKey: audienceKey)
        }
    }

    public static var cooldownMinutes: Int {
        get {
            return UserDefaults.standard.object(forKey: cooldownKey) as? Int ?? 60
        }
        set {
            UserDefaults.standard.set(newValue, forKey: cooldownKey)
        }
    }

    public static var delaySeconds: Int {
        get {
            return UserDefaults.standard.integer(forKey: delayKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: delayKey)
        }
    }

    public static var cooldownTitle: String {
        let value = cooldownMinutes
        return cooldowns.first(where: { $0.0 == value })?.1 ?? "раз в \(value) мин"
    }

    public static var delayTitle: String {
        let value = delaySeconds
        return delays.first(where: { $0.0 == value })?.1 ?? "через \(value) с"
    }

    public static var scheduleTitle: String {
        return String(format: "с %02d:00 до %02d:00", fromHour, toHour)
    }

    // Умные ответы: слово в сообщении и ответ на него. Проверяются раньше основного текста.
    public static var rules: [AyGrammAutoReplyRule] {
        get {
            let stored = UserDefaults.standard.array(forKey: rulesKey) as? [[String]] ?? []
            return stored.compactMap { pair in
                return pair.count == 2 ? AyGrammAutoReplyRule(keyword: pair[0], answer: pair[1]) : nil
            }
        }
        set {
            UserDefaults.standard.set(newValue.map { [$0.keyword, $0.answer] }, forKey: rulesKey)
        }
    }

    public static func addRule(keyword: String, answer: String) -> Bool {
        let keyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        let answer = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        if keyword.isEmpty || answer.isEmpty {
            return false
        }
        var current = rules.filter { $0.keyword.lowercased() != keyword.lowercased() }
        current.append(AyGrammAutoReplyRule(keyword: keyword, answer: answer))
        rules = current
        return true
    }

    public static func removeRule(keyword: String) {
        rules = rules.filter { $0.keyword != keyword }
    }

    // Люди, которым автоответ не отвечает. Добавляются в меню сообщения: AyGramm → Автоответ.
    public static var excluded: Set<Int64> {
        get {
            let stored = UserDefaults.standard.array(forKey: excludedKey) as? [NSNumber] ?? []
            return Set(stored.map { $0.int64Value })
        }
        set {
            UserDefaults.standard.set(newValue.map { NSNumber(value: $0) }, forKey: excludedKey)
        }
    }

    public static func isExcluded(_ peerId: PeerId) -> Bool {
        return excluded.contains(peerId.toInt64())
    }

    public static func setExcluded(_ peerId: PeerId, _ value: Bool) {
        var current = excluded
        if value {
            current.insert(peerId.toInt64())
        } else {
            current.remove(peerId.toInt64())
        }
        excluded = current
    }

    public static var log: [String] {
        return UserDefaults.standard.stringArray(forKey: logKey) ?? []
    }

    public static var sentCount: Int {
        return UserDefaults.standard.integer(forKey: countKey)
    }

    public static func clearLog() {
        UserDefaults.standard.removeObject(forKey: logKey)
        UserDefaults.standard.removeObject(forKey: countKey)
    }

    static func addLog(name: String, text: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM HH:mm"
        var list = log
        list.insert(formatter.string(from: Date()) + " · " + name + ": " + String(text.prefix(80)), at: 0)
        UserDefaults.standard.set(Array(list.prefix(50)), forKey: logKey)
        UserDefaults.standard.set(sentCount + 1, forKey: countKey)
    }

    // MARK: Работа

    // Автоответ сейчас отвечает: включён, подходит расписание и режим «только когда свёрнут».
    public static var isActiveNow: Bool {
        if !AyGrammSettings.value(AyGrammSettings.autoReplyKey) {
            return false
        }
        if AyGrammSettings.value(AyGrammSettings.autoReplyBackgroundKey) && isAppActive {
            return false
        }
        if AyGrammSettings.value(AyGrammSettings.autoReplyScheduleKey) {
            let hour = Calendar.current.component(.hour, from: Date())
            let from = fromHour
            let to = toHour
            if from < to {
                return hour >= from && hour < to
            } else if from > to {
                return hour >= from || hour < to
            }
        }
        return true
    }

    // Строка для меню AyGramm: «выкл», «отвечает» или «ждёт расписания».
    public static var statusTitle: String {
        if !AyGrammSettings.value(AyGrammSettings.autoReplyKey) {
            return "выкл"
        }
        return isActiveNow ? "отвечает" : "ждёт"
    }

    // Подписка на новые сообщения аккаунта. Повторный вызов для того же аккаунта ничего не делает.
    public static func attach(account: Account) {
        queue.async {
            if attached[account.peerId] != nil {
                return
            }
            attached[account.peerId] = (account.stateManager.notificationMessages
            |> deliverOn(queue)).start(next: { list in
                for item in list {
                    for message in item.0 {
                        handle(account: account, message: message)
                    }
                }
            })
        }
    }

    static func handle(account: Account, message: Message) {
        if !isActiveNow {
            return
        }
        if !message.flags.contains(.Incoming) || message.id.namespace != Namespaces.Message.Cloud {
            return
        }
        let peerId = message.id.peerId
        if peerId.namespace != Namespaces.Peer.CloudUser || peerId == account.peerId {
            return
        }
        guard let user = (message.peers[peerId] ?? message.author) as? TelegramUser else {
            return
        }
        if user.botInfo != nil || user.flags.contains(.isSupport) || peerId.id._internalGetInt64Value() == 777000 {
            return
        }
        let now = Date().timeIntervalSince1970
        if Int32(now) - message.timestamp > maxMessageAge {
            return
        }
        if message.text.hasPrefix("🤖") {
            return
        }
        if handledIds.contains(message.id) {
            return
        }
        if handledIds.count > 500 {
            handledIds.removeAll()
        }
        handledIds.insert(message.id)
        if isExcluded(peerId) {
            return
        }
        let lowered = message.text.lowercased()
        let rule = lowered.isEmpty ? nil : rules.first(where: { lowered.contains($0.keyword.lowercased()) })
        let key: String
        let pause: Double
        if let rule = rule {
            key = "\(peerId.toInt64()):\(rule.keyword.lowercased())"
            pause = rulePause
        } else {
            key = "\(peerId.toInt64())"
            pause = Double(cooldownMinutes * 60)
        }
        if let last = lastReply[key], now - last < pause {
            return
        }
        recentReplies = recentReplies.filter { now - $0 < 3600.0 }
        if recentReplies.count >= maxPerHour {
            return
        }
        let template = rule?.answer ?? text
        if template.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return
        }
        lastReply[key] = now
        recentReplies.append(now)
        let delay = Double(delaySeconds)
        let name = user.firstName ?? user.username ?? ""
        if delay > 0.0 {
            queue.after(delay, {
                send(account: account, message: message, name: name, template: template, checkRead: true)
            })
        } else {
            send(account: account, message: message, name: name, template: template, checkRead: false)
        }
    }

    static func fill(_ template: String, name: String) -> String {
        let time = DateFormatter()
        time.dateFormat = "HH:mm"
        let day = DateFormatter()
        day.dateFormat = "dd.MM"
        let now = Date()
        return template.replacingOccurrences(of: "{имя}", with: name).replacingOccurrences(of: "{время}", with: time.string(from: now)).replacingOccurrences(of: "{дата}", with: day.string(from: now))
    }

    static func send(account: Account, message: Message, name: String, template: String, checkRead: Bool) {
        if !isActiveNow {
            return
        }
        let peerId = message.id.peerId
        let incomingIndex = message.index
        var replyText = fill(template, name: name)
        if AyGrammSettings.value(AyGrammSettings.autoReplyMarkKey) {
            replyText = "🤖 " + replyText
        }
        let audience = self.audience
        let _ = (account.postbox.transaction { transaction -> Bool in
            // Хозяин уже ответил сам: последнее сообщение чата исходящее и новее входящего.
            if let topIndex = transaction.getTopPeerMessageIndex(peerId: peerId), topIndex > incomingIndex, let top = transaction.getMessage(topIndex.id), !top.flags.contains(.Incoming) {
                return false
            }
            // Хозяин открыл чат за время задержки.
            if checkRead, let readState = transaction.getCombinedPeerReadState(peerId), readState.isIncomingMessageIndexRead(incomingIndex) {
                return false
            }
            if audience != 0 {
                let isContact = transaction.isPeerContact(peerId: peerId)
                if (audience == 1 && !isContact) || (audience == 2 && isContact) {
                    return false
                }
            }
            let ids = enqueueMessages(transaction: transaction, account: account, peerId: peerId, messages: [(false, .message(text: replyText, attributes: [], inlineStickers: [:], mediaReference: nil, threadId: nil, replyToMessageId: EngineMessageReplySubject(messageId: message.id, quote: nil, innerSubject: nil), replyToStoryId: nil, localGroupingKey: nil, correlationId: nil, bubbleUpEmojiOrStickersets: []))])
            return ids.contains(where: { $0 != nil })
        }
        |> deliverOn(queue)).start(next: { sent in
            if sent {
                addLog(name: name, text: replyText)
                ayGrammAfterSend(account: account)
            }
        })
    }
}
