import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import AccountContext
import PresentationDataUtils
import LegacyMediaPickerUI

// Меню AyGramm в настройках: режим призрака, удалённые и изменённые сообщения, плагины,
// сообщество (канал, подписка, счётчик скачиваний, версия) и админ-панель для владельца канала.

private final class AyGrammSettingsControllerArguments {
    let toggle: (String, Bool) -> Void
    let openDeleted: () -> Void
    let openPlugins: () -> Void
    let openDecorations: () -> Void
    let openChannel: () -> Void
    let joinChannel: () -> Void
    let openUpdate: () -> Void
    let openAdmin: () -> Void

    init(toggle: @escaping (String, Bool) -> Void, openDeleted: @escaping () -> Void, openPlugins: @escaping () -> Void, openDecorations: @escaping () -> Void, openChannel: @escaping () -> Void, joinChannel: @escaping () -> Void, openUpdate: @escaping () -> Void, openAdmin: @escaping () -> Void) {
        self.toggle = toggle
        self.openDeleted = openDeleted
        self.openPlugins = openPlugins
        self.openDecorations = openDecorations
        self.openChannel = openChannel
        self.joinChannel = joinChannel
        self.openUpdate = openUpdate
        self.openAdmin = openAdmin
    }
}

private enum AyGrammSettingsSection: Int32 {
    case banned
    case ghost
    case messages
    case plugins
    case community
    case admin
    case background
}

private struct AyGrammSettingsState: Equatable {
    var values: [String: Bool]

    static func current() -> AyGrammSettingsState {
        var values: [String: Bool] = [:]
        for key in [AyGrammSettings.hideOnlineKey, AyGrammSettings.hideReadKey, AyGrammSettings.hideTypingKey, AyGrammSettings.hideStoryViewsKey, AyGrammSettings.saveDeletedKey, AyGrammSettings.saveEditsKey, AyGrammSettings.silentSendKey, AyGrammSettings.pluginsEnabledKey, AyGrammSettings.keepAliveKey] {
            values[key] = AyGrammSettings.storedValue(key)
        }
        return AyGrammSettingsState(values: values)
    }

    func value(_ key: String) -> Bool {
        return self.values[key] ?? AyGrammSettings.storedValue(key)
    }
}

private enum AyGrammSettingsEntry: ItemListNodeEntry {
    case bannedInfo
    case ghostHeader
    case toggle(Int32, AyGrammSettingsSection, String, String, Bool)
    case ghostFooter
    case messagesHeader
    case deleted(String)
    case messagesFooter
    case pluginsHeader
    case plugins
    case decorations
    case pluginsFooter
    case communityHeader
    case channel
    case join
    case downloads(String)
    case version(String)
    case communityFooter
    case adminHeader
    case admin
    case backgroundHeader
    case backgroundFooter

    var section: ItemListSectionId {
        switch self {
        case .bannedInfo:
            return AyGrammSettingsSection.banned.rawValue
        case .ghostHeader, .ghostFooter:
            return AyGrammSettingsSection.ghost.rawValue
        case let .toggle(_, section, _, _, _):
            return section.rawValue
        case .messagesHeader, .deleted, .messagesFooter:
            return AyGrammSettingsSection.messages.rawValue
        case .pluginsHeader, .plugins, .decorations, .pluginsFooter:
            return AyGrammSettingsSection.plugins.rawValue
        case .communityHeader, .channel, .join, .downloads, .version, .communityFooter:
            return AyGrammSettingsSection.community.rawValue
        case .adminHeader, .admin:
            return AyGrammSettingsSection.admin.rawValue
        case .backgroundHeader, .backgroundFooter:
            return AyGrammSettingsSection.background.rawValue
        }
    }

    // Порядок: бан 0, звонки в фоне 1–9, призрак 10–19, сообщения 20–29, плагины 30–39, сообщество 40–49, автор 50–59.
    var stableId: Int32 {
        switch self {
        case .bannedInfo:
            return 0
        case .ghostHeader:
            return 10
        case let .toggle(id, _, _, _, _):
            return id
        case .ghostFooter:
            return 19
        case .messagesHeader:
            return 20
        case .deleted:
            return 27
        case .messagesFooter:
            return 29
        case .pluginsHeader:
            return 30
        case .plugins:
            return 32
        case .decorations:
            return 33
        case .pluginsFooter:
            return 39
        case .communityHeader:
            return 40
        case .channel:
            return 41
        case .join:
            return 42
        case .downloads:
            return 43
        case .version:
            return 44
        case .communityFooter:
            return 49
        case .adminHeader:
            return 50
        case .admin:
            return 51
        case .backgroundHeader:
            return 1
        case .backgroundFooter:
            return 9
        }
    }

