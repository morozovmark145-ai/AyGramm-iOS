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
// Разделы экрана: связь, аккаунты, профиль, сообщения, чаты, голос, инструменты, автоответ, отправка.

private final class AyGrammBuiltinArguments {
    let toggle: (String, Bool) -> Void
    let openDecorations: () -> Void
    let openProfiles: () -> Void
    let openLog: () -> Void
    let openFonts: () -> Void
    let openVoice: () -> Void
    let openFilters: () -> Void
    let openCrashLog: () -> Void
    let exportBackup: () -> Void
    let restoreBackup: () -> Void
    let openAutoReply: () -> Void
    let chooseBomb: () -> Void
    let chooseLanguage: () -> Void
    let setPassword: () -> Void
    let openSnippets: () -> Void

    init(toggle: @escaping (String, Bool) -> Void, openDecorations: @escaping () -> Void, openProfiles: @escaping () -> Void, openLog: @escaping () -> Void, openFonts: @escaping () -> Void, openVoice: @escaping () -> Void, openCrashLog: @escaping () -> Void, exportBackup: @escaping () -> Void, restoreBackup: @escaping () -> Void, openFilters: @escaping () -> Void, openAutoReply: @escaping () -> Void, chooseBomb: @escaping () -> Void, chooseLanguage: @escaping () -> Void, setPassword: @escaping () -> Void, openSnippets: @escaping () -> Void) {
        self.toggle = toggle
        self.openSnippets = openSnippets
        self.openAutoReply = openAutoReply
        self.chooseBomb = chooseBomb
        self.chooseLanguage = chooseLanguage
        self.setPassword = setPassword
        self.openFonts = openFonts
        self.openVoice = openVoice
        self.openFilters = openFilters
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
    case filters(Int)
    case profiles
    case log(Int)
    case crashLog(Bool)
    case backupExport
    case backupRestore
    case autoReply(String)
    case bombSeconds(String)
    case translateLanguage(String)
    case cipherPassword(Bool)
    case stat(Int32, String, String, String, UInt32)
    case snippets(Int)
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
            return 610
        case .filters:
            return 511
        case .profiles:
            return 710
        case .log:
            return 711
        case .crashLog:
            return 712
        case .backupExport:
            return 713
        case .backupRestore:
            return 714
        case .autoReply:
            return 810
        case .bombSeconds:
            return 911
        case .translateLanguage:
            return 913
        case .cipherPassword:
            return 915
        case let .stat(id, _, _, _, _):
            return id
        case .snippets:
            return 417
        case .footer:
            return 1999
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
        case let .filters(count):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: ayGrammIcon("list.bullet", AyGrammColor.red), title: "Слова и скрытые люди", label: "\(count)", sectionId: self.section, style: .blocks, action: {
                arguments.openFilters()
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
        case let .autoReply(status):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: ayGrammIcon("bubble.left.and.bubble.right.fill", AyGrammColor.green), title: "Автоответ", label: status, sectionId: self.section, style: .blocks, action: {
                arguments.openAutoReply()
            })
        case let .bombSeconds(title):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: ayGrammIcon("timer", AyGrammColor.orange), title: "Время бомбы", label: title, sectionId: self.section, style: .blocks, action: {
                arguments.chooseBomb()
            })
        case let .translateLanguage(name):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: ayGrammIcon("character.bubble.fill", AyGrammColor.blue), title: "Язык перевода", label: name, sectionId: self.section, style: .blocks, action: {
                arguments.chooseLanguage()
            })
        case let .cipherPassword(isSet):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: ayGrammIcon("key.fill", AyGrammColor.yellow), title: "Пароль шифровки", label: isSet ? "задан" : "не задан", sectionId: self.section, style: .blocks, action: {
                arguments.setPassword()
            })
        case let .snippets(count):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: ayGrammIcon("text.badge.plus", AyGrammColor.teal), title: "Сокращения", label: "\(count)", sectionId: self.section, style: .blocks, action: {
                arguments.openSnippets()
            })
        case let .stat(_, title, label, symbol, color):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: ayGrammIcon(symbol, color), title: title, label: label, sectionId: self.section, style: .blocks, disclosureStyle: .none, action: nil)
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

