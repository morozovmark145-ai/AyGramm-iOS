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
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(key, value)
            })
        case .ghostFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Включённые пункты не отправляются на сервер Telegram, поэтому собеседники их не видят. После отправки сообщения AyGramm сразу возвращает статус «не в сети». Чтобы отметить чат прочитанным, зажмите сообщение → «Отправить прочтение». Если ответить в чате, Telegram сам отметит его прочитанным."), sectionId: self.section)
        case .messagesHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "СООБЩЕНИЯ", sectionId: self.section)
        case let .deleted(count):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: "Удалённые сообщения", label: count, sectionId: self.section, style: .blocks, action: {
                arguments.openDeleted()
            })
        case .messagesFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Удалённое собеседником сообщение остаётся полупрозрачным, рядом со временем появляется 🗑. Прежние версии изменённого сообщения открываются долгим нажатием → «История изменений». «Тихая отправка» отправляет ваши сообщения без звука у получателя."), sectionId: self.section)
        case .pluginsHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ПЛАГИНЫ", sectionId: self.section)
        case .plugins:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: "Плагины", label: "", sectionId: self.section, style: .blocks, action: {
                arguments.openPlugins()
            })
        case .decorations:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: "Встроенные плагины", label: "", sectionId: self.section, style: .blocks, action: {
                arguments.openDecorations()
            })
        case .pluginsFooter:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Плагины из открытого каталога на GitHub и свои: из буфера обмена или из файла .js. Плагин получает только текст вашего исходящего сообщения и не видит переписки."), sectionId: self.section)
        case .communityHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "СООБЩЕСТВО", sectionId: self.section)
        case .channel:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: "Канал AyGramm", label: "@" + AyGrammCommunity.channelUsername, sectionId: self.section, style: .blocks, action: {
                arguments.openChannel()
            })
        case .join:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: "Подписаться на канал", label: "", sectionId: self.section, style: .blocks, action: {
                arguments.joinChannel()
            })
        case let .downloads(value):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: "Скачиваний AyGramm", label: value, sectionId: self.section, style: .blocks, disclosureStyle: .none, action: nil)
        case let .version(value):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: "Версия", label: value, sectionId: self.section, style: .blocks, action: {
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
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: "Админ-панель", label: "", sectionId: self.section, style: .blocks, action: {
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
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: "Скопировать всё", label: "", sectionId: self.section, style: .blocks, action: {
                arguments.copyAll()
            })
        case .clear:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: "Очистить список", label: "", sectionId: self.section, style: .blocks, action: {
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
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: plugin.name, text: plugin.description, value: installed, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(plugin, value)
            })
        case .footer:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Исходный код каждого плагина открыт: " + AyGrammPlugins.catalogPageUrl + ". Плагин меняет только текст исходящего сообщения без форматирования и работает без доступа к сети."), sectionId: self.section)
        case .customHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "МОИ ПЛАГИНЫ", sectionId: self.section)
        case let .custom(_, plugin, enabled):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: plugin.name, value: enabled, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggleCustom(plugin, value)
            })
        case .addCustom:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: "Добавить из буфера обмена", label: "", sectionId: self.section, style: .blocks, action: {
                arguments.addCustom()
            })
        case .addFile:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: "Добавить из файла", label: "", sectionId: self.section, style: .blocks, action: {
                arguments.addFile()
            })
        case .removeDisabled:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: "Удалить выключенные", label: "", sectionId: self.section, style: .blocks, action: {
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
            case .invalid:
                showMessage("Это не плагин AyGramm: в коде нет функции onOutgoingText или он выполняется с ошибкой.")
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
        presentControllerImpl?(legacyICloudFilePicker(theme: presentationData.theme, mode: .import, documentTypes: ["public.item"], completion: { urls in
            guard let url = urls.first else {
                return
            }
            if let code = try? String(contentsOf: url, encoding: .utf8) {
                addCode(code)
            } else {
                showMessage("Не удалось прочитать файл. Нужен текстовый файл .js.")
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

private struct AyGrammAdminMember: Equatable {
    let peerId: EnginePeer.Id
    let title: String
    let isBanned: Bool
}

private final class AyGrammAdminControllerArguments {
    let toggleBan: (AyGrammAdminMember) -> Void

    init(toggleBan: @escaping (AyGrammAdminMember) -> Void) {
        self.toggleBan = toggleBan
    }
}

private enum AyGrammAdminEntry: ItemListNodeEntry {
    case statsHeader
    case stat(Int32, String, String)
    case membersHeader(Int32, String)
    case member(Int32, AyGrammAdminMember)
    case info(Int32, String)

    var section: ItemListSectionId {
        switch self {
        case .statsHeader, .stat:
            return 0
        case let .membersHeader(id, _):
            return id < 20000 ? 1 : 2
        case let .member(id, _):
            return id < 20000 ? 1 : 2
        case let .info(id, _):
            return id < 20000 ? 1 : 2
        }
    }

    var stableId: Int32 {
        switch self {
        case .statsHeader:
            return 0
        case let .stat(id, _, _):
            return id
        case let .membersHeader(id, _):
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
        case .statsHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "СТАТИСТИКА", sectionId: self.section)
        case let .stat(_, title, value):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: title, label: value, sectionId: self.section, style: .blocks, disclosureStyle: .none, action: nil)
        case let .membersHeader(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .member(_, member):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: member.title, label: member.isBanned ? "Разбанить" : "Забанить", sectionId: self.section, style: .blocks, action: {
                arguments.toggleBan(member)
            })
        case let .info(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private func ayGrammAdminTitle(_ participant: RenderedChannelParticipant) -> String {
    if let username = participant.peer.addressName, !username.isEmpty {
        return "@" + username
    }
    return participant.peer.debugDisplayTitle
}

private func ayGrammAdminController(context: AccountContext) -> ViewController {
    let downloadsPromise = ValuePromise<String>("…", ignoreRepeated: true)
    let countPromise = ValuePromise<String>("…", ignoreRepeated: true)
    let membersPromise = ValuePromise<[AyGrammAdminMember]?>(nil, ignoreRepeated: true)
    let bannedPromise = ValuePromise<[AyGrammAdminMember]>([], ignoreRepeated: true)
    let actionsDisposable = DisposableSet()
    var channelId: EnginePeer.Id?

    var presentControllerImpl: ((ViewController) -> Void)?

    let reload: () -> Void = {
        guard let channelId = channelId else {
            return
        }
        actionsDisposable.add((combineLatest(
            AyGrammCommunity.members(engine: context.engine, channelId: channelId, banned: false),
            AyGrammCommunity.members(engine: context.engine, channelId: channelId, banned: true)
        )
        |> deliverOnMainQueue).start(next: { members, banned in
            membersPromise.set(members.map { AyGrammAdminMember(peerId: $0.peer.id, title: ayGrammAdminTitle($0), isBanned: false) })
            bannedPromise.set(banned.map { AyGrammAdminMember(peerId: $0.peer.id, title: ayGrammAdminTitle($0), isBanned: true) })
        }))
    }

    let arguments = AyGrammAdminControllerArguments(toggleBan: { member in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let text: String
        if member.isBanned {
            text = "Разбанить \(member.title)? Функции AyGramm у него снова заработают."
        } else {
            text = "Забанить \(member.title)? Он будет удалён из канала @\(AyGrammCommunity.channelUsername), а функции AyGramm у него выключатся."
        }
        presentControllerImpl?(textAlertController(context: context, title: nil, text: text, actions: [
            TextAlertAction(type: .genericAction, title: presentationData.strings.Common_Cancel, action: {}),
            TextAlertAction(type: .destructiveAction, title: member.isBanned ? "Разбанить" : "Забанить", action: {
                guard let channelId = channelId else {
                    return
                }
                actionsDisposable.add((AyGrammCommunity.setBanned(engine: context.engine, channelId: channelId, memberId: member.peerId, banned: !member.isBanned)
                |> deliverOnMainQueue).start(completed: {
                    reload()
                }))
            })
        ]))
    })

    actionsDisposable.add((AyGrammCommunity.downloadCount()
    |> deliverOnMainQueue).start(next: { count in
        if let count = count {
            downloadsPromise.set("\(count)")
        } else {
            downloadsPromise.set("нет данных")
        }
    }))

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
            if let count = count {
                countPromise.set("\(count)")
            }
        }))
        reload()
    }))

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        downloadsPromise.get(),
        countPromise.get(),
        membersPromise.get(),
        bannedPromise.get()
    )
    |> map { presentationData, downloads, count, members, banned -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var entries: [AyGrammAdminEntry] = []
        entries.append(.statsHeader)
        entries.append(.stat(1, "Скачиваний", downloads))
        entries.append(.stat(2, "Зарегистрировано", count))
        entries.append(.membersHeader(10, "ПОДПИСЧИКИ, ДО 200 ПОСЛЕДНИХ"))
        if let members = members {
            if members.isEmpty {
                entries.append(.info(11, "Список пуст. Его видит только владелец канала @\(AyGrammCommunity.channelUsername)."))
            }
            for (index, member) in members.enumerated() {
                entries.append(.member(100 + Int32(index), member))
            }
        } else {
            entries.append(.info(11, "Загрузка…"))
        }
        entries.append(.membersHeader(20000, "ЗАБАНЕНЫ"))
        if banned.isEmpty {
            entries.append(.info(20001, "Никого."))
        }
        for (index, member) in banned.enumerated() {
            entries.append(.member(20100 + Int32(index), member))
        }
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
