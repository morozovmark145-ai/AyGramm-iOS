import Foundation
import Postbox
internal import TelegramApi
import SwiftSignalKit

// Запросы AyGramm к серверу Telegram, которые вызываются вручную или после отправки сообщения.

// После отправки сообщения сервер считает автора «в сети». В режиме призрака через 1,5 с
// AyGramm отправляет «не в сети», чтобы статус не держался.
func ayGrammAfterSend(account: Account) {
    if !AyGrammSettings.hideOnline {
        return
    }
    let network = account.network
    let _ = (Signal<Void, NoError>.single(Void())
    |> delay(1.5, queue: Queue.concurrentDefaultQueue())
    |> mapToSignal { _ -> Signal<Void, NoError> in
        return network.request(Api.functions.account.updateStatus(offline: .boolTrue))
        |> map { _ -> Void in
            return Void()
        }
        |> `catch` { _ -> Signal<Void, NoError> in
            return .complete()
        }
    }).start()
}

// Кнопка «Отправить прочтение»: в режиме призрака отмечает чат прочитанным до сообщения maxId
// только по явному нажатию. true, если сервер принял отметку.
public func ayGrammSendReadReceipt(account: Account, peerId: PeerId, maxId: Int32) -> Signal<Bool, NoError> {
    let network = account.network
    return account.postbox.transaction { transaction -> Peer? in
        return transaction.getPeer(peerId)
    }
    |> mapToSignal { peer -> Signal<Bool, NoError> in
        guard let peer = peer else {
            return .single(false)
        }
        if let inputChannel = apiInputChannel(peer) {
            return network.request(Api.functions.channels.readHistory(channel: inputChannel, maxId: maxId))
            |> map { _ -> Bool in
                return true
            }
            |> `catch` { _ -> Signal<Bool, NoError> in
                return .single(false)
            }
        } else if let inputPeer = apiInputPeer(peer) {
            return network.request(Api.functions.messages.readHistory(peer: inputPeer, maxId: maxId))
            |> map { _ -> Bool in
                return true
            }
            |> `catch` { _ -> Signal<Bool, NoError> in
                return .single(false)
            }
        } else {
            return .single(false)
        }
    }
}