// sections: номера разделов (stableId / 100) для экрана одной категории из меню AyGramm, nil показывает все.
// changed сообщает меню AyGramm, что подписи категорий надо обновить.
func ayGrammBuiltinController(context: AccountContext, sections: Set<Int32>? = nil, title: String = "Встроенные плагины", changed: (() -> Void)? = nil) -> ViewController {
    let valuesPromise = ValuePromise<[String: Bool]>(ayGrammBuiltinValues(), ignoreRepeated: true)
    let logCountPromise = ValuePromise<Int>(AyGrammPluginLog.entries().count, ignoreRepeated: true)
    let fontPromise = ValuePromise<Int>(AyGrammFonts.selectedIndex, ignoreRepeated: true)
    let voicePromise = ValuePromise<Int>(AyGrammVoice.selectedIndex, ignoreRepeated: true)
    let crashPromise = ValuePromise<Bool>(AyGrammCrashLog.lastReport != nil, ignoreRepeated: true)
    // Подписи автоответа, бомбы, языка и пароля перерисовываются после каждого изменения.
    let extraPromise = ValuePromise<Int>(0, ignoreRepeated: false)
    var extraVersion = 0
    let refreshExtra: () -> Void = {
        extraVersion += 1
        extraPromise.set(extraVersion)
    }
    var pushControllerImpl: ((ViewController) -> Void)?
    var presentControllerImpl: ((ViewController) -> Void)?
    let showMessage: (String) -> Void = { text in
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        presentControllerImpl?(textAlertController(context: context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]))
    }

    let arguments = AyGrammBuiltinArguments(toggle: { key, value in
        AyGrammSettings.setValue(key, value)
        valuesPromise.set(ayGrammBuiltinValues())
        changed?()
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
            changed?()
        }))
    }, openVoice: {
        pushControllerImpl?(ayGrammVoiceController(context: context, selected: { index in
            voicePromise.set(index)
            changed?()
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
    }, openFilters: {
        pushControllerImpl?(ayGrammFiltersController(context: context))
    }, openAutoReply: {
        pushControllerImpl?(ayGrammAutoReplyController(context: context, changed: {
            valuesPromise.set(ayGrammBuiltinValues())
            refreshExtra()
            changed?()
        }))
    }, chooseBomb: {
        let options = AyGrammBomb.options
        pushControllerImpl?(ayGrammOptionsController(context: context, title: "Время бомбы", header: "УДАЛИТЬ У ВСЕХ ЧЕРЕЗ", options: options.map { AyGrammBomb.title($0) }, selected: options.firstIndex(of: AyGrammBomb.seconds) ?? 2, footer: "Таймер идёт с момента отправки. Если AyGramm закрыт, сообщение удалится при следующем запуске. Клиенты с сохранением удалённых сообщений его сохранят.", select: { index in
            AyGrammBomb.seconds = options[index]
            refreshExtra()
        }))
    }, chooseLanguage: {
        let languages = AyGrammTranslate.languages
        let titles: [String] = languages.map { item -> String in
            return item.1.prefix(1).uppercased() + item.1.dropFirst()
        }
        pushControllerImpl?(ayGrammOptionsController(context: context, title: "Язык перевода", header: "ПЕРЕВОДИТЬ НА", options: titles, selected: languages.firstIndex(where: { item in item.0 == AyGrammTranslate.language }) ?? 0, footer: "Перевод делает переводчик Telegram. Форматирование сохраняется.", select: { index in
            AyGrammTranslate.language = languages[index].0
            refreshExtra()
        }))
    }, setPassword: {
        let alert = UIAlertController(title: "Пароль шифровки", message: "Сообщения расшифрует только AyGramm с тем же паролем. Сообщите пароль друзьям лично, не в этом же чате.", preferredStyle: .alert)
        alert.addTextField(configurationHandler: { field in
            field.text = AyGrammCipher.password
            field.placeholder = "Пароль"
            field.autocorrectionType = .no
            field.autocapitalizationType = .none
        })
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel, handler: nil))
        if !AyGrammCipher.password.isEmpty {
            alert.addAction(UIAlertAction(title: "Удалить пароль", style: .destructive, handler: { _ in
                AyGrammCipher.password = ""
                refreshExtra()
            }))
        }
        alert.addAction(UIAlertAction(title: "Сохранить", style: .default, handler: { [weak alert] _ in
            AyGrammCipher.password = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            refreshExtra()
        }))
        context.sharedContext.mainWindow?.presentNative(alert)
    }, openSnippets: {
        pushControllerImpl?(ayGrammSnippetsController(context: context, changed: {
            refreshExtra()
        }))
    })

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        valuesPromise.get(),
        logCountPromise.get(),
        fontPromise.get(),
        voicePromise.get(),
        crashPromise.get(),
        extraPromise.get()
    )
    |> map { presentationData, values, logCount, fontIndex, voiceIndex, hasCrash, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
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
        entries.append(.toggle(314, AyGrammSettings.accountAgeKey, "Дата регистрации", "Примерная дата создания аккаунта в профиле, по номеру ID.", value(AyGrammSettings.accountAgeKey)))
        entries.append(.toggle(315, AyGrammSettings.mutualKey, "Взаимный контакт", "В профиле контакта видно, сохранил ли он вас в ответ.", value(AyGrammSettings.mutualKey)))
        entries.append(.sectionHeader(400, "СООБЩЕНИЯ"))
        entries.append(.toggle(410, AyGrammSettings.tokensKey, "Подстановки", "{дата}, {время} и {день} заменяются при отправке.", value(AyGrammSettings.tokensKey)))
        entries.append(.font(AyGrammFonts.styles[fontIndex].name))
        entries.append(.toggle(412, AyGrammSettings.fontButtonKey, "Кнопка шрифта", "Долгое нажатие на «Отправить»: включить или выключить шрифт сообщений.", value(AyGrammSettings.fontButtonKey)))
        entries.append(.toggle(413, AyGrammSettings.fontLiveKey, "Шрифт при наборе", "Слово меняет шрифт сразу после пробела, ещё до отправки. Работает для начертаний без украшений и рамок.", value(AyGrammSettings.fontLiveKey)))
        entries.append(.toggle(415, AyGrammSettings.secondsKey, "Секунды во времени", "Время сообщений с секундами: 14:05:37.", value(AyGrammSettings.secondsKey)))
        entries.append(.toggle(416, AyGrammSettings.readAloudKey, "Прочитать вслух", "Пункт в меню сообщения: голос iOS читает текст.", value(AyGrammSettings.readAloudKey)))
        entries.append(.snippets(AyGrammSnippets.all.count))
        entries.append(.sectionHeader(500, "ЧАТЫ"))
        entries.append(.toggle(510, AyGrammSettings.filtersKey, "Фильтры в группах", "Скрывает сообщения со словами из списка и сообщения выбранных людей.", value(AyGrammSettings.filtersKey)))
        entries.append(.filters(AyGrammFilters.words.count + AyGrammFilters.authors.count))
        entries.append(.toggle(512, AyGrammSettings.exportKey, "Экспорт чата", "Пункт в меню сообщения: скачанные сообщения чата в файл .txt. Чаты с запретом копирования не экспортируются.", value(AyGrammSettings.exportKey)))
        entries.append(.toggle(513, AyGrammSettings.chatToolsKey, "Меню AyGramm в сообщении", "Статистика чата, первое сообщение, скриншот, кружок из галереи, «Стереть мои сообщения».", value(AyGrammSettings.chatToolsKey)))
        entries.append(.sectionHeader(600, "ГОЛОС"))
        entries.append(.voice(AyGrammVoice.effects[voiceIndex].0))
        entries.append(.toggle(611, AyGrammSettings.voiceSendKey, "Отправить голосом", "Долгое нажатие на «Отправить»: голос iOS читает текст, собеседник получает голосовое с эффектом выше.", value(AyGrammSettings.voiceSendKey)))
        entries.append(.sectionHeader(700, "ИНСТРУМЕНТЫ"))
        entries.append(.profiles)
        entries.append(.log(logCount))
        entries.append(.crashLog(hasCrash))
        entries.append(.backupExport)
        entries.append(.backupRestore)
        entries.append(.stat(715, "Сегодня в AyGramm", AyGrammScreenTime.todayTitle, "hourglass", AyGrammColor.teal))
        entries.append(.stat(716, "За 7 дней", AyGrammScreenTime.weekTitle, "chart.bar.fill", AyGrammColor.blue))
        entries.append(.sectionHeader(800, "АВТООТВЕТ"))
        entries.append(.autoReply(AyGrammAutoReply.statusTitle))
        entries.append(.sectionHeader(900, "ОТПРАВКА"))
        entries.append(.toggle(910, AyGrammSettings.bombKey, "Сообщение-бомба", "Долгое нажатие на «Отправить»: сообщение удалится у всех через выбранное время.", value(AyGrammSettings.bombKey)))
        entries.append(.bombSeconds(AyGrammBomb.secondsTitle))
        entries.append(.toggle(912, AyGrammSettings.translateKey, "Перевод при отправке", "Долгое нажатие на «Отправить»: текст уходит на выбранном языке.", value(AyGrammSettings.translateKey)))
        entries.append(.translateLanguage(AyGrammTranslate.languageName))
        entries.append(.toggle(914, AyGrammSettings.cipherKey, "Шифровка", "Долгое нажатие на «Отправить»: текст уходит зашифрованным, прочитает только AyGramm с тем же паролем.", value(AyGrammSettings.cipherKey)))
        entries.append(.cipherPassword(!AyGrammCipher.password.isEmpty))
        if let sections = sections {
            entries = entries.filter { sections.contains($0.stableId / 100) }
        } else {
            entries.append(.footer)
        }
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
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
            return ItemListTextItem(presentationData: presentationData, text: .plain("Шрифт применяется к каждому отправленному сообщению. Все начертания работают и с русским текстом: русские буквы заменяются похожими буквами того же начертания, в жирных и курсивных стилях Г, Д, Л, П, Ф становятся греческими. Черты, точки и сердечки добавляются ко всем буквам. Ссылки, @имена, #теги и /команды не меняются. Сообщения с вашим форматированием уходят как есть."), sectionId: self.section)
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
            return ItemListTextItem(presentationData: presentationData, text: .plain("Нажмите на эффект: AyGramm прочитает фразу-образец с ним. Голос меняется при записи голосового сообщения и в «Отправить голосом». Собеседник слышит уже изменённый голос. Видеосообщения в кружках не меняются."), sectionId: self.section)
        }
    }
}

