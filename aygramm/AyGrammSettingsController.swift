import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import AccountContext

// Отдельное меню AyGramm в настройках: режим призрака, удалённые сообщения, канал создателя.

private final class AyGrammSettingsControllerArguments {
    let toggle: (String, Bool) -> Void
    let openChannel: () -> Void

    init(toggle: @escaping (String, Bool) -> Void, openChannel: @escaping () -> Void) {
        self.toggle = toggle
        self.openChannel = openChannel
    }
}

private enum AyGrammSettingsSection: Int32 {
    case ghost
    case messages
    case channel
}

private struct AyGrammSettingsState: Equatable {
    var hideOnline: Bool
    var hideRead: Bool
    var hideTyping: Bool
    var hideStoryViews: Bool
    var saveDeleted: Bool

    static func current() -> AyGrammSettingsState {
        return AyGrammSettingsState(
            hideOnline: AyGrammSettings.hideOnline,
            hideRead: AyGrammSettings.hideRead,
            hideTyping: AyGrammSettings.hideTyping,
            hideStoryViews: AyGrammSettings.hideStoryViews,
            saveDeleted: AyGrammSettings.saveDeleted
        )
    }
}

private enum AyGrammSettingsEntry: ItemListNodeEntry {
    case ghostHeader
    case ghostToggle(Int32, String, String, Bool)
    case ghostFooter
    case messagesHeader
    case saveDeleted(Bool)
    case messagesFooter
    case channelHeader
    case channel

    var section: ItemListSectionId {
        switch self {
        case .ghostHeader, .ghostToggle, .ghostFooter:
            return AyGrammSettingsSection.ghost.rawValue
        case .messagesHeader, .saveDeleted, .messagesFooter:
            return AyGrammSettingsSection.messages.rawValue
        case .channelHeader, .channel:
            return AyGrammSettingsSection.channel.rawValue
        }
    }

    var stableId: Int32 {
        switch self {
        case .ghostHeader:
            return 0
        case let .ghostToggle(index, _, _, _):
            return 1 + index
        case .ghostFooter:
            return 10
        case .messagesHeader:
            return 11
        case .saveDeleted:
            return 12
        case .messagesFooter:
            return 13
        case .channelHeader:
            return 14
        case .channel:
            return 15
        }
    }

    static func <(lhs: AyGrammSettingsEntry, rhs: AyGrammSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! AyGrammSettingsControllerArguments
        switch self {
        case .ghostHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "РЕЖИМ ПРИЗРАКА", sectionId: self.section)
        case let .ghostToggle(_, key, title, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(key, value)
            })
        case .ghostFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Включённые пункты не отправляются на сервер Telegram, поэтому собеседники их не видят."), sectionId: self.section)
        case .messagesHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "СООБЩЕНИЯ", sectionId: self.section)
        case let .saveDeleted(value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: "Сохранять удалённые", value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(AyGrammSettings.saveDeletedKey, value)
            })
        case .messagesFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Сообщение, которое собеседник удалил, остаётся в чате с пометкой «🗑 Удалено». Работает для сообщений, полученных, пока AyGramm установлен."), sectionId: self.section)
        case .channelHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "AYGRAMM", sectionId: self.section)
        case .channel:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: "Канал AyGramm", label: "@augrammipa", sectionId: self.section, style: .blocks, action: {
                arguments.openChannel()
            })
        }
    }
}

private func ayGrammSettingsEntries(state: AyGrammSettingsState) -> [AyGrammSettingsEntry] {
    var entries: [AyGrammSettingsEntry] = []
    entries.append(.ghostHeader)
    entries.append(.ghostToggle(0, AyGrammSettings.hideOnlineKey, "Не отправлять «в сети»", state.hideOnline))
    entries.append(.ghostToggle(1, AyGrammSettings.hideReadKey, "Не отправлять прочтение", state.hideRead))
    entries.append(.ghostToggle(2, AyGrammSettings.hideTypingKey, "Не отправлять «печатает…»", state.hideTyping))
    entries.append(.ghostToggle(3, AyGrammSettings.hideStoryViewsKey, "Не отправлять просмотр историй", state.hideStoryViews))
    entries.append(.ghostFooter)
    entries.append(.messagesHeader)
    entries.append(.saveDeleted(state.saveDeleted))
    entries.append(.messagesFooter)
    entries.append(.channelHeader)
    entries.append(.channel)
    return entries
}

func ayGrammSettingsController(context: AccountContext, openChannel: @escaping () -> Void) -> ViewController {
    let statePromise = ValuePromise(AyGrammSettingsState.current(), ignoreRepeated: true)

    let arguments = AyGrammSettingsControllerArguments(
        toggle: { key, value in
            AyGrammSettings.setValue(key, value)
            statePromise.set(AyGrammSettingsState.current())
        },
        openChannel: {
            openChannel()
        }
    )

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        statePromise.get()
    )
    |> deliverOnMainQueue
    |> map { presentationData, state -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("AyGramm"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: ayGrammSettingsEntries(state: state), style: .blocks, animateChanges: true)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    return controller
}
