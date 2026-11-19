import Foundation
import UIKit
import SwiftSignalKit
import TelegramCore
import AccountContext

// Запуск AyGramm после входа в аккаунт:
// 1. проверка бана в канале @augrammipa (на телефоне, ничего не отправляется);
// 2. один раз — согласие на подписку с описанием, что увидит автор;
// 3. подсказка о новом плагине из каталога.
func ayGrammAccountReady(context: AccountContext, presentAlert: @escaping (UIAlertController) -> Void) {
    AyGrammCrashLog.install()
    // Автоответ слушает новые сообщения аккаунта, бомбы срабатывают после перезапуска, озвучка подключается к меню «Отправить».
    AyGrammAutoReply.attach(account: context.account)
    AyGrammBomb.resume(account: context.account)
    ayGrammInstallActions()
    let engine = context.engine
    let _ = (AyGrammCommunity.refreshBanState(engine: engine, accountPeerId: context.account.peerId)
    |> deliverOnMainQueue).start(next: { banned in
        if banned {
            let alert = UIAlertController(title: "AyGramm", message: "Автор AyGramm заблокировал этот аккаунт в канале @\(AyGrammCommunity.channelUsername). Режим призрака, удалённые сообщения и плагины выключены.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            presentAlert(alert)
            return
        }
        if !UserDefaults.standard.bool(forKey: "AyGrammConsentShown") {
            UserDefaults.standard.set(true, forKey: "AyGrammConsentShown")
            let alert = UIAlertController(title: "Добро пожаловать в AyGramm", message: AyGrammCommunity.consentText, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Подписаться", style: .default, handler: { _ in
                let _ = AyGrammCommunity.join(engine: engine).start()
            }))
            alert.addAction(UIAlertAction(title: "Не сейчас", style: .cancel, handler: nil))
            presentAlert(alert)
            return
        }
        let _ = (AyGrammCommunity.latestRelease()
        |> deliverOnMainQueue).start(next: { release in
            let skipped = UserDefaults.standard.integer(forKey: "AyGrammSkippedVersion")
            if let release = release, release.version > AyGrammSettings.currentVersion, release.version != skipped {
                let alert = UIAlertController(title: "Вышла AyGramm 0.\(release.version)", message: "У вас версия 0.\(AyGrammSettings.currentVersion). Новый файл лежит на GitHub и в канале @\(AyGrammCommunity.channelUsername).", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Скачать", style: .default, handler: { _ in
                    context.sharedContext.applicationBindings.openUrl(release.url)
                }))
                alert.addAction(UIAlertAction(title: "Не сейчас", style: .cancel, handler: { _ in
                    UserDefaults.standard.set(release.version, forKey: "AyGrammSkippedVersion")
                }))
                presentAlert(alert)
                return
            }
            let _ = (AyGrammPlugins.catalog()
            |> deliverOnMainQueue).start(next: { catalog in
                let unseen = AyGrammPlugins.unseen(in: catalog)
                guard let plugin = unseen.first else {
                    return
                }
                AyGrammPlugins.markSeen(unseen.map { $0.id })
                let alert = UIAlertController(title: "Новый плагин: \(plugin.name)", message: plugin.description + "\n\nВключить: Настройки → AyGramm → Плагины.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                presentAlert(alert)
            })
        })
    })
}