private func ayGrammVoiceController(context: AccountContext, selected: @escaping (Int) -> Void) -> ViewController {
    let selectedPromise = ValuePromise<Int>(AyGrammVoice.selectedIndex, ignoreRepeated: true)
    let select: (Int) -> Void = { index in
        AyGrammVoice.selectedIndex = index
        selectedPromise.set(index)
        selected(index)
        AyGrammVoice.previewPlayer?(index)
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

// MARK: - Фильтры в группах

private final class AyGrammFiltersArguments {
    let addWords: () -> Void
    let removeWord: (String) -> Void
    let showAuthor: (Int64) -> Void

    init(addWords: @escaping () -> Void, removeWord: @escaping (String) -> Void, showAuthor: @escaping (Int64) -> Void) {
        self.addWords = addWords
        self.removeWord = removeWord
        self.showAuthor = showAuthor
    }
}

private enum AyGrammFiltersEntry: ItemListNodeEntry {
    case wordsHeader
    case word(Int32, String)
    case addWords
    case authorsHeader
    case author(Int32, Int64, String)
    case noAuthors
    case footer

    var section: ItemListSectionId {
        switch self {
        case .wordsHeader, .word, .addWords:
            return 0
        case .authorsHeader, .author, .noAuthors, .footer:
            return 1
        }
    }

    var stableId: Int32 {
        switch self {
        case .wordsHeader:
            return 0
        case let .word(index, _):
            return 1 + index
        case .addWords:
            return 99999
        case .authorsHeader:
            return 100000
        case let .author(index, _, _):
            return 100001 + index
        case .noAuthors:
            return 199998
        case .footer:
            return 199999
        }
    }

    static func <(lhs: AyGrammFiltersEntry, rhs: AyGrammFiltersEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! AyGrammFiltersArguments
        switch self {
        case .wordsHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "СЛОВА", sectionId: self.section)
        case let .word(_, word):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: ayGrammIcon("textformat.abc", AyGrammColor.gray), title: word, label: "удалить", sectionId: self.section, style: .blocks, action: {
                arguments.removeWord(word)
            })
        case .addWords:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: ayGrammIcon("plus", AyGrammColor.green), title: "Добавить слова из буфера обмена", label: "", sectionId: self.section, style: .blocks, action: {
                arguments.addWords()
            })
        case .authorsHeader:
            return ItemListSectionHeaderItem(presentationData: presentationData, text: "СКРЫТЫЕ ЛЮДИ", sectionId: self.section)
        case let .author(_, id, name):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: ayGrammIcon("person.fill.xmark", AyGrammColor.red), title: name, label: "показать", sectionId: self.section, style: .blocks, action: {
                arguments.showAuthor(id)
            })
        case .noAuthors:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Пока никого. Нажмите на сообщение в группе и выберите «Скрывать сообщения автора»."), sectionId: self.section)
        case .footer:
            return ItemListTextItem(presentationData: presentationData, text: .plain("Сообщения со словами из списка и сообщения скрытых людей не показываются в группах и каналах. Личные чаты, свои сообщения и реклама Telegram не фильтруются."), sectionId: self.section)
        }
    }
}