    static func <(lhs: AyGrammSettingsEntry, rhs: AyGrammSettingsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! AyGrammSettingsControllerArguments
        switch self {
        case .bannedInfo:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Автор AyGramm заблокировал этот аккаунт в канале @augrammipa. Режим призрака, удалённые сообщения и плагины выключены."), sectionId: self.section)
        case .ghostHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "РЕЖИМ ПРИЗРАКА", sectionId: self.section)
        case let .toggle(_, _, key, title, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, icon: ayGrammKeyIcon(key), title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(key, value)
            })
        case .ghostFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Собеседники не видят включённые пункты. Отметить чат прочитанным: зажмите сообщение → «Отправить прочтение». Ответ в чате Telegram сам отмечает прочитанным."), sectionId: self.section)
        case .messagesHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "СООБЩЕНИЯ", sectionId: self.section)
        case let .deleted(count):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: ayGrammIcon("tray.full.fill", AyGrammColor.gray), title: "Удалённые сообщения", label: count, sectionId: self.section, style: .blocks, action: {
                arguments.openDeleted()
            })
        case .messagesFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Удалённое сообщение остаётся полупрозрачным и получает 🗑. Прежние версии: зажмите сообщение → «История изменений». «Тихая отправка» приходит получателю без звука."), sectionId: self.section)
        case .pluginsHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ПЛАГИНЫ", sectionId: self.section)
        case .plugins:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: ayGrammIcon("puzzlepiece.fill", AyGrammColor.green), title: "Плагины", label: "", sectionId: self.section, style: .blocks, action: {
                arguments.openPlugins()
            })
        case .decorations:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: ayGrammIcon("square.grid.2x2.fill", AyGrammColor.indigo), title: "Встроенные плагины", label: "", sectionId: self.section, style: .blocks, action: {
                arguments.openDecorations()
            })
        case .pluginsFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Плагины меняют только текст ваших исходящих сообщений и не видят переписку. Встроенные: звонки в фоне, 213 шрифтов, украшения, аккаунты без лимита."), sectionId: self.section)
        case .communityHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "СООБЩЕСТВО", sectionId: self.section)
        case .channel:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: ayGrammIcon("paperplane.fill", AyGrammColor.blue), title: "Канал AyGramm", label: "@" + AyGrammCommunity.channelUsername, sectionId: self.section, style: .blocks, action: {
                arguments.openChannel()
            })
        case .join:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: ayGrammIcon("person.badge.plus", AyGrammColor.green), title: "Подписаться на канал", label: "", sectionId: self.section, style: .blocks, action: {
                arguments.joinChannel()
            })
        case let .downloads(value):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: ayGrammIcon("arrow.down.circle.fill", AyGrammColor.teal), title: "Скачиваний AyGramm", label: value, sectionId: self.section, style: .blocks, disclosureStyle: .none, action: nil)
        case let .version(value):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: ayGrammIcon("info.circle.fill", AyGrammColor.gray), title: "Версия", label: value, sectionId: self.section, style: .blocks, action: {
                arguments.openUpdate()
            })
        case .communityFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain(AyGrammCommunity.consentText + " Счётчик скачиваний открытый: это число скачиваний файла на GitHub."), sectionId: self.section)
        case .adminHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "АВТОР", sectionId: self.section)
        case .backgroundHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ЗВОНКИ И УВЕДОМЛЕНИЯ", sectionId: self.section)
        case .backgroundFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Push-уведомления Telegram не доходят до переподписанного AyGramm, поэтому свёрнутый AyGramm засыпает. С этим режимом он держит связь с Telegram в фоне: звонки приходят на экран вызова iOS, о сообщениях приходит уведомление. Батарея садится быстрее. Если смахнуть AyGramm из списка приложений, режим выключится до следующего запуска."), sectionId: self.section)
        case .admin:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: ayGrammIcon("lock.shield.fill", AyGrammColor.red), title: "Админ-панель", label: "", sectionId: self.section, style: .blocks, action: {
                arguments.openAdmin()
            })
        }
    }
}

private func ayGrammSettingsEntries(state: AyGrammSettingsState, downloads: String, version: String, deletedCount: Int, isAdmin: Bool, isBanned: Bool) -> [AyGrammSettingsEntry] {
    var entries: [AyGrammSettingsEntry] = []
    if isBanned {
        entries.append(.bannedInfo)
    }
    entries.append(.ghostHeader)
    entries.append(.toggle(11, .ghost, AyGrammSettings.hideOnlineKey, "Не отправлять «в сети»", state.value(AyGrammSettings.hideOnlineKey)))
    entries.append(.toggle(12, .ghost, AyGrammSettings.hideReadKey, "Не отправлять прочтение", state.value(AyGrammSettings.hideReadKey)))
    entries.append(.toggle(13, .ghost, AyGrammSettings.hideTypingKey, "Не отправлять «печатает…»", state.value(AyGrammSettings.hideTypingKey)))
    entries.append(.toggle(14, .ghost, AyGrammSettings.hideStoryViewsKey, "Не отправлять просмотр историй", state.value(AyGrammSettings.hideStoryViewsKey)))
    entries.append(.ghostFooter)
    entries.append(.messagesHeader)
    entries.append(.toggle(21, .messages, AyGrammSettings.saveDeletedKey, "Сохранять удалённые", state.value(AyGrammSettings.saveDeletedKey)))
    entries.append(.toggle(22, .messages, AyGrammSettings.saveEditsKey, "Сохранять историю правок", state.value(AyGrammSettings.saveEditsKey)))
    entries.append(.toggle(23, .messages, AyGrammSettings.silentSendKey, "Тихая отправка", state.value(AyGrammSettings.silentSendKey)))
    entries.append(.deleted("\(deletedCount)"))
    entries.append(.messagesFooter)
    entries.append(.pluginsHeader)
    entries.append(.toggle(31, .plugins, AyGrammSettings.pluginsEnabledKey, "Плагины включены", state.value(AyGrammSettings.pluginsEnabledKey)))
    entries.append(.plugins)
    entries.append(.decorations)
    entries.append(.pluginsFooter)
    entries.append(.communityHeader)
    entries.append(.channel)
    entries.append(.join)
    entries.append(.downloads(downloads))
    entries.append(.version(version))
    entries.append(.communityFooter)
    if isAdmin {
        entries.append(.adminHeader)
        entries.append(.admin)
    }
    return entries
}

