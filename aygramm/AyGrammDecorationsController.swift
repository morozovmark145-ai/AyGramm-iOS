import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import AccountContext
import PresentationDataUtils

// Меню «Украшения профиля»: подарки и рейтинг, которые видны только на этом телефоне.
// Подарки появляются во вкладке «Подарки» своего профиля с лентой «украшение».

private final class AyGrammDecorationsArguments {
    let openItem: (Int) -> Void
    let add: () -> Void
    let changeRating: (Int) -> Void

    init(openItem: @escaping (Int) -> Void, add: @escaping () -> Void, changeRating: @escaping (Int) -> Void) {
        self.openItem = openItem
        self.add = add
        self.changeRating = changeRating
    }
}

private enum AyGrammDecorationsEntry: ItemListNodeEntry {
    case giftsHeader
    case gift(Int32, String, Bool)
    case add
    case giftsFooter
    case ratingHeader
    case rating(Int)
    case ratingUp
    case ratingDown
    case ratingFooter

    var section: ItemListSectionId {
        switch self {
        case .giftsHeader, .gift, .add, .giftsFooter:
            return 0
        case .ratingHeader, .rating, .ratingUp, .ratingDown, .ratingFooter:
            return 1
        }
    }

    var stableId: Int32 {
        switch self {
        case .giftsHeader:
            return 0
        case let .gift(index, _, _):
            return 10 + index
        case .add:
            return 9000
        case .giftsFooter:
            return 9001
        case .ratingHeader:
            return 9100
        case .rating:
            return 9101
        case .ratingUp:
            return 9102
        case .ratingDown:
            return 9103
        case .ratingFooter:
            return 9104
        }
    }

    static func <(lhs: AyGrammDecorationsEntry, rhs: AyGrammDecorationsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! AyGrammDecorationsArguments
        switch self {
        case .giftsHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ПОДАРКИ-УКРАШЕНИЯ", sectionId: self.section)
        case let .gift(index, title, isUpgraded):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: isUpgraded ? ayGrammIcon("sparkles", AyGrammColor.purple) : ayGrammIcon("gift.fill", AyGrammColor.pink), title: title, label: isUpgraded ? "улучшен ✨" : "обычный", sectionId: self.section, style: .blocks, action: {
                arguments.openItem(Int(index))
            })
        case .add:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: ayGrammIcon("plus", AyGrammColor.green), title: "Добавить подарок", label: "", sectionId: self.section, style: .blocks, action: {
                arguments.add()
            })
        case .giftsFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Украшения видны только на этом телефоне во вкладке «Подарки» профиля, с лентой «украшение». Продать или передать их нельзя. «Улучшить» даёт подарку случайную модель, узор и фон из вариантов Telegram."), sectionId: self.section)
        case .ratingHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "РЕЙТИНГ-УКРАШЕНИЕ", sectionId: self.section)
        case let .rating(level):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: ayGrammIcon("star.fill", AyGrammColor.yellow), title: "Уровень", label: "\(level) из 90", sectionId: self.section, style: .blocks, disclosureStyle: .none, action: nil)
        case .ratingUp:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: ayGrammIcon("arrow.up", AyGrammColor.green), title: "Повысить на 1", label: "", sectionId: self.section, style: .blocks, action: {
                arguments.changeRating(1)
            })
        case .ratingDown:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: ayGrammIcon("arrow.down", AyGrammColor.red), title: "Понизить на 1", label: "", sectionId: self.section, style: .blocks, action: {
                arguments.changeRating(-1)
            })
        case .ratingFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Рейтинг-украшение виден только в этом меню. Настоящий рейтинг Telegram в профиле не меняется."), sectionId: self.section)
        }
    }
}