private func ayGrammFiltersController(context: AccountContext) -> ViewController {
    let updatePromise = ValuePromise<Int>(0, ignoreRepeated: false)
    var counter = 0
    var presentControllerImpl: ((ViewController) -> Void)?
    let refresh: () -> Void = {
        counter += 1
        updatePromise.set(counter)
    }

    let arguments = AyGrammFiltersArguments(addWords: {
        let presentationData = context.sharedContext.currentPresentationData.with { $0 }
        let added = AyGrammFilters.addWords(from: UIPasteboard.general.string ?? "")
        let text = added == 0 ? "Скопируйте слова через запятую или с новой строки, потом нажмите ещё раз." : "Добавлено слов: \(added)."
        presentControllerImpl?(textAlertController(context: context, title: nil, text: text, actions: [TextAlertAction(type: .defaultAction, title: presentationData.strings.Common_OK, action: {})]))
        refresh()
    }, removeWord: { word in
        AyGrammFilters.removeWord(word)
        refresh()
    }, showAuthor: { id in
        AyGrammFilters.showAuthor(id: id)
        refresh()
    })

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        updatePromise.get()
    )
    |> map { presentationData, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var entries: [AyGrammFiltersEntry] = [.wordsHeader]
        for (index, word) in AyGrammFilters.words.prefix(9000).enumerated() {
            entries.append(.word(Int32(index), word))
        }
        entries.append(.addWords)
        entries.append(.authorsHeader)
        let authors = AyGrammFilters.authors
        if authors.isEmpty {
            entries.append(.noAuthors)
        }
        for (index, author) in authors.prefix(9000).enumerated() {
            entries.append(.author(Int32(index), author.0, author.1))
        }
        entries.append(.footer)
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Фильтры в группах"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: false)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    presentControllerImpl = { [weak controller] c in
        controller?.present(c, in: .window(.root))
    }
    return controller
}

// MARK: - Выбор из списка