func ayGrammSettingsController(context: AccountContext, openChannel: @escaping () -> Void) -> ViewController {
    let statePromise = ValuePromise(AyGrammSettingsState.current(), ignoreRepeated: true)
    let downloadsPromise = ValuePromise<String>("…", ignoreRepeated: true)
    let versionPromise = ValuePromise<String>("0.\(AyGrammSettings.currentVersion)", ignoreRepeated: true)
    let deletedCountPromise = ValuePromise<Int>(AyGrammDeletedLog.entries().count, ignoreRepeated: true)
    let isAdminPromise = ValuePromise<Bool>(false, ignoreRepeated: true)
    let isBannedPromise = ValuePromise<Bool>(AyGrammSettings.isBanned, ignoreRepeated: true)
    let actionsDisposable = DisposableSet()
    var latestRelease: AyGrammRelease?

    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController) -> Void)?

    let showMessage: (String) -> Void = { text in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        presentControllerImpl?(textAlertController(context: context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]))
    }

    let arguments = AyGrammSettingsControllerArguments(
        toggle: { key, value in
            AyGrammSettings.setValue(key, value)
            statePromise.set(AyGrammSettingsState.current())
        },
        openDeleted: {
            pushControllerImpl?(ayGrammDeletedController(context: context, updatedCount: { count in
                deletedCountPromise.set(count)
            }))
        },
        openPlugins: {
            pushControllerImpl?(ayGrammPluginsController(context: context))
        },
        openDecorations: {
            pushControllerImpl?(ayGrammBuiltinController(context: context))
        },
        openChannel: {
            openChannel()
        },
        joinChannel: {
            actionsDisposable.add((AyGrammCommunity.join(engine: context.engine)
            |> deliverOnMainQueue).start(completed: {
                showMessage("Готово: вы подписаны на канал AyGramm.")
            }))
        },
        openUpdate: {
            if let release = latestRelease, release.version > AyGrammSettings.currentVersion {
                context.sharedContext.applicationBindings.openUrl(release.url)
            } else {
                showMessage("У вас последняя версия AyGramm.")
            }
        },
        openAdmin: {
            pushControllerImpl?(ayGrammAdminController(context: context))
        }
    )

    actionsDisposable.add((AyGrammCommunity.downloadCount()
    |> deliverOnMainQueue).start(next: { count in
        if let count = count {
            downloadsPromise.set("\(count)")
        } else {
            downloadsPromise.set("нет данных")
        }
    }))
    actionsDisposable.add((AyGrammCommunity.latestRelease()
    |> deliverOnMainQueue).start(next: { release in
        latestRelease = release
        if let release = release, release.version > AyGrammSettings.currentVersion {
            versionPromise.set("0.\(AyGrammSettings.currentVersion) → есть 0.\(release.version)")
        }
    }))
    actionsDisposable.add((AyGrammCommunity.ownParticipant(engine: context.engine, accountPeerId: context.account.peerId)
    |> deliverOnMainQueue).start(next: { participant in
        isAdminPromise.set(AyGrammCommunity.isAdmin(participant))
        let banned = AyGrammCommunity.isBanned(participant)
        AyGrammSettings.isBanned = banned
        isBannedPromise.set(banned)
    }))

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        statePromise.get(),
        combineLatest(downloadsPromise.get(), versionPromise.get(), deletedCountPromise.get()),
        isAdminPromise.get(),
        isBannedPromise.get()
    )
    |> map { presentationData, state, info, isAdmin, isBanned -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let (downloads, version, deletedCount) = info
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("AyGramm"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: ayGrammSettingsEntries(state: state, downloads: downloads, version: version, deletedCount: deletedCount, isAdmin: isAdmin, isBanned: isBanned), style: .blocks, animateChanges: true)
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

// MARK: - Удалённые сообщения

private final class AyGrammDeletedControllerArguments {
    let copyAll: () -> Void
    let clear: () -> Void

    init(copyAll: @escaping () -> Void, clear: @escaping () -> Void) {
        self.copyAll = copyAll
        self.clear = clear
    }
}

private enum AyGrammDeletedEntry: ItemListNodeEntry {
    case actionsHeader(String)
    case copyAll
    case clear
    case listHeader
    case item(Int32, String)
    case empty

    var section: ItemListSectionId {
        switch self {
        case .actionsHeader, .copyAll, .clear:
            return 0
        case .listHeader, .item, .empty:
            return 1
        }
    }

    var stableId: Int32 {
        switch self {
        case .actionsHeader:
            return 0
        case .copyAll:
            return 1
        case .clear:
            return 2
        case .listHeader:
            return 10
        case .empty:
            return 11
        case let .item(index, _):
            return 100 + index
        }
    }

    static func <(lhs: AyGrammDeletedEntry, rhs: AyGrammDeletedEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! AyGrammDeletedControllerArguments
        switch self {
        case let .actionsHeader(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case .copyAll:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: ayGrammIcon("doc.on.doc.fill", AyGrammColor.blue), title: "Скопировать всё", label: "", sectionId: self.section, style: .blocks, action: {
                arguments.copyAll()
            })
        case .clear:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: ayGrammIcon("trash.fill", AyGrammColor.red), title: "Очистить список", label: "", sectionId: self.section, style: .blocks, action: {
                arguments.clear()
            })
        case .listHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ПОСЛЕДНИЕ 300, НОВЫЕ СВЕРХУ", sectionId: self.section)
        case let .item(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case .empty:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Пока ничего не удаляли."), sectionId: self.section)
        }
    }
}

private func ayGrammDeletedController(context: AccountContext, updatedCount: @escaping (Int) -> Void) -> ViewController {
    let entriesPromise = ValuePromise<[AyGrammDeletedLogEntry]>(AyGrammDeletedLog.entries(), ignoreRepeated: true)
    var presentControllerImpl: ((ViewController) -> Void)?

    let arguments = AyGrammDeletedControllerArguments(copyAll: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        UIPasteboard.general.string = AyGrammDeletedLog.exportText()
        presentControllerImpl?(textAlertController(context: context, title: nil, text: "Все удалённые сообщения скопированы. Их можно вставить в «Избранное» или в заметки.", actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]))
    }, clear: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        presentControllerImpl?(textAlertController(context: context, title: nil, text: "Очистить список удалённых сообщений? Сами сообщения в чатах останутся.", actions: [
            TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}),
            TextAlertAction(type: .destructiveAction, title: "Очистить", action: {
                AyGrammDeletedLog.clear()
                entriesPromise.set([])
                updatedCount(0)
            })
        ]))
    })

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        entriesPromise.get()
    )
    |> map { presentationData, logEntries -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var entries: [AyGrammDeletedEntry] = []
        entries.append(.actionsHeader("СОХРАНЕНО: \(logEntries.count)"))
        entries.append(.copyAll)
        entries.append(.clear)
        entries.append(.listHeader)
        if logEntries.isEmpty {
            entries.append(.empty)
        }
        for (index, entry) in logEntries.prefix(300).enumerated() {
            entries.append(.item(Int32(index), AyGrammDeletedLog.describe(entry)))
        }
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Удалённые"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: false)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    return controller
}

