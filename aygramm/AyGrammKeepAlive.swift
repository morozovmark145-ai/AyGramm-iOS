import Foundation
import UIKit
import AVFAudio
import NaturalLanguage
import UserNotifications
import TelegramCore

// «Звонки в фоне». Push-уведомления Telegram приходят только в приложение с подписью Telegram,
// поэтому переподписанный AyGramm в свёрнутом виде засыпает и не получает звонков.
// В этом режиме, пока AyGramm свёрнут, играет беззвучный звук: iOS не усыпляет приложение,
// соединение с Telegram остаётся открытым, звонок показывается через экран вызова iOS,
// а о новых сообщениях AyGramm сам показывает уведомление.
final class AyGrammKeepAlive {
    static let shared = AyGrammKeepAlive()

    private var player: AVAudioPlayer?
    private var interruptionObserver: NSObjectProtocol?
    private var inForeground = true
    private var hasOtherAudio = false

    var isRunning: Bool {
        return self.player != nil
    }

    // Вызывается при сворачивании и разворачивании AyGramm и когда Telegram сам включает или выключает звук.
    func update(inForeground: Bool, hasOtherAudio: Bool) {
        self.inForeground = inForeground
        self.hasOtherAudio = hasOtherAudio
        if !inForeground && !hasOtherAudio && AyGrammSettings.keepAlive && !AyGrammKeepAlive.isBatteryLow() {
            self.start()
        } else {
            self.stop()
        }
    }

    private func start() {
        if let player = self.player {
            if !player.isPlaying {
                player.play()
            }
            return
        }
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            let player = try AVAudioPlayer(data: AyGrammKeepAlive.silentWav())
            player.numberOfLoops = -1
            player.volume = 0.0
            player.play()
            self.player = player
        } catch {
            self.player = nil
            return
        }
        if self.interruptionObserver == nil {
            // После звонка или будильника iOS останавливает звук, его надо запустить снова.
            self.interruptionObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main, using: { [weak self] notification in
                guard let self = self, let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt, AVAudioSession.InterruptionType(rawValue: raw) == .ended else {
                    return
                }
                self.player = nil
                self.update(inForeground: self.inForeground, hasOtherAudio: self.hasOtherAudio)
            })
        }
    }

    private func stop() {
        if let player = self.player {
            self.player = nil
            player.stop()
        }
    }

    // Встроенный плагин: при заряде ниже 20% без зарядки фон выключается, чтобы телефон не сел.
    static func isBatteryLow() -> Bool {
        guard AyGrammSettings.value(AyGrammSettings.keepAliveBatteryKey) else {
            return false
        }
        let device = UIDevice.current
        device.isBatteryMonitoringEnabled = true
        let level = device.batteryLevel
        return level >= 0.0 && level < 0.2 && device.batteryState == .unplugged
    }

    // Одна секунда тишины: WAV, 8000 Гц, 16 бит, моно.
    private static func silentWav() -> Data {
        let sampleRate: UInt32 = 8000
        let dataSize: UInt32 = sampleRate * 2
        var data = Data()
        func append32(_ value: UInt32) {
            var v = value.littleEndian
            data.append(Data(bytes: &v, count: 4))
        }
        func append16(_ value: UInt16) {
            var v = value.littleEndian
            data.append(Data(bytes: &v, count: 2))
        }
        data.append("RIFF".data(using: .ascii)!)
        append32(36 + dataSize)
        data.append("WAVE".data(using: .ascii)!)
        data.append("fmt ".data(using: .ascii)!)
        append32(16)
        append16(1)
        append16(1)
        append32(sampleRate)
        append32(sampleRate * 2)
        append16(2)
        append16(16)
        data.append("data".data(using: .ascii)!)
        append32(dataSize)
        data.append(Data(count: Int(dataSize)))
        return data
    }

    // Уведомление о новом сообщении, пока AyGramm свёрнут и работает «Звонки в фоне».
    static func notify(messages: [EngineMessage]) {
        guard shared.isRunning, let message = messages.first, message.flags.contains(.Incoming) else {
            return
        }
        let content = UNMutableNotificationContent()
        content.title = message.enginePeers[message.id.peerId]?.debugDisplayTitle ?? "AyGramm"
        if let author = message.author, author.id != message.id.peerId {
            content.body = author.debugDisplayTitle + ": " + describe(message)
        } else {
            content.body = describe(message)
        }
        content.sound = .default
        content.threadIdentifier = "\(message.id.peerId.toInt64())"
        let request = UNNotificationRequest(identifier: "aygramm-\(message.id.peerId.toInt64())-\(message.id.id)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    private static func describe(_ message: EngineMessage) -> String {
        if !message.text.isEmpty {
            return message.text
        }
        return message.media.isEmpty ? "Сообщение" : "Медиа"
    }
}

// Встроенный плагин «Прочитать вслух»: текст сообщения читает голос iOS на языке сообщения.
final class AyGrammSpeech {
    static let shared = AyGrammSpeech()
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String) {
        if self.synthesizer.isSpeaking {
            self.synthesizer.stopSpeaking(at: .immediate)
            return
        }
        let utterance = AVSpeechUtterance(string: text)
        let language = NLLanguageRecognizer.dominantLanguage(for: text)?.rawValue ?? "ru"
        utterance.voice = AVSpeechSynthesisVoice(language: language) ?? AVSpeechSynthesisVoice(language: "ru-RU")
        self.synthesizer.speak(utterance)
    }
}
