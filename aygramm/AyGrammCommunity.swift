import Foundation
import Postbox
import SwiftSignalKit

// Сообщество AyGramm держится на канале @augrammipa, без своего сервера и бота.
// Зарегистрированный пользователь = подписчик канала: он сам нажимает «Подписаться», и автор видит его
// в списке подписчиков, как в любом канале Telegram. Админ = владелец канала, это проверяет сам Telegram.
// Бан = бан в канале; приложение забаненного видит свой статус и выключает функции AyGramm.
public enum AyGrammCommunity {
    public static let channelUsername = "augrammipa"
    static let releasesUrl = "https://api.github.com/repos/morozovmark145-ai/AyGramm-iOS/releases"

    public static let consentText = "AyGramm работает и без подписки. Если подписаться на канал @augrammipa, автор увидит ваши @username и имя в списке подписчиков, как в любом канале Telegram. Больше AyGramm ничего не отправляет: ни IP-адрес, ни геолокацию, ни переписку. Отписаться можно в любой момент."

    public static func channel(engine: TelegramEngine) -> Signal<EnginePeer?, NoError> {
        return engine.peers.resolvePeerByName(name: channelUsername, referrer: nil)
        |> mapToSignal { result -> Signal<EnginePeer?, NoError> in
            switch result {
            case .progress:
                return .complete()
            case let .result(peer):
                return .single(peer)
            }
        }
        |> take(1)
    }

    // Статус этого аккаунта в канале: nil, если он не подписан.
    public static func ownParticipant(engine: TelegramEngine, accountPeerId: EnginePeer.Id) -> Signal<ChannelParticipant?, NoError> {
        return channel(engine: engine)
        |> mapToSignal { peer -> Signal<ChannelParticipant?, NoError> in
            guard let peer = peer else {
                return .single(nil)
            }
            return engine.peers.fetchChannelParticipant(peerId: peer.id, participantId: accountPeerId)
        }
    }

    public static func isAdmin(_ participant: ChannelParticipant?) -> Bool {
        if let participant = participant, case .creator = participant {
            return true
        }
        return false
    }

    public static func isBanned(_ participant: ChannelParticipant?) -> Bool {
        if let participant = participant, case let .member(_, _, _, banInfo, _, _) = participant, let banInfo = banInfo {
            return banInfo.rights.flags.contains(.banReadMessages)
        }
        return false
    }

    // Обновляет флаг бана на устройстве. Проверка идёт на телефоне: AyGramm никуда не отправляет данные.
    public static func refreshBanState(engine: TelegramEngine, accountPeerId: EnginePeer.Id) -> Signal<Bool, NoError> {
        return ownParticipant(engine: engine, accountPeerId: accountPeerId)
        |> map { participant -> Bool in
            let banned = isBanned(participant)
            AyGrammSettings.isBanned = banned
            return banned
        }
    }

    public static func join(engine: TelegramEngine) -> Signal<Void, NoError> {
        return channel(engine: engine)
        |> mapToSignal { peer -> Signal<Void, NoError> in
            guard let peer = peer else {
                return .complete()
            }
            return engine.peers.joinChannel(peerId: peer.id, hash: nil)
            |> map { _ -> Void in
                return Void()
            }
            |> `catch` { _ -> Signal<Void, NoError> in
                return .complete()
            }
        }
    }

    // Подписчики (до 200 последних) или забаненные. Telegram отдаёт этот список только админам канала.
    public static func members(engine: TelegramEngine, channelId: EnginePeer.Id, banned: Bool) -> Signal<[RenderedChannelParticipant], NoError> {
        return engine.peers.channelMembers(peerId: channelId, category: banned ? .banned(.all) : .recent(.all), offset: 0, limit: 200)
        |> map { members -> [RenderedChannelParticipant] in
            return members ?? []
        }
    }

    public static func setBanned(engine: TelegramEngine, channelId: EnginePeer.Id, memberId: EnginePeer.Id, banned: Bool) -> Signal<Void, NoError> {
        let rights: TelegramChatBannedRights? = banned ? TelegramChatBannedRights(flags: [.banReadMessages], untilDate: Int32.max) : nil
        return engine.peers.updateChannelMemberBannedRights(peerId: channelId, memberId: memberId, rights: rights)
        |> map { _ -> Void in
            return Void()
        }
    }

    // Открытый счётчик: сумма скачиваний файлов во всех релизах на GitHub. nil, если GitHub не ответил.
    public static func downloadCount() -> Signal<Int?, NoError> {
        return Signal { subscriber in
            Queue.concurrentDefaultQueue().async {
                var total: Int?
                if let url = URL(string: releasesUrl), let data = try? Data(contentsOf: url), let releases = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [[String: Any]] {
                    var sum = 0
                    for release in releases {
                        if let assets = release["assets"] as? [[String: Any]] {
                            for asset in assets {
                                sum += asset["download_count"] as? Int ?? 0
                            }
                        }
                    }
                    total = sum
                }
                subscriber.putNext(total)
                subscriber.putCompletion()
            }
            return EmptyDisposable
        }
    }
}