// MARK: - Каталог плагинов

private final class AyGrammPluginsControllerArguments {
    let toggle: (AyGrammPlugin, Bool) -> Void
    let toggleCustom: (AyGrammCustomPlugin, Bool) -> Void
    let addCustom: () -> Void
    let addFile: () -> Void
    let removeDisabledCustom: () -> Void

    init(toggle: @escaping (AyGrammPlugin, Bool) -> Void, toggleCustom: @escaping (AyGrammCustomPlugin, Bool) -> Void, addCustom: @escaping () -> Void, addFile: @escaping () -> Void, removeDisabledCustom: @escaping () -> Void) {
        self.toggle = toggle
        self.toggleCustom = toggleCustom
        self.addCustom = addCustom
        self.addFile = addFile
        self.removeDisabledCustom = removeDisabledCustom
    }
}

private enum AyGrammPluginsEntry: ItemListNodeEntry {
    case header
    case status(String)
    case plugin(Int32, AyGrammPlugin, Bool)
    case footer
    case customHeader
    case custom(Int32, AyGrammCustomPlugin, Bool)
    case addCustom
    case addFile
    case removeDisabled
    case customFooter

    var section: ItemListSectionId {
        switch self {
        case .header, .status, .plugin, .footer:
            return 0
        case .customHeader, .custom, .addCustom, .addFile, .removeDisabled, .customFooter:
            return 1
        }
    }

    var stableId: Int32 {
        switch self {
        case .header:
            return 0
        case .status:
            return 1
        case let .plugin(index, _, _):
            return 2 + index
        case .footer:
            return 999
        case .customHeader:
            return 5000
        case let .custom(index, _, _):
            return 5100 + index
        case .addCustom:
            return 5900
        case .addFile:
            return 5901
        case .removeDisabled:
            return 5902
        case .customFooter:
            return 6000
        }
    }

    static func <(lhs: AyGrammPluginsEntry, rhs: AyGrammPluginsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! AyGrammPluginsControllerArguments
        switch self {
        case .header:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "КАТАЛОГ", sectionId: self.section)
        case let .status(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case let .plugin(_, plugin, installed):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, icon: ayGrammIcon("puzzlepiece.fill", AyGrammColor.green), title: plugin.name, text: plugin.description, value: installed, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(plugin, value)
            })
        case .footer:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Исходный код каждого плагина открыт: " + AyGrammPlugins.catalogPageUrl + ". Плагин меняет только текст исходящего сообщения без форматирования и работает без доступа к сети."), sectionId: self.section)
        case .customHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "МОИ ПЛАГИНЫ", sectionId: self.section)
        case let .custom(_, plugin, enabled):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, icon: ayGrammIcon("chevron.left.forwardslash.chevron.right", AyGrammColor.orange), title: plugin.name, value: enabled, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleCustom(plugin, value)
            })
        case .addCustom:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: ayGrammIcon("doc.on.clipboard.fill", AyGrammColor.blue), title: "Добавить из буфера обмена", label: "", sectionId: self.section, style: .blocks, action: {
                arguments.addCustom()
            })
        case .addFile:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: ayGrammIcon("folder.fill", AyGrammColor.orange), title: "Добавить из файла", label: "", sectionId: self.section, style: .blocks, action: {
                arguments.addFile()
            })
        case .removeDisabled:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: ayGrammIcon("trash.fill", AyGrammColor.red), title: "Удалить выключенные", label: "", sectionId: self.section, style: .blocks, action: {
                arguments.removeDisabledCustom()
            })
        case .customFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Скопируйте код плагина или ссылку на файл .js и нажмите «Добавить из буфера обмена», или выберите файл .js в «Файлах». Плагин — это JavaScript с функцией onOutgoingText(text), она возвращает новый текст сообщения. Первая строка «// Название» станет названием плагина. Ставьте только плагины, которым доверяете: плагин может менять ваши исходящие сообщения."), sectionId: self.section)
        }
    }
}