func ayGrammDecorationsController(context: AccountContext) -> ViewController {
    let itemsPromise = ValuePromise<[AyGrammDecorationItem]>(AyGrammDecorations.items(), ignoreRepeated: true)
    let ratingPromise = ValuePromise<Int>(AyGrammDecorations.ratingLevel, ignoreRepeated: true)
    let actionsDisposable = DisposableSet()

    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController) -> Void)?

    let showMessage: (String) -> Void = { text in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        presentControllerImpl?(textAlertController(context: context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]))
    }

    let upgrade: (Int) -> Void = { index in
        guard let giftId = AyGrammDecorations.giftId(index: index) else {
            return
        }
        actionsDisposable.add((context.engine.payments.starGiftUpgradePreview(giftId: giftId)
        |> take(1)
        |> deliverOnMainQueue).start(next: { preview in
            if let preview = preview, AyGrammDecorations.upgrade(index: index, attributes: preview.attributes) {
                itemsPromise.set(AyGrammDecorations.items())
                showMessage("Украшение улучшено. Откройте свой профиль → «Подарки».")
            } else {
                showMessage("У этого подарка нет вариантов улучшения в Telegram.")
            }
        }))
    }

    let arguments = AyGrammDecorationsArguments(openItem: { index in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let items = AyGrammDecorations.items()
        guard index >= 0 && index < items.count else {
            return
        }
        var actions: [TextAlertAction] = []
        if !items[index].isUpgraded {
            actions.append(TextAlertAction(type: .defaultAction, title: "Улучшить", action: {
                upgrade(index)
            }))
        }
        actions.append(TextAlertAction(type: .destructiveAction, title: "Удалить", action: {
            AyGrammDecorations.remove(index: index)
            itemsPromise.set(AyGrammDecorations.items())
        }))
        actions.append(TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}))
        presentControllerImpl?(textAlertController(context: context, title: items[index].title, text: "Украшение видно только на этом телефоне.", actions: actions, actionLayout: .vertical))
    }, add: {
        pushControllerImpl?(ayGrammDecorationsCatalogController(context: context, added: {
            itemsPromise.set(AyGrammDecorations.items())
        }))
    }, changeRating: { delta in
        AyGrammDecorations.ratingLevel = AyGrammDecorations.ratingLevel + delta
        ratingPromise.set(AyGrammDecorations.ratingLevel)
    })

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        itemsPromise.get(),
        ratingPromise.get()
    )
    |> map { presentationData, items, rating -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var entries: [AyGrammDecorationsEntry] = [.giftsHeader]
        for item in items {
            entries.append(.gift(Int32(item.index), item.title, item.isUpgraded))
        }
        entries.append(.add)
        entries.append(.giftsFooter)
        entries.append(.ratingHeader)
        entries.append(.rating(rating))
        entries.append(.ratingUp)
        entries.append(.ratingDown)
        entries.append(.ratingFooter)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Украшения"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: true)
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }

    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    return controller
}

// MARK: - Каталог подарков Telegram

private enum AyGrammDecorationsCatalogEntry: ItemListNodeEntry {
    case header
    case status(String)
    case gift(Int32, String, String)

    var section: ItemListSectionId {
        return 0
    }

    var stableId: Int32 {
        switch self {
        case .header:
            return 0
        case .status:
            return 1
        case let .gift(index, _, _):
            return 10 + index
        }
    }

    static func <(lhs: AyGrammDecorationsCatalogEntry, rhs: AyGrammDecorationsCatalogEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let add = arguments as! (Int) -> Void
        switch self {
        case .header:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ПОДАРКИ TELEGRAM", sectionId: self.section)
        case let .status(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .gift(index, title, label):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: ayGrammIcon("gift.fill", AyGrammColor.pink), title: title, label: label, sectionId: self.section, style: .blocks, action: {
                add(Int(index))
            })
        }
    }
}

private func ayGrammDecorationsCatalogController(context: AccountContext, added: @escaping () -> Void) -> ViewController {
    var presentControllerImpl: ((ViewController) -> Void)?
    var catalog: [StarGift.Gift] = []

    let add: (Int) -> Void = { index in
        guard index >= 0 && index < catalog.count else {
            return
        }
        AyGrammDecorations.add(catalog[index])
        added()
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        presentControllerImpl?(textAlertController(context: context, title: nil, text: "Украшение добавлено. Оно появится в профиле во вкладке «Подарки».", actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]))
    }

    let _ = context.engine.payments.keepStarGiftsUpdated().start()

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        context.engine.payments.cachedStarGifts()
    )
    |> map { presentationData, gifts -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var entries: [AyGrammDecorationsCatalogEntry] = [.header]
        if let gifts = gifts {
            catalog = gifts.compactMap { gift -> StarGift.Gift? in
                if case let .generic(value) = gift {
                    return value
                }
                return nil
            }
            if catalog.isEmpty {
                entries.append(.status("Каталог подарков пуст."))
            }
            for (index, gift) in catalog.enumerated() {
                let title = gift.title ?? "Подарок за \(gift.price) ⭐"
                entries.append(.gift(Int32(index), title, "⭐ \(gift.price)"))
            }
        } else {
            entries.append(.status("Загрузка подарков…"))
        }
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Добавить"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: false)
        return (controllerState, (listState, add))
    }

    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    return controller
}
