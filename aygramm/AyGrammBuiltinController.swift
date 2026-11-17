import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import ItemListUI
import AccountContext
import PresentationDataUtils

// Встроенные плагины AyGramm: функции, которые работают внутри приложения и включаются переключателем.
// Плагины из каталога и свои плагины меняют только текст исходящих сообщений, а встроенные могут больше.

private final class AyGrammBuiltinArguments {
    let toggle: (String, Bool) -> Void
    let openDecorations: () -> Void
    let openProfiles: () -> Void
    let openLog: () -> Void

    init(toggle: @escaping (String, Bool) -> Void, openDecorations: @escaping () -> Void, openProfiles: @escaping () -> Void, openLog: @escaping () -> Void) {
        self.toggle = toggle
        self.openDecorations = openDecorations
        self.openProfiles = openProfiles
        self.openLog = openLog
    }
}

private enum AyGrammBuiltinEntry: ItemListNodeEntry {
    case header
    case toggle(Int32, String, String, String, Bool)
    case decorations
    case profiles
    case log(Int)
    case footer

    var section: ItemListSectionId {
        return 0
    }

    var stableId: Int32 {
        switch self {
        case .header:
            return 0
        case let .toggle(id, _, _, _, _):
            return id
        case .decorations:
            return 51
        case .profiles:
            return 90
        case .log:
            return 91
        case .footer:
            return 99
        }
    }

    static func <(lhs: AyGrammBuiltinEntry, rhs: AyGrammBuiltinEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! AyGrammBuiltinArguments
        switch self {
        case .header:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ВСТРОЕННЫЕ ПЛАГИНЫ", sectionId: self.section)
        case let .toggle(_, key, title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(key, value)
            })
        case .decorations:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: "Настроить украшения", label: "", sectionId: self.section, style: .blocks, action: {
                arguments.openDecorations()
            })
        case .profiles:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: "Профили настроек", label: "", sectionId: self.section, style: .blocks, action: {
                arguments.openProfiles()
            })
        case let .log(count):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: "Журнал плагинов", label: "\(count)", sectionId: self.section, style: .blocks, action: {
                arguments.openLog()
            })
        case .footer:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Встроенные плагины работают внутри AyGramm и ничего не отправляют автору. Каждый выключается переключателем. Изменение лимита аккаунтов действует при следующем добавлении аккаунта."), sectionId: self.section)
        }
    }
}

private func ayGrammBuiltinValues() -> [String: Bool] {
    var values: [String: Bool] = [:]
    for key in AyGrammSettings.profileKeys {
        values[key] = AyGrammSettings.storedValue(key)
    }
    return values
}

func ayGrammBuiltinController(context: AccountContext) -> ViewController {
    let valuesPromise = ValuePromise<[String: Bool]>(ayGrammBuiltinValues(), ignoreRepeated: true)
    let logCountPromise = ValuePromise<Int>(AyGrammPluginLog.entries().count, ignoreRepeated: true)
    var pushControllerImpl: ((ViewController) -> Void)?

    let arguments = AyGrammBuiltinArguments(toggle: { key, value in
        AyGrammSettings.setValue(key, value)
        valuesPromise.set(ayGrammBuiltinValues())
    }, openDecorations: {
        pushControllerImpl?(ayGrammDecorationsController(context: context))
    }, openProfiles: {
        pushControllerImpl?(ayGrammProfilesController(context: context, applied: {
            valuesPromise.set(ayGrammBuiltinValues())
        }))
    }, openLog: {
        pushControllerImpl?(ayGrammPluginLogController(context: context, cleared: {
            logCountPromise.set(0)
        }))
    })

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        valuesPromise.get(),
        logCountPromise.get()
    )
    |> map { presentationData, values, logCount -> (ItemListControllerState, (ItemListNodeState, Any)) in
        func value(_ key: String) -> Bool {
            return values[key] ?? AyGrammSettings.storedValue(key)
        }
        var entries: [AyGrammBuiltinEntry] = [.header]
        entries.append(.toggle(10, AyGrammSettings.keepAliveKey, "Звонки в фоне", "Свёрнутый AyGramm держит связь с Telegram: приходят звонки и уведомления о сообщениях. Батарея садится быстрее.", value(AyGrammSettings.keepAliveKey)))
        entries.append(.toggle(11, AyGrammSettings.keepAliveBatteryKey, "Беречь заряд", "При заряде ниже 20% без зарядки «Звонки в фоне» не включаются.", value(AyGrammSettings.keepAliveBatteryKey)))
        entries.append(.toggle(20, AyGrammSettings.unlimitedAccountsKey, "Аккаунты без лимита", "До 1000 аккаунтов вместо 3. Каждый аккаунт занимает память, при 15–20 аккаунтах iOS может закрывать приложение.", value(AyGrammSettings.unlimitedAccountsKey)))
        entries.append(.toggle(50, AyGrammSettings.decorationsKey, "Украшения профиля", "Подарки с лентой «украшение» во вкладке «Подарки» своего профиля. Видны только на этом телефоне.", value(AyGrammSettings.decorationsKey)))
        entries.append(.decorations)
        entries.append(.toggle(60, AyGrammSettings.tokensKey, "Подстановки", "{дата}, {время} и {день} в сообщении заменяются на текущие значения при отправке.", value(AyGrammSettings.tokensKey)))
        entries.append(.toggle(70, AyGrammSettings.readAloudKey, "Прочитать вслух", "Пункт в меню сообщения: голос iOS читает текст. Повторное нажатие останавливает чтение.", value(AyGrammSettings.readAloudKey)))
        entries.append(.profiles)
        entries.append(.log(logCount))
        entries.append(.footer)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Встроенные плагины"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: false)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    return controller
}