private func ayGrammPluginsController(context: AccountContext) -> ViewController {
    let catalogPromise = ValuePromise<[AyGrammPlugin]?>(nil, ignoreRepeated: true)
    let installedPromise = ValuePromise<[String]>(AyGrammPlugins.installedIds, ignoreRepeated: true)
    let customPromise = ValuePromise<[AyGrammCustomPlugin]>(AyGrammPlugins.customPlugins, ignoreRepeated: true)
    let actionsDisposable = DisposableSet()

    var presentControllerImpl: ((ViewController) -> Void)?

    let showMessage: (String) -> Void = { text in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        presentControllerImpl?(textAlertController(context: context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]))
    }

    let addCode: (String) -> Void = { code in
        actionsDisposable.add((AyGrammPlugins.addCustom(from: code)
        |> deliverOnMainQueue).start(next: { result in
            switch result {
            case let .installed(name):
                showMessage("Плагин «\(name)» добавлен и включён.")
            case let .invalid(error):
                var text = "В коде нет функции, которая меняет текст. Нужна функция onOutgoingText(text): она получает текст сообщения и возвращает новый."
                if let error = error {
                    text += "\n\nОшибка в коде: " + error
                }
                showMessage(text)
            case .notJavaScript:
                showMessage("Это плагин на Python для Android (exteraGram и похожие клиенты). iPhone не запускает Python, поэтому AyGramm принимает плагины на JavaScript.")
            case .tooLarge:
                showMessage("Файл больше 1 МБ. Плагин AyGramm занимает несколько килобайт текста.")
            case .downloadFailed:
                showMessage("Не удалось скачать файл по ссылке.")
            }
            customPromise.set(AyGrammPlugins.customPlugins)
            installedPromise.set(AyGrammPlugins.installedIds)
        }))
    }

    let arguments = AyGrammPluginsControllerArguments(toggle: { plugin, value in
        if value {
            actionsDisposable.add((AyGrammPlugins.install(plugin)
            |> deliverOnMainQueue).start(next: { _ in
                installedPromise.set(AyGrammPlugins.installedIds)
            }))
        } else {
            AyGrammPlugins.uninstall(id: plugin.id)
            installedPromise.set(AyGrammPlugins.installedIds)
        }
    }, toggleCustom: { plugin, value in
        AyGrammPlugins.setEnabled(id: plugin.id, enabled: value)
        installedPromise.set(AyGrammPlugins.installedIds)
    }, addCustom: {
        guard let clipboard = UIPasteboard.general.string, !clipboard.isEmpty else {
            showMessage("Буфер обмена пуст. Скопируйте код плагина или ссылку на файл .js.")
            return
        }
        addCode(clipboard)
    }, addFile: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        presentControllerImpl?(legacyICloudFilePicker(theme: presentationData.theme, mode: .import, documentTypes: ["public.item", "public.data", "public.content", "public.text"], completion: { urls in
            guard let url = urls.first else {
                return
            }
            let accessing = url.startAccessingSecurityScopedResource()
            let data = try? Data(contentsOf: url)
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
            if let data = data, let code = AyGrammPlugins.decodeText(data) {
                addCode(code)
            } else {
                showMessage("Не удалось прочитать файл. Подойдёт любой текстовый файл с кодом плагина: .js, .txt, .plugin и другие.")
            }
        }))
    }, removeDisabledCustom: {
        AyGrammPlugins.removeDisabledCustom()
        customPromise.set(AyGrammPlugins.customPlugins)
    })

    actionsDisposable.add((AyGrammPlugins.catalog()
    |> deliverOnMainQueue).start(next: { plugins in
        AyGrammPlugins.markSeen(plugins.map { $0.id })
        catalogPromise.set(plugins)
    }))

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        catalogPromise.get(),
        installedPromise.get(),
        customPromise.get()
    )
    |> map { presentationData, catalog, installed, custom -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var entries: [AyGrammPluginsEntry] = [.header]
        if let catalog = catalog {
            if catalog.isEmpty {
                entries.append(.status("Каталог пуст или GitHub не ответил."))
            }
            for (index, plugin) in catalog.enumerated() {
                entries.append(.plugin(Int32(index), plugin, installed.contains(plugin.id)))
            }
        } else {
            entries.append(.status("Загрузка каталога…"))
        }
        entries.append(.footer)
        entries.append(.customHeader)
        for (index, plugin) in custom.enumerated() {
            entries.append(.custom(Int32(index), plugin, installed.contains(plugin.id)))
        }
        entries.append(.addCustom)
        entries.append(.addFile)
        if custom.contains(where: { !installed.contains($0.id) }) {
            entries.append(.removeDisabled)
        }
        entries.append(.customFooter)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Плагины"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: true)
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }

    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    return controller
}

// MARK: - Админ-панель

