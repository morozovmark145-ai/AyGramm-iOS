import Foundation
import SwiftSignalKit

// Украшения AyGramm: подарки и рейтинг, которые видны только на этом телефоне.
// Telegram о них не знает, другие люди их не видят, купить или продать их нельзя.
// В профиле у каждого украшения вместо номера стоит лента «украшение», чтобы снимок экрана
// нельзя было выдать за настоящие подарки.
public struct AyGrammDecorationItem: Equatable {
    public let index: Int
    public let title: String
    public let isUpgraded: Bool
}

public enum AyGrammDecorations {
    public static let marker = "Украшение AyGramm. Видно только на этом телефоне, в Telegram его нет."
    public static let ribbonText = "украшение"
    static let ratingKey = "AyGrammDecorationRating"
    static let updatesPromise = ValuePromise<Int>(0, ignoreRepeated: false)
    static var updateCounter = 0

    static var fileUrl: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("aygramm-decorations.json")
    }

    // Меняется при каждом добавлении, улучшении и удалении: профиль сразу перерисовывает подарки.
    public static var updates: Signal<Int, NoError> {
        return updatesPromise.get()
    }

    static func notifyUpdated() {
        updateCounter += 1
        updatesPromise.set(updateCounter)
    }

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

    public static var hasGifts: Bool {
        return !gifts().isEmpty
    }

    public static func items() -> [AyGrammDecorationItem] {
        return gifts().enumerated().map { index, gift in
            switch gift.gift {
            case let .generic(value):
                return AyGrammDecorationItem(index: index, title: value.title ?? "Подарок", isUpgraded: false)
            case let .unique(value):
                return AyGrammDecorationItem(index: index, title: value.title, isUpgraded: true)
            }
        }
    }

    public static func isDecoration(_ gift: ProfileGiftsContext.State.StarGift) -> Bool {
        return gift.reference == nil && gift.text == marker
    }

    static func wrap(_ gift: StarGift, number: Int32?) -> ProfileGiftsContext.State.StarGift {
        return ProfileGiftsContext.State.StarGift(
            gift: gift,
            reference: nil,
            fromPeer: nil,
            date: Int32(Date().timeIntervalSince1970),
            text: marker,
            entities: nil,
            nameHidden: false,
            savedToProfile: true,
            pinnedToTop: false,
            convertStars: nil,
            canUpgrade: false,
            canExportDate: nil,
            upgradeStars: nil,
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

    // Подарок из каталога Telegram добавляется в начало списка.
    public static func add(_ gift: StarGift.Gift) {
        var list = gifts()
        list.insert(wrap(.generic(gift), number: nil), at: 0)
        save(list)
    }

    public static func remove(index: Int) {
        var list = gifts()
        if index >= 0 && index < list.count {
            list.remove(at: index)
            save(list)
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
        list[index] = wrap(.unique(unique), number: number)
        save(list)
        return true
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
    let local = AyGrammDecorations.gifts()
    if local.isEmpty {
        return state
    }
    var state = state
    state.gifts = local + state.gifts
    state.filteredGifts = local + state.filteredGifts
    state.count = (state.count ?? 0) + Int32(local.count)
    return state
}
