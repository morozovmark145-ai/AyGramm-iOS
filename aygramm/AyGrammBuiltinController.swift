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
// Экран разбит на 5 разделов: связь, аккаунты, профиль, сообщения, инструменты.

private final class AyGrammBuiltinArguments {
    let toggle: (String, Bool) -> Void
    let openDecorations: () -> Void
    let openProfiles: () -> Void
    let openLog: () -> Void
    let openFonts: () -> Void
    let openVoice: () -> Void
    let openCrashLog: () -> Void
    let exportBackup: () -> Void
    let restoreBackup: () -> Void

    init(toggle: @escaping (String, Bool) -> Void, openDecorations: @escaping () -> Void, openProfiles: @escaping () -> Void, openLog: @escaping () -> Void, openFonts: @escaping () -> Void, openVoice: @escaping () -> Void, openCrashLog: @escaping () -> Void, exportBackup: @escaping () -> Void, restoreBackup: @escaping () -> Void) {
        self.toggle = toggle
        self.openFonts = openFonts
        self.openVoice = openVoice
        self.openCrashLog = openCrashLog
        self.exportBackup = exportBackup
        self.restoreBackup = restoreBackup
        self.openDecorations = openDecorations
        self.openProfiles = openProfiles
        self.openLog = openLog
    }
}

// stableId / 100 = номер раздела, поэтому строки сами попадают в свой раздел.
private enum AyGrammBuiltinEntry: ItemListNodeEntry {
    case sectionHeader(Int32, String)
    case toggle(Int32, String, String, String, Bool)
    case decorations
    case font(String)
    case voice(String)
    case profiles
    case log(Int)
    case crashLog(Bool)
    case backupExport
    case backupRestore
    case footer

    var section: ItemListSectionId {
        return self.stableId / 100
    }

    var stableId: Int32 {
        switch self {
        case let .sectionHeader(id, _):
            return id
        case let .toggle(id, _, _, _, _):
            return id
        case .decorations:
            return 311
        case .font:
            return 411
        case .voice:
            return 414
        case .profiles:
            return 510
        case .log:
            return 511
        case .crashLog:
            return 512
        case .backupExport:
            return 513
        case .backupRestore:
            return 514
        case .footer:
            return 599
        }
    }