// Админ видит только подписчиков канала @augrammipa. При подписке AyGramm предупреждает, что автор увидит
// @username и имя. Тех, кто не подписался, AyGramm не раскрывает: так написано в согласии.
private struct AyGrammAdminMember: Equatable {
    let peerId: EnginePeer.Id
    let id: Int64
    let username: String?
    let name: String
    let date: Int32?
    let banUntil: Int32?
    let isBanned: Bool

    var title: String {
        if let username = self.username, !username.isEmpty {
            return "@" + username
        }
        return self.name
    }
}

private struct AyGrammAdminVersion: Equatable {
    let tag: String
    let count: Int
}

private func ayGrammAdminMember(_ participant: RenderedChannelParticipant, banned: Bool) -> AyGrammAdminMember {
    return AyGrammAdminMember(peerId: participant.peer.id, id: participant.peer.id.id._internalGetInt64Value(), username: participant.peer.addressName, name: participant.peer.debugDisplayTitle, date: AyGrammCommunity.joinDate(participant.participant), banUntil: banned ? AyGrammCommunity.banUntil(participant.participant) : nil, isBanned: banned)
}

private func ayGrammAdminDate(_ timestamp: Int32) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "dd.MM.yy HH:mm"
    return formatter.string(from: Date(timeIntervalSince1970: Double(timestamp)))
}

private final class AyGrammAdminControllerArguments {
    let openMember: (AyGrammAdminMember) -> Void
    let runAction: (Int) -> Void

    init(openMember: @escaping (AyGrammAdminMember) -> Void, runAction: @escaping (Int) -> Void) {
        self.openMember = openMember
        self.runAction = runAction
    }
}

// Номер строки / 10000 = раздел: 0 статистика, 1 версии, 2 действия, 3 подписчики, 4 забаненные, 5 журнал.
private enum AyGrammAdminEntry: ItemListNodeEntry {
    case header(Int32, String)
    case stat(Int32, String, String)
    case action(Int32, String, String, UInt32, Int)
    case member(Int32, AyGrammAdminMember)
    case info(Int32, String)

    var section: ItemListSectionId {
        return self.stableId / 10000
    }

    var stableId: Int32 {
        switch self {
        case let .header(id, _):
            return id
        case let .stat(id, _, _):
            return id
        case let .action(id, _, _, _, _):
            return id
        case let .member(id, _):
            return id
        case let .info(id, _):
            return id
        }
    }