// MARK: - Профили настроек

private enum AyGrammProfilesEntry: ItemListNodeEntry {
    case header
    case apply(Int32, String, Bool)
    case save(Int32, String)
    case footer

    var section: ItemListSectionId {
        return 0
    }

    var stableId: Int32 {
        switch self {
        case .header:
            return 0
        case let .apply(id, _, _):
            return id
        case let .save(id, _):
            return id
        case .footer:
            return 99
        }
    }

    static func <(lhs: AyGrammProfilesEntry, rhs: AyGrammProfilesEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let action = arguments as! (String, Bool) -> Void
        switch self {
        case .header:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ПРОФИЛИ", sectionId: self.section)
        case let .apply(_, name, saved):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: "Включить «\(name)»", label: saved ? "" : "не сохранён", sectionId: self.section, style: .blocks, action: {
                action(name, true)
            })
        case let .save(_, name):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: "Сохранить текущие как «\(name)»", label: "", sectionId: self.section, style: .blocks, action: {
                action(name, false)
            })
        case .footer:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Профиль запоминает все переключатели AyGramm: режим призрака, сообщения, плагины и встроенные плагины. «Включить» возвращает сохранённые значения одним касанием."), sectionId: self.section)
        }
    }
}

private func ayGrammProfilesController(context: AccountContext, applied: @escaping () -> Void) -> ViewController {
    let names = ["Работа", "Дом"]
    let versionPromise = ValuePromise<Int>(0, ignoreRepeated: false)
    var version = 0
    var presentControllerImpl: ((ViewController) -> Void)?

    let showMessage: (String) -> Void = { text in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        presentControllerImpl?(textAlertController(context: context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]))
    }

    let action: (String, Bool) -> Void = { name, apply in
        if apply {
            if AyGrammSettings.applyProfile(name) {
                applied()
                showMessage("Профиль «\(name)» включён.")
            } else {
                showMessage("Профиль «\(name)» ещё не сохранён. Настройте переключатели и нажмите «Сохранить текущие как «\(name)»».")
            }
        } else {
            AyGrammSettings.saveProfile(name)
            version += 1
            versionPromise.set(version)
            showMessage("Текущие настройки сохранены в профиль «\(name)».")
        }
    }

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        versionPromise.get()
    )
    |> map { presentationData, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var entries: [AyGrammProfilesEntry] = [.header]
        for (index, name) in names.enumerated() {
            entries.append(.apply(Int32(10 + index * 10), name, AyGrammSettings.hasProfile(name)))
            entries.append(.save(Int32(11 + index * 10), name))
        }
        entries.append(.footer)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Профили"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: false)
        return (controllerState, (listState, action))
    }

    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    return controller
}

// MARK: - Журнал плагинов

private enum AyGrammPluginLogEntry: ItemListNodeEntry {
    case header
    case entry(Int32, String)
    case empty
    case clear

    var section: ItemListSectionId {
        return 0
    }

    var stableId: Int32 {
        switch self {
        case .header:
            return 0
        case let .entry(index, _):
            return 10 + index
        case .empty:
            return 1
        case .clear:
            return 5000
        }
    }

    static func <(lhs: AyGrammPluginLogEntry, rhs: AyGrammPluginLogEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let clear = arguments as! () -> Void
        switch self {
        case .header:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ПОСЛЕДНИЕ 100 ЗАПИСЕЙ", sectionId: self.section)
        case let .entry(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        case .empty:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Записей нет. Здесь появится, что плагин изменил в сообщении, и ошибки в коде плагинов."), sectionId: self.section)
        case .clear:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, title: "Очистить журнал", label: "", sectionId: self.section, style: .blocks, action: {
                clear()
            })
        }
    }
}

private func ayGrammPluginLogController(context: AccountContext, cleared: @escaping () -> Void) -> ViewController {
    let entriesPromise = ValuePromise<[String]>(AyGrammPluginLog.entries(), ignoreRepeated: true)
    let clear: () -> Void = {
        AyGrammPluginLog.clear()
        entriesPromise.set([])
        cleared()
    }

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        entriesPromise.get()
    )
    |> map { presentationData, log -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var entries: [AyGrammPluginLogEntry] = [.header]
        if log.isEmpty {
            entries.append(.empty)
        }
        for (index, text) in log.enumerated() {
            entries.append(.entry(Int32(index), text))
        }
        if !log.isEmpty {
            entries.append(.clear)
        }
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Журнал плагинов"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: false)
        return (controllerState, (listState, clear))
    }

    return ItemListController(context: context, state: signal)
}