    static func <(lhs: AyGrammBuiltinEntry, rhs: AyGrammBuiltinEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! AyGrammBuiltinArguments
        switch self {
        case let .sectionHeader(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .toggle(_, key, title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, icon: ayGrammKeyIcon(key), title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(key, value)
            })
        case .decorations:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: ayGrammIcon("paintbrush.fill", AyGrammColor.purple), title: "Настроить украшения", label: "", sectionId: self.section, style: .blocks, action: {
                arguments.openDecorations()
            })
        case let .font(name):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: ayGrammIcon("textformat", AyGrammColor.indigo), title: "Шрифт сообщений", label: name, sectionId: self.section, style: .blocks, action: {
                arguments.openFonts()
            })
        case let .voice(name):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: ayGrammIcon("waveform", AyGrammColor.pink), title: "Изменение голоса", label: name, sectionId: self.section, style: .blocks, action: {
                arguments.openVoice()
            })
        case .profiles:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: ayGrammIcon("slider.horizontal.3", AyGrammColor.gray), title: "Профили настроек", label: "Работа, Дом", sectionId: self.section, style: .blocks, action: {
                arguments.openProfiles()
            })
        case let .log(count):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: ayGrammIcon("doc.text.fill", AyGrammColor.gray), title: "Журнал плагинов", label: "\(count)", sectionId: self.section, style: .blocks, action: {
                arguments.openLog()
            })
        case let .crashLog(hasCrash):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: ayGrammIcon("exclamationmark.triangle.fill", AyGrammColor.orange), title: "Журнал вылетов", label: hasCrash ? "есть запись" : "пусто", sectionId: self.section, style: .blocks, action: {
                arguments.openCrashLog()
            })
        case .backupExport:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: ayGrammIcon("square.and.arrow.up.fill", AyGrammColor.blue), title: "Скопировать резервную копию", label: "", sectionId: self.section, style: .blocks, action: {
                arguments.exportBackup()
            })
        case .backupRestore:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: ayGrammIcon("arrow.counterclockwise", AyGrammColor.green), title: "Восстановить из буфера обмена", label: "", sectionId: self.section, style: .blocks, action: {
                arguments.restoreBackup()
            })
        case .footer:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Встроенные плагины работают внутри AyGramm и ничего не отправляют автору. Новый лимит аккаунтов действует при следующем добавлении аккаунта."), sectionId: self.section)
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
    let fontPromise = ValuePromise<Int>(AyGrammFonts.selectedIndex, ignoreRepeated: true)
    let voicePromise = ValuePromise<Int>(AyGrammVoice.selectedIndex, ignoreRepeated: true)
    let crashPromise = ValuePromise<Bool>(AyGrammCrashLog.lastReport != nil, ignoreRepeated: true)
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController) -> Void)?
    let showMessage: (String) -> Void = { text in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        presentControllerImpl?(textAlertController(context: context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]))
    }

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
    }, openFonts: {
        pushControllerImpl?(ayGrammFontsController(context: context, selected: { index in
            fontPromise.set(index)
        }))
    }, openVoice: {
        pushControllerImpl?(ayGrammVoiceController(context: context, selected: { index in
            voicePromise.set(index)
        }))
    }, openCrashLog: {
        guard let report = AyGrammCrashLog.lastReport else {
            showMessage("Вылетов не было. Если AyGramm закроется сам, причина появится здесь.")
            return
        }
        presentControllerImpl?(textAlertController(context: context, title: "Последний вылет", text: String(report.prefix(700)), actions: [
            TextAlertAction(type: .genericAction, title: "Удалить", action: {
                AyGrammCrashLog.clear()
                crashPromise.set(false)
            }),
            TextAlertAction(type: .defaultAction, title: "Скопировать", action: {
                UIPasteboard.general.string = report
            })
        ]))
    }, exportBackup: {
        if let text = AyGrammBackup.export() {
            UIPasteboard.general.string = text
            showMessage("Резервная копия скопирована: настройки, плагины и украшения. Вставьте её в «Избранное», чтобы сохранить.")
        } else {
            showMessage("Не удалось собрать резервную копию.")
        }
    }, restoreBackup: {
        guard let text = UIPasteboard.general.string, AyGrammBackup.restore(text) else {
            showMessage("В буфере обмена нет резервной копии AyGramm. Скопируйте её текст из «Избранного».")
            return
        }
        valuesPromise.set(ayGrammBuiltinValues())
        fontPromise.set(AyGrammFonts.selectedIndex)
        voicePromise.set(AyGrammVoice.selectedIndex)
        showMessage("Настройки, плагины и украшения восстановлены.")
    })

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        valuesPromise.get(),
        logCountPromise.get(),
        fontPromise.get(),
        voicePromise.get(),
        crashPromise.get()
    )
    |> map { presentationData, values, logCount, fontIndex, voiceIndex, hasCrash -> (ItemListControllerState, (ItemListNodeState, Any)) in
        func value(_ key: String) -> Bool {
            return values[key] ?? AyGrammSettings.storedValue(key)
        }
        var entries: [AyGrammBuiltinEntry] = []
        entries.append(.sectionHeader(100, "СВЯЗЬ"))
        entries.append(.toggle(110, AyGrammSettings.keepAliveKey, "Звонки в фоне", "Свёрнутый AyGramm принимает звонки и сообщения. Батарея садится быстрее.", value(AyGrammSettings.keepAliveKey)))
        entries.append(.toggle(111, AyGrammSettings.keepAliveBatteryKey, "Беречь заряд", "Ниже 20% без зарядки «Звонки в фоне» выключаются.", value(AyGrammSettings.keepAliveBatteryKey)))
        entries.append(.sectionHeader(200, "АККАУНТЫ"))
        entries.append(.toggle(210, AyGrammSettings.unlimitedAccountsKey, "Аккаунты без лимита", "До 1000 аккаунтов вместо 3. С 15–20 аккаунтами iOS может закрывать приложение.", value(AyGrammSettings.unlimitedAccountsKey)))
        entries.append(.sectionHeader(300, "ПРОФИЛЬ"))
        entries.append(.toggle(310, AyGrammSettings.decorationsKey, "Украшения профиля", "Подарки и NFT из каталога в своём профиле, с лентой AyGramm. Видны только на этом телефоне.", value(AyGrammSettings.decorationsKey)))
        entries.append(.decorations)
        entries.append(.toggle(312, AyGrammSettings.showIdKey, "ID в профиле", "ID пользователя в Telegram. Нажатие копирует его.", value(AyGrammSettings.showIdKey)))
        entries.append(.toggle(313, AyGrammSettings.streamerKey, "Режим стримера", "Номера телефонов скрыты в профилях и в настройках.", value(AyGrammSettings.streamerKey)))
        entries.append(.sectionHeader(400, "СООБЩЕНИЯ"))
        entries.append(.toggle(410, AyGrammSettings.tokensKey, "Подстановки", "{дата}, {время} и {день} заменяются при отправке.", value(AyGrammSettings.tokensKey)))
        entries.append(.font(AyGrammFonts.styles[fontIndex].name))
        entries.append(.toggle(412, AyGrammSettings.readAloudKey, "Прочитать вслух", "Пункт в меню сообщения: голос iOS читает текст.", value(AyGrammSettings.readAloudKey)))
        entries.append(.toggle(413, AyGrammSettings.secondsKey, "Секунды во времени", "Время сообщений с секундами: 14:05:37.", value(AyGrammSettings.secondsKey)))
        entries.append(.voice(AyGrammVoice.effects[voiceIndex].0))
        entries.append(.sectionHeader(500, "ИНСТРУМЕНТЫ"))
        entries.append(.profiles)
        entries.append(.log(logCount))
        entries.append(.crashLog(hasCrash))
        entries.append(.backupExport)
        entries.append(.backupRestore)
        entries.append(.footer)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Встроенные плагины"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: false)
        return (controllerState, (listState, arguments))
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
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: ayGrammIcon("checkmark.circle.fill", AyGrammColor.green), title: "Включить «\(name)»", label: saved ? "" : "не сохранён", sectionId: self.section, style: .blocks, action: {
                action(name, true)
            })
        case let .save(_, name):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: ayGrammIcon("square.and.arrow.down.fill", AyGrammColor.blue), title: "Сохранить текущие как «\(name)»", label: "", sectionId: self.section, style: .blocks, action: {
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
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: ayGrammIcon("trash.fill", AyGrammColor.red), title: "Очистить журнал", label: "", sectionId: self.section, style: .blocks, action: {
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

// MARK: - Шрифт сообщений

// Раздел 0: «Без шрифта», раздел 1: форматирование Telegram, дальше по разделу на каждое начертание.
// stableId = раздел × 100 + номер строки, поэтому порядок строк совпадает с порядком разделов.
private enum AyGrammFontsEntry: ItemListNodeEntry {
    case sectionHeader(Int32, String)
    case style(Int32, Int32, String, String, Bool)
    case footer(Int32)

    var section: ItemListSectionId {
        return self.stableId / 100
    }

    var stableId: Int32 {
        switch self {
        case let .sectionHeader(id, _):
            return id
        case let .style(id, _, _, _, _):
            return id
        case let .footer(id):
            return id
        }
    }

    static func <(lhs: AyGrammFontsEntry, rhs: AyGrammFontsEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let select = arguments as! (Int) -> Void
        switch self {
        case let .sectionHeader(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .style(_, index, title, subtitle, isSelected):
            return ItemListCheckboxItem(presentationData: presentationData, systemStyle: .glass, title: title, subtitle: subtitle, style: .right, checked: isSelected, zeroSeparatorInsets: false, sectionId: self.section, action: {
                select(Int(index))
            })
        case .footer:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Шрифт применяется к каждому отправленному сообщению. Начертания Unicode меняют латиницу и цифры, черты, точки и сердечки добавляются и к русским буквам. Ссылки, @имена, #теги и /команды не меняются. Сообщения с вашим форматированием уходят как есть."), sectionId: self.section)
        }
    }
}

private func ayGrammFontsController(context: AccountContext, selected: @escaping (Int) -> Void) -> ViewController {
    let selectedPromise = ValuePromise<Int>(AyGrammFonts.selectedIndex, ignoreRepeated: true)
    let select: (Int) -> Void = { index in
        AyGrammFonts.selectedIndex = index
        selectedPromise.set(index)
        selected(index)
    }
    let samples: [String] = (0 ..< AyGrammFonts.styles.count).map { AyGrammFonts.sample($0) }

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        selectedPromise.get()
    )
    |> map { presentationData, selectedIndex -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var entries: [AyGrammFontsEntry] = []
        let sections = AyGrammFonts.menuSections
        for (sectionIndex, section) in sections.enumerated() {
            let base = Int32(sectionIndex) * 100
            entries.append(.sectionHeader(base, section.0.uppercased()))
            for (row, item) in section.1.enumerated() {
                let title: String
                if sectionIndex <= 1 {
                    title = AyGrammFonts.styles[item.0].name.replacingOccurrences(of: " (Telegram)", with: "")
                } else {
                    title = samples[item.0]
                }
                entries.append(.style(base + 1 + Int32(row), Int32(item.0), title, item.1, item.0 == selectedIndex))
            }
            if sectionIndex == sections.count - 1 {
                entries.append(.footer(base + 99))
            }
        }
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Шрифт сообщений"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: false)
        return (controllerState, (listState, select))
    }

    return ItemListController(context: context, state: signal)
}

// MARK: - Изменение голоса

private enum AyGrammVoiceEntry: ItemListNodeEntry {
    case header
    case effect(Int32, String, String, Bool)
    case footer

    var section: ItemListSectionId {
        return 0
    }

    var stableId: Int32 {
        switch self {
        case .header:
            return 0
        case let .effect(index, _, _, _):
            return 1 + index
        case .footer:
            return 100
        }
    }

    static func <(lhs: AyGrammVoiceEntry, rhs: AyGrammVoiceEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let select = arguments as! (Int) -> Void
        switch self {
        case .header:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "ЭФФЕКТ", sectionId: self.section)
        case let .effect(index, title, subtitle, isSelected):
            return ItemListCheckboxItem(presentationData: presentationData, systemStyle: .glass, title: title, subtitle: subtitle, style: .right, checked: isSelected, zeroSeparatorInsets: false, sectionId: self.section, action: {
                select(Int(index))
            })
        case .footer:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Голос меняется при записи голосового сообщения. Собеседник слышит уже изменённый голос, прослушивание перед отправкой звучит так же. Видеосообщения в кружках не меняются."), sectionId: self.section)
        }
    }
}

private func ayGrammVoiceController(context: AccountContext, selected: @escaping (Int) -> Void) -> ViewController {
    let selectedPromise = ValuePromise<Int>(AyGrammVoice.selectedIndex, ignoreRepeated: true)
    let select: (Int) -> Void = { index in
        AyGrammVoice.selectedIndex = index
        selectedPromise.set(index)
        selected(index)
    }

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        selectedPromise.get()
    )
    |> map { presentationData, selectedIndex -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var entries: [AyGrammVoiceEntry] = [.header]
        for (index, effect) in AyGrammVoice.effects.enumerated() {
            entries.append(.effect(Int32(index), effect.0, effect.1, index == selectedIndex))
        }
        entries.append(.footer)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Изменение голоса"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: false)
        return (controllerState, (listState, select))
    }

    return ItemListController(context: context, state: signal)
}