    static func <(lhs: AyGrammAdminEntry, rhs: AyGrammAdminEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! AyGrammAdminControllerArguments
        switch self {
        case let .header(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .stat(_, title, value):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: title, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .none, action: nil)
        case let .action(_, title, symbol, color, kind):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: ayGrammIcon(symbol, color), title: title, label: "", sectionId: self.section, style: .blocks, action: {
                arguments.runAction(kind)
            })
        case let .member(_, member):
            let label: String
            if member.isBanned {
                if let until = member.banUntil, until > 0 && until < Int32.max - 1 {
                    label = "до " + ayGrammAdminDate(until)
                } else {
                    label = "навсегда"
                }
            } else if let date = member.date {
                label = ayGrammAdminDate(date)
            } else {
                label = ""
            }
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: member.title, label: label, sectionId: self.section, style: .blocks, action: {
                arguments.openMember(member)
            })
        case let .info(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private func ayGrammAdminController(context: AccountContext) -> ViewController {
    let downloadsPromise = ValuePromise<Int?>(nil, ignoreRepeated: true)
    let versionsPromise = ValuePromise<[AyGrammAdminVersion]>([], ignoreRepeated: true)
    let countPromise = ValuePromise<Int?>(nil, ignoreRepeated: true)
    let membersPromise = ValuePromise<[AyGrammAdminMember]?>(nil, ignoreRepeated: true)
    let bannedPromise = ValuePromise<[AyGrammAdminMember]>([], ignoreRepeated: true)
    let logPromise = ValuePromise<[String]>(AyGrammAdminLog.entries(), ignoreRepeated: true)
    let actionsDisposable = DisposableSet()
    var channelId: EnginePeer.Id?
    var loadedMembers: [AyGrammAdminMember] = []
    var loadedBanned: [AyGrammAdminMember] = []
    var nextOffset: Int32 = 0

    var presentControllerImpl: ((ViewController) -> Void)?

    let showMessage: (String) -> Void = { text in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        presentControllerImpl?(textAlertController(context: context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]))
    }

    let loadMembers: (Bool) -> Void = { reset in
        guard let channelId = channelId else {
            return
        }
        if reset {
            nextOffset = 0
            loadedMembers = []
        }
        actionsDisposable.add((AyGrammCommunity.members(engine: context.engine, channelId: channelId, banned: false, offset: nextOffset)
        |> deliverOnMainQueue).start(next: { members in
            for participant in members {
                let member = ayGrammAdminMember(participant, banned: false)
                if !loadedMembers.contains(where: { $0.peerId == member.peerId }) {
                    loadedMembers.append(member)
                }
            }
            nextOffset += Int32(members.count)
            membersPromise.set(loadedMembers)
        }))
    }

    let loadBanned: () -> Void = {
        guard let channelId = channelId else {
            return
        }
        actionsDisposable.add((AyGrammCommunity.members(engine: context.engine, channelId: channelId, banned: true)
        |> deliverOnMainQueue).start(next: { members in
            loadedBanned = members.map { ayGrammAdminMember($0, banned: true) }
            bannedPromise.set(loadedBanned)
        }))
    }

    let loadStats: () -> Void = {
        actionsDisposable.add((AyGrammCommunity.releaseDownloads()
        |> deliverOnMainQueue).start(next: { releases in
            guard let releases = releases else {
                return
            }
            downloadsPromise.set(releases.reduce(0) { $0 + $1.1 })
            versionsPromise.set(releases.prefix(10).map { AyGrammAdminVersion(tag: $0.0, count: $0.1) })
        }))
    }

    let reload: () -> Void = {
        loadMembers(true)
        loadBanned()
    }

    // seconds: nil снимает бан, Int32.max даёт бан навсегда, остальное = бан на столько секунд.
    let ban: (AyGrammAdminMember, Int32?) -> Void = { member, seconds in
        guard let channelId = channelId else {
            return
        }
        var until = Int32.max
        let what: String
        if let seconds = seconds {
            if seconds != Int32.max {
                until = Int32(Date().timeIntervalSince1970) + seconds
                what = "Бан на \(seconds / 86400) дн."
            } else {
                what = "Бан навсегда"
            }
        } else {
            what = "Разбан"
        }
        actionsDisposable.add((AyGrammCommunity.setBanned(engine: context.engine, channelId: channelId, memberId: member.peerId, banned: seconds != nil, until: until)
        |> deliverOnMainQueue).start(completed: {
            AyGrammAdminLog.add(what + ": " + member.title + " (ID \(member.id))")
            logPromise.set(AyGrammAdminLog.entries())
            reload()
        }))
    }

    let openMember: (AyGrammAdminMember) -> Void = { member in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        var lines: [String] = [member.name]
        if let username = member.username, !username.isEmpty {
            lines.append("@" + username)
        }
        lines.append("ID: \(member.id)")
        if member.isBanned {
            if let until = member.banUntil, until > 0 && until < Int32.max - 1 {
                lines.append("Забанен до " + ayGrammAdminDate(until))
            } else {
                lines.append("Забанен навсегда")
            }
        } else if let date = member.date {
            lines.append("Подписан с " + ayGrammAdminDate(date))
        } else {
            lines.append("Не подписан на канал")
        }
        var actions: [TextAlertAction] = []
        if let username = member.username, !username.isEmpty {
            actions.append(TextAlertAction(type: .genericAction, title: "Скопировать @username", action: {
                UIPasteboard.general.string = "@" + username
            }))
        }
        actions.append(TextAlertAction(type: .genericAction, title: "Скопировать ID", action: {
            UIPasteboard.general.string = "\(member.id)"
        }))
        if member.isBanned {
            actions.append(TextAlertAction(type: .defaultAction, title: "Разбанить", action: {
                ban(member, nil)
            }))
        } else {
            actions.append(TextAlertAction(type: .genericAction, title: "Бан на 1 день", action: {
                ban(member, 86400)
            }))
            actions.append(TextAlertAction(type: .genericAction, title: "Бан на 7 дней", action: {
                ban(member, 7 * 86400)
            }))
            actions.append(TextAlertAction(type: .destructiveAction, title: "Бан навсегда", action: {
                ban(member, Int32.max)
            }))
        }
        actions.append(TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}))
        presentControllerImpl?(textAlertController(context: context, title: member.title, text: lines.joined(separator: "\n"), actions: actions))
    }

    let checkUsername: () -> Void = {
        let text = UIPasteboard.general.string ?? ""
        guard let channelId = channelId, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showMessage("Скопируйте @username пользователя, потом нажмите ещё раз.")
            return
        }
        actionsDisposable.add((AyGrammCommunity.resolveUser(engine: context.engine, username: text)
        |> mapToSignal { peer -> Signal<(EnginePeer?, ChannelParticipant?), NoError> in
            guard let peer = peer else {
                return .single((nil, nil))
            }
            return context.engine.peers.fetchChannelParticipant(peerId: channelId, participantId: peer.id)
            |> map { participant -> (EnginePeer?, ChannelParticipant?) in
                return (peer, participant)
            }
        }
        |> deliverOnMainQueue).start(next: { peer, participant in
            guard let peer = peer, case .user = peer else {
                showMessage("Пользователь «\(text)» не найден.")
                return
            }
            let isBanned = AyGrammCommunity.isBanned(participant)
            openMember(AyGrammAdminMember(peerId: peer.id, id: peer.id.id._internalGetInt64Value(), username: peer.addressName, name: peer.debugDisplayTitle, date: participant.flatMap { AyGrammCommunity.joinDate($0) }, banUntil: isBanned ? participant.flatMap { AyGrammCommunity.banUntil($0) } : nil, isBanned: isBanned))
        }))
    }

    let arguments = AyGrammAdminControllerArguments(openMember: { member in
        openMember(member)
    }, runAction: { kind in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        switch kind {
        case 0:
            checkUsername()
        case 1:
            var rows: [String] = ["id;username;имя;подписан"]
            for member in loadedMembers {
                rows.append("\(member.id);\(member.username ?? "");\(member.name);\(member.date.flatMap { ayGrammAdminDate($0) } ?? "")")
            }
            UIPasteboard.general.string = rows.joined(separator: "\n")
            showMessage("Скопировано подписчиков: \(loadedMembers.count). Список можно вставить в Заметки или Excel.")
        case 2:
            loadMembers(false)
        case 3:
            if loadedBanned.isEmpty {
                showMessage("Забаненных нет.")
                return
            }
            presentControllerImpl?(textAlertController(context: context, title: nil, text: "Разбанить всех (\(loadedBanned.count))? Функции AyGramm у них снова заработают.", actions: [
                TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}),
                TextAlertAction(type: .destructiveAction, title: "Разбанить всех", action: {
                    guard let channelId = channelId else {
                        return
                    }
                    var signal: Signal<Void, NoError> = .complete()
                    for member in loadedBanned {
                        signal = signal |> then(AyGrammCommunity.setBanned(engine: context.engine, channelId: channelId, memberId: member.peerId, banned: false))
                    }
                    let count = loadedBanned.count
                    actionsDisposable.add((signal |> deliverOnMainQueue).start(completed: {
                        AyGrammAdminLog.add("Разбан всех: \(count)")
                        logPromise.set(AyGrammAdminLog.entries())
                        reload()
                    }))
                })
            ]))
        case 4:
            reload()
            loadStats()
        default:
            AyGrammAdminLog.clear()
            logPromise.set([])
        }
    })

    loadStats()

    actionsDisposable.add((AyGrammCommunity.channel(engine: context.engine)
    |> deliverOnMainQueue).start(next: { peer in
        guard let peer = peer else {
            membersPromise.set([])
            return
        }
        channelId = peer.id
        actionsDisposable.add(context.engine.peers.fetchAndUpdateCachedPeerData(peerId: peer.id).start())
        actionsDisposable.add((context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.ParticipantCount(id: peer.id))
        |> deliverOnMainQueue).start(next: { count in
            countPromise.set(count)
        }))
        reload()
    }))

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        downloadsPromise.get(),
        versionsPromise.get(),
        countPromise.get(),
        membersPromise.get(),
        bannedPromise.get(),
        logPromise.get()
    )
    |> map { presentationData, downloads, versions, count, members, banned, log -> (ItemListControllerState, (ItemListNodeState, Any)) in
        let now = Int32(Date().timeIntervalSince1970)
        let loaded = members ?? []
        let newDay = loaded.filter { ($0.date ?? 0) > now - 86400 }.count
        let newWeek = loaded.filter { ($0.date ?? 0) > now - 7 * 86400 }.count

        var entries: [AyGrammAdminEntry] = []
        entries.append(.header(0, "СТАТИСТИКА"))
        entries.append(.stat(1, "Скачиваний", downloads.flatMap { "\($0)" } ?? "…"))
        entries.append(.stat(2, "Подписчиков", count.flatMap { "\($0)" } ?? "…"))
        if let downloads = downloads, let count = count, downloads > 0 {
            entries.append(.stat(3, "Подписались из скачавших", "\(min(100, count * 100 / downloads))%"))
        }
        entries.append(.stat(4, "Новых за сутки", "\(newDay)"))
        entries.append(.stat(5, "Новых за 7 дней", "\(newWeek)"))
        entries.append(.stat(6, "Забанено", "\(banned.count)"))

        if !versions.isEmpty {
            entries.append(.header(10000, "СКАЧИВАНИЯ ПО ВЕРСИЯМ"))
            for (index, version) in versions.enumerated() {
                entries.append(.stat(10001 + Int32(index), version.tag, "\(version.count)"))
            }
        }

        entries.append(.header(20000, "ДЕЙСТВИЯ"))
        entries.append(.action(20001, "Проверить @username из буфера", "magnifyingglass", AyGrammColor.blue, 0))
        entries.append(.action(20002, "Скопировать список подписчиков", "doc.on.doc.fill", AyGrammColor.teal, 1))
        entries.append(.action(20003, "Разбанить всех", "lock.open.fill", AyGrammColor.green, 3))
        entries.append(.action(20004, "Обновить", "arrow.clockwise", AyGrammColor.gray, 4))

        entries.append(.header(30000, "ПОДПИСЧИКИ, ЗАГРУЖЕНО \(loaded.count)"))
        if let members = members {
            if members.isEmpty {
                entries.append(.info(39999, "Список пуст. Его видит только владелец канала @\(AyGrammCommunity.channelUsername)."))
            }
            for (index, member) in members.prefix(9000).enumerated() {
                entries.append(.member(30001 + Int32(index), member))
            }
            if let count = count, members.count < count {
                entries.append(.action(39998, "Загрузить ещё 200", "arrow.down.circle.fill", AyGrammColor.blue, 2))
            }
        } else {
            entries.append(.info(39999, "Загрузка…"))
        }

        entries.append(.header(40000, "ЗАБАНЕНЫ"))
        if banned.isEmpty {
            entries.append(.info(49999, "Никого."))
        }
        for (index, member) in banned.prefix(9000).enumerated() {
            entries.append(.member(40001 + Int32(index), member))
        }

        entries.append(.header(50000, "ЖУРНАЛ ДЕЙСТВИЙ"))
        if log.isEmpty {
            entries.append(.info(50001, "Пусто. Здесь появятся баны и разбаны."))
        } else {
            entries.append(.info(50001, log.prefix(30).joined(separator: "\n")))
            entries.append(.action(59998, "Очистить журнал", "trash.fill", AyGrammColor.red, 5))
        }
        entries.append(.info(59999, "Список подписчиков Telegram отдаёт только владельцу канала. Кто скачал AyGramm и не подписался, здесь не виден: при подписке AyGramm обещает, что больше ничего не отправляет."))

        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Админ-панель"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: true)
        return (controllerState, (listState, arguments))
    }
    |> afterDisposed {
        actionsDisposable.dispose()
    }

    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    return controller
}
