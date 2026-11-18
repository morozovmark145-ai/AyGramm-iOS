import Foundation
import SwiftSignalKit

// Украшения AyGramm: подарки и NFT из каталога Telegram, которые AyGramm рисует в своём профиле.
// Telegram о них не знает, купить, продать или передать их нельзя.
// Профиль показывает их как обычные подарки: экран подарка, скрытие и анимация улучшения со слотами.
// На карточке стоит лента «AyGramm», а в описании подарка строка «Украшение AyGramm»:
// по снимку экрана видно, что это украшение, и его нельзя выдать за купленный NFT.
public struct AyGrammDecorationItem: Equatable {
    public let index: Int
    public let title: String
    public let isUpgraded: Bool
    public let isHidden: Bool
}

public enum AyGrammDecorations {
    public static let marker = "Украшение AyGramm"
    public static let ribbonText = "AyGramm"
    static let ratingKey = "AyGrammDecorationRating"
    static let hiddenKey = "AyGrammDecorationHidden"
    static let slugPrefix = "aygramm-"
    static let updatesPromise = ValuePromise<Int>(0, ignoreRepeated: false)
    static var updateCounter = 0

    static var fileUrl: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("aygramm-decorations.json")
    }

    // Меняется при каждом добавлении, улучшении, скрытии и удалении: профиль сразу перерисовывает подарки.
    public static var updates: Signal<Int, NoError> {
        return updatesPromise.get()
    }

    static func notifyUpdated() {
        updateCounter += 1
        updatesPromise.set(updateCounter)
    }

    // Подарки в том виде, в котором они лежат в файле.
    public static func gifts() -> [ProfileGiftsContext.State.StarGift] {
        guard let data = try? Data(contentsOf: fileUrl), let gifts = try? JSONDecoder().decode([ProfileGiftsContext.State.StarGift].self, from: data) else {
            return []
        }
        return gifts
    }

    static func save(_ gifts: [ProfileGiftsContext.State.StarGift]) {
        if let data = try? JSONEncoder().encode(gifts) {
            try? data.write(to: fileUrl, options: .atomic)
        }
        notifyUpdated()
    }

    // Встроенный плагин «Украшения профиля» включён.
    public static var enabled: Bool {
        return AyGrammSettings.value(AyGrammSettings.decorationsKey)
    }

    public static var hasGifts: Bool {
        return enabled && !gifts().isEmpty
    }

    // Ключ украшения: дата добавления и номер подарка в каталоге. Улучшение дату не меняет.
    static func key(_ gift: ProfileGiftsContext.State.StarGift) -> String {
        switch gift.gift {
        case let .generic(value):
            return "\(gift.date)-\(value.id)"
        case let .unique(value):
            return "\(gift.date)-\(value.giftId)"
        }
    }

    static var hiddenKeys: Set<String> {
        get {
            return Set(UserDefaults.standard.stringArray(forKey: hiddenKey) ?? [])
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: hiddenKey)
        }
    }

    public static func items() -> [AyGrammDecorationItem] {
        let hidden = hiddenKeys
        return gifts().enumerated().map { index, gift in
            let isHidden = hidden.contains(key(gift))
            switch gift.gift {
            case let .generic(value):
                return AyGrammDecorationItem(index: index, title: value.title ?? "Подарок", isUpgraded: false, isHidden: isHidden)
            case let .unique(value):
                return AyGrammDecorationItem(index: index, title: value.title, isUpgraded: true, isHidden: isHidden)
            }
        }
    }

    // Украшение узнаётся по строке в описании. Старые украшения хранят длинный текст, он начинается так же.
    public static func isDecoration(_ gift: ProfileGiftsContext.State.StarGift) -> Bool {
        guard let text = gift.text, text.hasPrefix(marker) else {
            return false
        }
        guard let reference = gift.reference else {
            return true
        }
        if case let .slug(slug) = reference {
            return slug.hasPrefix(slugPrefix)
        }
        return false
    }

    // Ссылка AyGramm нужна экрану подарка Telegram: без неё он не даёт скрыть и улучшить подарок.
    // Обычный улучшаемый подарок получает предоплаченное улучшение, поэтому звёзды не списываются.
    static func wrap(_ gift: StarGift, number: Int32?, date: Int32, reference: StarGiftReference? = nil, savedToProfile: Bool = true) -> ProfileGiftsContext.State.StarGift {
        var canUpgrade = false
        var upgradeStars: Int64?
        if reference != nil, case .generic = gift {
            canUpgrade = true
            upgradeStars = 1
        }
        return ProfileGiftsContext.State.StarGift(
            gift: gift,
            reference: reference,
            fromPeer: nil,
            date: date,
            text: marker,
            entities: nil,
            nameHidden: false,
            savedToProfile: savedToProfile,
            pinnedToTop: false,
            convertStars: nil,
            canUpgrade: canUpgrade,
            canExportDate: nil,
            upgradeStars: upgradeStars,
            transferStars: nil,
            canTransferDate: nil,
            canResaleDate: nil,
            collectionIds: nil,
            prepaidUpgradeHash: nil,
            upgradeSeparate: false,
            dropOriginalDetailsStars: nil,
            number: number,
            isRefunded: false,
            canCraftAt: nil
        )
    }

    // Подарки для профиля: со ссылкой AyGramm и отметкой «скрыт», как у настоящих подарков.
    public static func displayGifts() -> [ProfileGiftsContext.State.StarGift] {
        let hidden = hiddenKeys
        return gifts().map { gift in
            let giftKey = key(gift)
            return wrap(gift.gift, number: gift.number, date: gift.date, reference: .slug(slug: slugPrefix + giftKey), savedToProfile: !hidden.contains(giftKey))
        }
    }

    static func index(of reference: StarGiftReference) -> Int? {
        guard case let .slug(slug) = reference, slug.hasPrefix(slugPrefix) else {
            return nil
        }
        let giftKey = String(slug.dropFirst(slugPrefix.count))
        return gifts().firstIndex(where: { key($0) == giftKey })
    }

    // Подарок из каталога Telegram добавляется в начало списка.
    public static func add(_ gift: StarGift.Gift) {
        var list = gifts()
        var date = Int32(Date().timeIntervalSince1970)
        // Два подарка, добавленные за одну секунду, получают разные ключи.
        while list.contains(where: { $0.date == date }) {
            date += 1
        }
        list.insert(wrap(.generic(gift), number: nil, date: date), at: 0)
        save(list)
    }

    public static func remove(index: Int) {
        var list = gifts()
        if index >= 0 && index < list.count {
            var hidden = hiddenKeys
            hidden.remove(key(list[index]))
            hiddenKeys = hidden
            list.remove(at: index)
            save(list)
        }
    }

    public static func remove(reference: StarGiftReference) {
        if let index = index(of: reference) {
            remove(index: index)
        }
    }

    // Скрыть или показать украшение в профиле. Скрытое видно только владельцу, с отметкой «скрыт».
    public static func setHidden(index: Int, hidden: Bool) {
        let list = gifts()
        guard index >= 0 && index < list.count else {
            return
        }
        var keys = hiddenKeys
        if hidden {
            keys.insert(key(list[index]))
        } else {
            keys.remove(key(list[index]))
        }
        hiddenKeys = keys
        notifyUpdated()
    }

    public static func setHidden(reference: StarGiftReference, hidden: Bool) {
        if let index = index(of: reference) {
            setHidden(index: index, hidden: hidden)
        }
    }

    // Улучшение: случайная модель, узор и фон из вариантов, которые Telegram показывает для этого подарка.
    public static func upgrade(index: Int, attributes: [StarGift.UniqueGift.Attribute]) -> Bool {
        var list = gifts()
        guard index >= 0 && index < list.count, case let .generic(gift) = list[index].gift else {
            return false
        }
        let models = attributes.filter { if case .model = $0 { return true } else { return false } }
        let patterns = attributes.filter { if case .pattern = $0 { return true } else { return false } }
        let backdrops = attributes.filter { if case .backdrop = $0 { return true } else { return false } }
        guard let model = models.randomElement(), let pattern = patterns.randomElement(), let backdrop = backdrops.randomElement() else {
            return false
        }
        let number = Int32(index + 1)
        let unique = StarGift.UniqueGift(
            id: Int64.random(in: 1 ... Int64.max),
            giftId: gift.id,
            title: gift.title ?? "Подарок",
            number: number,
            slug: "",
            owner: nil,
            attributes: [model, pattern, backdrop],
            availability: StarGift.UniqueGift.Availability(issued: 1, total: 1),
            giftAddress: nil,
            resellAmounts: nil,
            resellForTonOnly: false,
            releasedBy: nil,
            valueAmount: nil,
            valueCurrency: nil,
            valueUsdAmount: nil,
            flags: [],
            themePeerId: nil,
            peerColor: nil,
            hostPeerId: nil,
            minOfferStars: nil,
            craftChancePermille: nil
        )
        list[index] = wrap(.unique(unique), number: number, date: list[index].date)
        save(list)
        return true
    }

    // Улучшение из экрана подарка Telegram. Экран сам крутит слоты фона, узора и модели,
    // пока ждёт ответ, а потом останавливает их на выпавшем варианте.
    public static func upgradeSignal(engine: TelegramEngine, reference: StarGiftReference) -> Signal<ProfileGiftsContext.State.StarGift, UpgradeStarGiftError> {
        guard let index = index(of: reference), let giftId = giftId(index: index) else {
            return .fail(.alreadyUpgraded)
        }
        return engine.payments.starGiftUpgradePreview(giftId: giftId)
        |> castError(UpgradeStarGiftError.self)
        |> mapToSignal { preview -> Signal<ProfileGiftsContext.State.StarGift, UpgradeStarGiftError> in
            guard let preview = preview, upgrade(index: index, attributes: preview.attributes) else {
                return .fail(.generic)
            }
            let list = displayGifts()
            guard index < list.count else {
                return .fail(.generic)
            }
            return .single(list[index])
        }
    }

    public static func giftId(index: Int) -> Int64? {
        let list = gifts()
        guard index >= 0 && index < list.count, case let .generic(gift) = list[index].gift else {
            return nil
        }
        return gift.id
    }

    // Уровень рейтинга украшения: от 0 до 90. Виден только в меню «Украшения».
    public static var ratingLevel: Int {
        get {
            return UserDefaults.standard.integer(forKey: ratingKey)
        }
        set {
            UserDefaults.standard.set(max(0, min(90, newValue)), forKey: ratingKey)
        }
    }
}

// Профиль своего аккаунта: украшения стоят перед настоящими подарками.
func ayGrammWithDecorations(_ state: ProfileGiftsContext.State) -> ProfileGiftsContext.State {
    if !AyGrammDecorations.enabled {
        return state
    }
    let local = AyGrammDecorations.displayGifts()
    if local.isEmpty {
        return state
    }
    var state = state
    state.gifts = local + state.gifts
    state.filteredGifts = local + state.filteredGifts
    state.count = (state.count ?? 0) + Int32(local.count)
    return state
}