private enum AyGrammOptionEntry: ItemListNodeEntry {
    case header(String)
    case option(Int32, String, Bool)
    case footer(String)

    var section: ItemListSectionId {
        return 0
    }

    var stableId: Int32 {
        switch self {
        case .header:
            return 0
        case let .option(index, _, _):
            return 1 + index
        case .footer:
            return 100000
        }
    }

    static func <(lhs: AyGrammOptionEntry, rhs: AyGrammOptionEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let select = arguments as! (Int) -> Void
        switch self {
        case let .header(text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .option(index, title, isSelected):
            return ItemListCheckboxItem(presentationData: presentationData, systemStyle: .glass, title: title, style: .right, checked: isSelected, zeroSeparatorInsets: false, sectionId: self.section, action: {
                select(Int(index))
            })
        case let .footer(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

// Экран с галочками: выбор одного варианта из списка, выбор сохраняется сразу.
func ayGrammOptionsController(context: AccountContext, title: String, header: String, options: [String], selected: Int, footer: String, select: @escaping (Int) -> Void) -> ViewController {
    let selectedPromise = ValuePromise<Int>(selected, ignoreRepeated: true)
    let choose: (Int) -> Void = { index in
        selectedPromise.set(index)
        select(index)
    }
    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        selectedPromise.get()
    )
    |> map { presentationData, current -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var entries: [AyGrammOptionEntry] = [.header(header)]
        for (index, option) in options.enumerated() {
            entries.append(.option(Int32(index), option, index == current))
        }
        if !footer.isEmpty {
            entries.append(.footer(footer))
        }
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text(title), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: false)
        return (controllerState, (listState, choose))
    }
    return ItemListController(context: context, state: signal)
}

// MARK: - Автоответ

private final class AyGrammAutoReplyArguments {
    let toggle: (String, Bool) -> Void
    let action: (Int) -> Void
    let removeRule: (String) -> Void

    init(toggle: @escaping (String, Bool) -> Void, action: @escaping (Int) -> Void, removeRule: @escaping (String) -> Void) {
        self.toggle = toggle
        self.action = action
        self.removeRule = removeRule
    }
}

// Номера действий для строк со стрелкой.
private enum AyGrammAutoReplyAction {
    static let text = 0
    static let schedule = 1
    static let audience = 2
    static let cooldown = 3
    static let delay = 4
    static let excluded = 5
    static let addRule = 6
    static let clearLog = 7
    static let templates = 8
}

// stableId / 100 = номер раздела.
private enum AyGrammAutoReplyEntry: ItemListNodeEntry {
    case header(Int32, String)
    case toggle(Int32, String, String, String, Bool)
    case action(Int32, String, String, String, UInt32, Int)
    case rule(Int32, String, String)
    case info(Int32, String)

    var section: ItemListSectionId {
        return self.stableId / 100
    }

    var stableId: Int32 {
        switch self {
        case let .header(id, _):
            return id
        case let .toggle(id, _, _, _, _):
            return id
        case let .action(id, _, _, _, _, _):
            return id
        case let .rule(id, _, _):
            return id
        case let .info(id, _):
            return id
        }
    }

    static func <(lhs: AyGrammAutoReplyEntry, rhs: AyGrammAutoReplyEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! AyGrammAutoReplyArguments
        switch self {
        case let .header(_, text):
            return ItemListSectionHeaderItem(presentationData: presentationData, text: text, sectionId: self.section)
        case let .toggle(_, key, title, text, value):
            return ItemListSwitchItem(presentationData: presentationData, systemStyle: .glass, icon: ayGrammKeyIcon(key), title: title, text: text, value: value, sectionId: self.section, style: .blocks, updated: { value in
                arguments.toggle(key, value)
            })
        case let .action(_, title, label, symbol, color, kind):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: ayGrammIcon(symbol, color), title: title, label: label, sectionId: self.section, style: .blocks, action: {
                arguments.action(kind)
            })
        case let .rule(_, keyword, answer):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: ayGrammIcon("text.bubble.fill", AyGrammColor.teal), title: "«\(keyword)»", label: answer, sectionId: self.section, style: .blocks, action: {
                arguments.removeRule(keyword)
            })
        case let .info(_, text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

func ayGrammAutoReplyController(context: AccountContext, changed: @escaping () -> Void) -> ViewController {
    let versionPromise = ValuePromise<Int>(0, ignoreRepeated: false)
    var version = 0
    let refresh: () -> Void = {
        version += 1
        versionPromise.set(version)
        changed()
    }
    var pushControllerImpl: ((ViewController) -> Void)?
    let presentAlert: (UIAlertController) -> Void = { alert in
        context.sharedContext.mainWindow?.presentNative(alert)
    }

    let arguments = AyGrammAutoReplyArguments(toggle: { key, value in
        AyGrammSettings.setValue(key, value)
        refresh()
    }, action: { kind in
        switch kind {
        case AyGrammAutoReplyAction.text:
            let alert = UIAlertController(title: "Текст автоответа", message: "Подстановки: {имя}, {время}, {дата}, {до} (конец расписания, например 08:00). Пустой текст вернёт стандартный.", preferredStyle: .alert)
            alert.addTextField(configurationHandler: { field in
                field.text = AyGrammAutoReply.text
                field.clearButtonMode = .whileEditing
            })
            alert.addAction(UIAlertAction(title: "Отмена", style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: "Сохранить", style: .default, handler: { [weak alert] _ in
                let value = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                AyGrammAutoReply.text = value.isEmpty ? AyGrammAutoReply.defaultText : value
                refresh()
            }))
            presentAlert(alert)
        case AyGrammAutoReplyAction.schedule:
            let alert = UIAlertController(title: "Время автоответа", message: "Часы от 0 до 23. Например, с 23 до 8: автоответ работает ночью.", preferredStyle: .alert)
            alert.addTextField(configurationHandler: { field in
                field.text = "\(AyGrammAutoReply.fromHour)"
                field.placeholder = "С какого часа"
                field.keyboardType = .numberPad
            })
            alert.addTextField(configurationHandler: { field in
                field.text = "\(AyGrammAutoReply.toHour)"
                field.placeholder = "До какого часа"
                field.keyboardType = .numberPad
            })
            alert.addAction(UIAlertAction(title: "Отмена", style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: "Сохранить", style: .default, handler: { [weak alert] _ in
                let fields = alert?.textFields ?? []
                if fields.count == 2, let from = Int(fields[0].text ?? ""), let to = Int(fields[1].text ?? ""), from >= 0 && from < 24 && to >= 0 && to < 24 {
                    AyGrammAutoReply.fromHour = from
                    AyGrammAutoReply.toHour = to
                    AyGrammSettings.setValue(AyGrammSettings.autoReplyScheduleKey, true)
                }
                refresh()
            }))
            presentAlert(alert)
        case AyGrammAutoReplyAction.audience:
            pushControllerImpl?(ayGrammOptionsController(context: context, title: "Кому отвечать", header: "АВТООТВЕТ ПОЛУЧАТ", options: AyGrammAutoReply.audiences, selected: AyGrammAutoReply.audience, footer: "Контакты: люди из вашей телефонной книги Telegram. Незнакомые: все остальные.", select: { index in
                AyGrammAutoReply.audience = index
                refresh()
            }))
        case AyGrammAutoReplyAction.cooldown:
            let options = AyGrammAutoReply.cooldowns
            pushControllerImpl?(ayGrammOptionsController(context: context, title: "Как часто", header: "ОДНОМУ ЧЕЛОВЕКУ НЕ ЧАЩЕ", options: options.map { $0.1 }, selected: options.firstIndex(where: { $0.0 == AyGrammAutoReply.cooldownMinutes }) ?? 1, footer: "Если человек пишет много сообщений подряд, автоответ уходит один раз за выбранный срок. Умные ответы на слова приходят не чаще раза в 2 минуты.", select: { index in
                AyGrammAutoReply.cooldownMinutes = options[index].0
                refresh()
            }))
        case AyGrammAutoReplyAction.delay:
            let options = AyGrammAutoReply.delays
            pushControllerImpl?(ayGrammOptionsController(context: context, title: "Задержка", header: "ОТВЕЧАТЬ", options: options.map { $0.1 }, selected: options.firstIndex(where: { $0.0 == AyGrammAutoReply.delaySeconds }) ?? 0, footer: "Если за это время вы ответите сами или откроете чат, автоответ не уйдёт.", select: { index in
                AyGrammAutoReply.delaySeconds = options[index].0
                refresh()
            }))
        case AyGrammAutoReplyAction.excluded:
            let count = AyGrammAutoReply.excluded.count
            let alert = UIAlertController(title: "Исключения", message: count == 0 ? "Исключений нет. Чтобы автоответ не отвечал человеку, нажмите на его сообщение и выберите AyGramm → «Автоответ: не отвечать ему»." : "Автоответ не отвечает людям: \(count). Добавить человека: нажмите на его сообщение и выберите AyGramm → «Автоответ: не отвечать ему».", preferredStyle: .alert)
            if count > 0 {
                alert.addAction(UIAlertAction(title: "Очистить список", style: .destructive, handler: { _ in
                    AyGrammAutoReply.excluded = Set()
                    refresh()
                }))
            }
            alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
            presentAlert(alert)
        case AyGrammAutoReplyAction.addRule:
            let alert = UIAlertController(title: "Умный ответ", message: "Если сообщение содержит слово, автоответ отправит ваш ответ. Пример: слово «цена», ответ «Прайс в закреплённом сообщении».", preferredStyle: .alert)
            alert.addTextField(configurationHandler: { field in
                field.placeholder = "Слово или фраза"
            })
            alert.addTextField(configurationHandler: { field in
                field.placeholder = "Ответ"
            })
            alert.addAction(UIAlertAction(title: "Отмена", style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: "Добавить", style: .default, handler: { [weak alert] _ in
                let fields = alert?.textFields ?? []
                if fields.count == 2 {
                    let _ = AyGrammAutoReply.addRule(keyword: fields[0].text ?? "", answer: fields[1].text ?? "")
                }
                refresh()
            }))
            presentAlert(alert)
        case AyGrammAutoReplyAction.clearLog:
            AyGrammAutoReply.clearLog()
            refresh()
        case AyGrammAutoReplyAction.templates:
            let templates = AyGrammAutoReply.templates
            pushControllerImpl?(ayGrammOptionsController(context: context, title: "Шаблоны", header: "ГОТОВЫЙ ТЕКСТ", options: templates.map { $0.0 }, selected: templates.firstIndex(where: { $0.1 == AyGrammAutoReply.text }) ?? -1, footer: "Шаблон заменяет текст ответа. Потом его можно поправить в «Текст ответа».", select: { index in
                AyGrammAutoReply.text = templates[index].1
                refresh()
            }))
        default:
            break
        }
    }, removeRule: { keyword in
        let alert = UIAlertController(title: "Удалить правило «\(keyword)»?", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Удалить", style: .destructive, handler: { _ in
            AyGrammAutoReply.removeRule(keyword: keyword)
            refresh()
        }))
        presentAlert(alert)
    })

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        versionPromise.get()
    )
    |> map { presentationData, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        func value(_ key: String) -> Bool {
            return AyGrammSettings.storedValue(key)
        }
        var entries: [AyGrammAutoReplyEntry] = []
        entries.append(.header(0, "АВТООТВЕТ"))
        entries.append(.toggle(1, AyGrammSettings.autoReplyKey, "Автоответ", "Отвечает людям в личных чатах, пока вас нет. Сейчас: \(AyGrammAutoReply.statusTitle).", value(AyGrammSettings.autoReplyKey)))
        entries.append(.action(2, "Текст ответа", String(AyGrammAutoReply.text.prefix(24)), "text.quote", AyGrammColor.blue, AyGrammAutoReplyAction.text))
        entries.append(.action(3, "Шаблоны", "\(AyGrammAutoReply.templates.count) готовых", "square.stack.fill", AyGrammColor.orange, AyGrammAutoReplyAction.templates))
        entries.append(.toggle(4, AyGrammSettings.autoReplyMarkKey, "Метка 🤖", "Собеседник видит, что ответ автоматический. На сообщения с 🤖 автоответ не отвечает, поэтому два автоответа не спорят друг с другом.", value(AyGrammSettings.autoReplyMarkKey)))
        entries.append(.header(100, "КОГДА"))
        entries.append(.toggle(101, AyGrammSettings.autoReplyBackgroundKey, "Только когда AyGramm свёрнут", "Пока приложение открыто, автоответ молчит.", value(AyGrammSettings.autoReplyBackgroundKey)))
        entries.append(.toggle(102, AyGrammSettings.autoReplyScheduleKey, "По расписанию", "Автоответ работает только в выбранные часы.", value(AyGrammSettings.autoReplyScheduleKey)))
        entries.append(.action(103, "Часы работы", AyGrammAutoReply.scheduleTitle, "clock.fill", AyGrammColor.orange, AyGrammAutoReplyAction.schedule))
        entries.append(.header(200, "КОМУ И КАК ЧАСТО"))
        entries.append(.action(201, "Кому отвечать", AyGrammAutoReply.audiences[AyGrammAutoReply.audience].lowercased(), "person.2.fill", AyGrammColor.indigo, AyGrammAutoReplyAction.audience))
        entries.append(.action(202, "Одному человеку", AyGrammAutoReply.cooldownTitle, "hourglass", AyGrammColor.purple, AyGrammAutoReplyAction.cooldown))
        entries.append(.action(203, "Задержка", AyGrammAutoReply.delayTitle, "timer", AyGrammColor.teal, AyGrammAutoReplyAction.delay))
        entries.append(.action(204, "Исключения", "\(AyGrammAutoReply.excluded.count)", "person.fill.xmark", AyGrammColor.red, AyGrammAutoReplyAction.excluded))
        entries.append(.header(300, "УМНЫЕ ОТВЕТЫ"))
        let rules = AyGrammAutoReply.rules
        for (index, rule) in rules.prefix(90).enumerated() {
            entries.append(.rule(301 + Int32(index), rule.keyword, rule.answer))
        }
        entries.append(.action(398, "Добавить правило", "", "plus", AyGrammColor.green, AyGrammAutoReplyAction.addRule))
        entries.append(.info(399, rules.isEmpty ? "Ответ на слово в сообщении, например на «цена» или «адрес». Правила проверяются раньше основного текста. Нажмите на правило, чтобы удалить его." : "Нажмите на правило, чтобы удалить его."))
        entries.append(.header(400, "ЖУРНАЛ"))
        let log = AyGrammAutoReply.log
        entries.append(.info(401, "Отправлено автоответов: \(AyGrammAutoReply.sentCount)."))
        for (index, line) in log.prefix(20).enumerated() {
            entries.append(.info(402 + Int32(index), line))
        }
        if !log.isEmpty {
            entries.append(.action(498, "Очистить журнал", "", "trash.fill", AyGrammColor.red, AyGrammAutoReplyAction.clearLog))
        }
        entries.append(.info(500, "Автоответ работает, пока AyGramm запущен. Чтобы он отвечал в свёрнутом приложении, включите «Звонки в фоне». Он отвечает только людям в личных чатах, не ботам, на сообщения не старше 10 минут и не больше 30 раз в час. Ответ уходит цитатой на сообщение собеседника, после него Telegram может показать чат прочитанным."))
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Автоответ"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: false)
        return (controllerState, (listState, arguments))
    }

    let controller = ItemListController(context: context, state: signal)
    pushControllerImpl = { [weak controller] c in
        controller?.push(c)
    }
    return controller
}

// MARK: - Сокращения

private final class AyGrammSnippetArguments {
    let add: () -> Void
    let remove: (String) -> Void

    init(add: @escaping () -> Void, remove: @escaping (String) -> Void) {
        self.add = add
        self.remove = remove
    }
}

private enum AyGrammSnippetEntry: ItemListNodeEntry {
    case snippet(Int32, String, String)
    case add
    case info(String)

    var section: ItemListSectionId {
        return 0
    }

    var stableId: Int32 {
        switch self {
        case let .snippet(id, _, _):
            return id
        case .add:
            return 1000
        case .info:
            return 1001
        }
    }

    static func <(lhs: AyGrammSnippetEntry, rhs: AyGrammSnippetEntry) -> Bool {
        return lhs.stableId < rhs.stableId
    }

    func item(presentationData: ItemListPresentationData, arguments: Any) -> ListViewItem {
        let arguments = arguments as! AyGrammSnippetArguments
        switch self {
        case let .snippet(_, key, text):
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: ayGrammIcon("text.badge.plus", AyGrammColor.teal), title: key, label: text, sectionId: self.section, style: .blocks, action: {
                arguments.remove(key)
            })
        case .add:
            return ItemListDisclosureItem(presentationData: presentationData, systemStyle: .glass, icon: ayGrammIcon("plus", AyGrammColor.green), title: "Добавить сокращение", label: "", sectionId: self.section, style: .blocks, action: {
                arguments.add()
            })
        case let .info(text):
            return ItemListTextItem(presentationData: presentationData, text: .plain(text), sectionId: self.section)
        }
    }
}

private func ayGrammSnippetsController(context: AccountContext, changed: @escaping () -> Void) -> ViewController {
    let versionPromise = ValuePromise<Int>(0, ignoreRepeated: false)
    var version = 0
    let refresh: () -> Void = {
        version += 1
        versionPromise.set(version)
        changed()
    }
    let arguments = AyGrammSnippetArguments(add: {
        let alert = UIAlertController(title: "Сокращение", message: "Слово с ; в сообщении при отправке заменится текстом. Пример: ;адрес станет «ул. Ленина, 5».", preferredStyle: .alert)
        alert.addTextField(configurationHandler: { field in
            field.placeholder = "Слово, например адрес"
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
        })
        alert.addTextField(configurationHandler: { field in
            field.placeholder = "Текст"
        })
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Добавить", style: .default, handler: { [weak alert] _ in
            let fields = alert?.textFields ?? []
            if fields.count == 2 {
                AyGrammSnippets.set(fields[0].text ?? "", fields[1].text ?? "")
            }
            refresh()
        }))
        context.sharedContext.mainWindow?.presentNative(alert)
    }, remove: { key in
        let alert = UIAlertController(title: "Удалить \(key)?", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Удалить", style: .destructive, handler: { _ in
            AyGrammSnippets.remove(key)
            refresh()
        }))
        context.sharedContext.mainWindow?.presentNative(alert)
    })

    let signal = combineLatest(queue: .mainQueue(),
        context.sharedContext.presentationData,
        versionPromise.get()
    )
    |> map { presentationData, _ -> (ItemListControllerState, (ItemListNodeState, Any)) in
        var entries: [AyGrammSnippetEntry] = []
        for (index, item) in AyGrammSnippets.all.prefix(900).enumerated() {
            entries.append(.snippet(Int32(index), item.0, item.1))
        }
        entries.append(.add)
        entries.append(.info("Сокращение начинается с ; и стоит отдельным словом. Текст может содержать {дата} и {время}. Нажмите на сокращение, чтобы удалить его. Сообщения с форматированием не меняются."))
        let controllerState = ItemListControllerState(presentationData: ItemListPresentationData(presentationData), title: .text("Сокращения"), leftNavigationButton: nil, rightNavigationButton: nil, backNavigationButton: ItemListBackButton(title: presentationData.strings.Common_Back))
        let listState = ItemListNodeState(presentationData: ItemListPresentationData(presentationData), entries: entries, style: .blocks, animateChanges: false)
        return (controllerState, (listState, arguments))
    }
    return ItemListController(context: context, state: signal)
}
