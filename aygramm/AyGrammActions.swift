import Foundation
import UIKit
import AVFoundation
import NaturalLanguage
import SwiftSignalKit
import TelegramCore
import AccountContext
import Display
import ContextUI
import TelegramPresentationData
import PresentationDataUtils
import AppBundle
import OpusBinding
import AudioWaveform

// Действия AyGramm в чате: «Отправить голосом», кружок из галереи, скриншот сообщений, статистика чата,
// «Стереть мои сообщения» и подменю AyGramm в меню сообщения.

private func ayGrammRGB(_ value: UInt32) -> UIColor {
    return UIColor(red: CGFloat((value >> 16) & 0xff) / 255.0, green: CGFloat((value >> 8) & 0xff) / 255.0, blue: CGFloat(value & 0xff) / 255.0, alpha: 1.0)
}

func ayGrammInstallActions() {
    AyGrammOutgoing.voiceRenderer = { text, completion in
        AyGrammTextToVoice.render(text, completion: completion)
    }
    AyGrammVoice.previewPlayer = { effect in
        AyGrammVoicePreview.play(effect: effect)
    }
}

// MARK: - Образец эффекта голоса

// Фраза-образец читается голосом iOS один раз, потом каждый выбор эффекта проигрывает её с этим эффектом.
final class AyGrammVoicePreview {
    private static var cached: [Int16]?
    private static var waiting: Int?
    private static var player: AVAudioPlayer?

    static func play(effect: Int) {
        if let cached = cached {
            start(cached, effect: effect)
            return
        }
        if waiting != nil {
            waiting = effect
            return
        }
        waiting = effect
        AyGrammTextToVoice.renderSamples("Привет! Так звучит мой голос в AyGramm.", completion: { samples, rate in
            DispatchQueue.global(qos: .userInitiated).async {
                let pcm = AyGrammTextToVoice.resample(samples, rate: rate)
                DispatchQueue.main.async {
                    let latest = AyGrammVoicePreview.waiting ?? effect
                    AyGrammVoicePreview.waiting = nil
                    if let pcm = pcm {
                        AyGrammVoicePreview.cached = pcm
                        AyGrammVoicePreview.start(pcm, effect: latest)
                    }
                }
            }
        })
    }

    private static func start(_ source: [Int16], effect: Int) {
        var pcm = source
        pcm.withUnsafeMutableBufferPointer { buffer -> Void in
            if let base = buffer.baseAddress {
                AyGrammVoice.processWhole(base, count: buffer.count, effect: effect)
            }
        }
        player?.stop()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
        try? AVAudioSession.sharedInstance().setActive(true)
        player = try? AVAudioPlayer(data: wav(pcm))
        player?.play()
    }

    // Файл WAV: 48 кГц, 16 бит, моно.
    private static func wav(_ pcm: [Int16]) -> Data {
        var data = Data()
        func append32(_ value: UInt32) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
        }
        func append16(_ value: UInt16) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
        }
        let byteCount = UInt32(pcm.count * 2)
        data.append(contentsOf: Array("RIFF".utf8))
        append32(36 + byteCount)
        data.append(contentsOf: Array("WAVEfmt ".utf8))
        append32(16)
        append16(1)
        append16(1)
        append32(48000)
        append32(96000)
        append16(2)
        append16(16)
        data.append(contentsOf: Array("data".utf8))
        append32(byteCount)
        pcm.withUnsafeBytes { data.append(contentsOf: $0) }
        return data
    }
}

// MARK: - Отправить голосом

// Голос iOS читает текст в звук, звук переводится в 48 кГц, к нему применяется эффект войс ченджера,
// кодек Opus собирает файл OGG, как у записанного голосового. Озвучка кончается пустым буфером
// или паузой в 1,5 секунды, предел 30 секунд.
final class AyGrammTextToVoice {
    private static var active: [AyGrammTextToVoice] = []

    private let synthesizer = AVSpeechSynthesizer()
    private let completion: ([Float], Double) -> Void
    private var samples: [Float] = []
    private var sampleRate: Double = 22050.0
    private var finished = false
    private var lastBuffer = CACurrentMediaTime()

    private init(completion: @escaping ([Float], Double) -> Void) {
        self.completion = completion
    }

    static func render(_ text: String, completion: @escaping ((Data, Int, Data?)?) -> Void) {
        renderSamples(text, completion: { samples, rate in
            DispatchQueue.global(qos: .userInitiated).async {
                completion(AyGrammTextToVoice.encode(samples: samples, rate: rate))
            }
        })
    }

    // Звук голоса iOS без кодека: отсчёты и их частота.
    static func renderSamples(_ text: String, completion: @escaping ([Float], Double) -> Void) {
        DispatchQueue.main.async {
            let renderer = AyGrammTextToVoice(completion: completion)
            active.append(renderer)
            renderer.start(text)
        }
    }

    private static func voice(_ language: String) -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix(language) }
        if let enhanced = voices.first(where: { $0.quality == .enhanced }) {
            return enhanced
        }
        return voices.first ?? AVSpeechSynthesisVoice(language: "ru-RU")
    }

    private static func extract(_ buffer: AVAudioBuffer) -> ([Float], Double) {
        guard let pcm = buffer as? AVAudioPCMBuffer else {
            return ([], 0.0)
        }
        let count = Int(pcm.frameLength)
        let rate = pcm.format.sampleRate
        if count == 0 {
            return ([], rate)
        }
        if let channels = pcm.floatChannelData {
            return (Array(UnsafeBufferPointer(start: channels[0], count: count)), rate)
        }
        if let channels = pcm.int16ChannelData {
            let pointer = channels[0]
            var result = [Float](repeating: 0.0, count: count)
            for index in 0 ..< count {
                result[index] = Float(pointer[index]) / 32768.0
            }
            return (result, rate)
        }
        return ([], rate)
    }

    private func start(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        let language = NLLanguageRecognizer.dominantLanguage(for: text)?.rawValue ?? "ru"
        utterance.voice = AyGrammTextToVoice.voice(language)
        self.synthesizer.write(utterance, toBufferCallback: { [weak self] buffer in
            let chunk = AyGrammTextToVoice.extract(buffer)
            DispatchQueue.main.async {
                self?.append(chunk.0, rate: chunk.1)
            }
        })
        self.watch(started: CACurrentMediaTime())
    }

    private func append(_ chunk: [Float], rate: Double) {
        if self.finished {
            return
        }
        if chunk.isEmpty {
            if !self.samples.isEmpty {
                self.finish()
            }
            return
        }
        if rate > 0.0 {
            self.sampleRate = rate
        }
        self.samples.append(contentsOf: chunk)
        self.lastBuffer = CACurrentMediaTime()
    }

    private func watch(started: Double) {
        if self.finished {
            return
        }
        let now = CACurrentMediaTime()
        if (!self.samples.isEmpty && now - self.lastBuffer > 1.5) || now - started > 30.0 {
            self.finish()
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: { [weak self] in
            self?.watch(started: started)
        })
    }

    private func finish() {
        if self.finished {
            return
        }
        self.finished = true
        let samples = self.samples
        let rate = self.sampleRate
        let completion = self.completion
        AyGrammTextToVoice.active.removeAll(where: { $0 === self })
        completion(samples, rate)
    }

    // Перевод в 48 кГц и 16 бит. Меньше 0,1 секунды звука считается пустой озвучкой.
    static func resample(_ samples: [Float], rate: Double) -> [Int16]? {
        if samples.isEmpty || rate <= 0.0 {
            return nil
        }
        let ratio = 48000.0 / rate
        let count = Int(Double(samples.count) * ratio)
        if count < 4800 {
            return nil
        }
        var pcm = [Int16](repeating: 0, count: count)
        let last = samples.count - 1
        for index in 0 ..< count {
            let position = Double(index) / ratio
            let lower = min(Int(position), last)
            let upper = min(lower + 1, last)
            let fraction = Float(min(1.0, position - Double(lower)))
            let value = samples[lower] + (samples[upper] - samples[lower]) * fraction
            pcm[index] = Int16(max(-1.0, min(1.0, value)) * 32767.0)
        }
        return pcm
    }

    static func encode(samples: [Float], rate: Double) -> (Data, Int, Data?)? {
        guard var pcm = resample(samples, rate: rate) else {
            return nil
        }
        pcm.withUnsafeMutableBufferPointer { buffer -> Void in
            if let base = buffer.baseAddress {
                AyGrammVoice.processWhole(base, count: buffer.count)
            }
        }

        let dataItem = TGDataItem()
        let writer = TGOggOpusWriter()
        writer.begin(with: dataItem)
        let frameSize = 960
        var frame = [Int16](repeating: 0, count: frameSize)
        var offset = 0
        while offset < pcm.count {
            let available = min(frameSize, pcm.count - offset)
            for index in 0 ..< frameSize {
                frame[index] = index < available ? pcm[offset + index] : 0
            }
            frame.withUnsafeMutableBytes { bytes -> Void in
                if let base = bytes.baseAddress {
                    writer.writeFrame(base.assumingMemoryBound(to: UInt8.self), frameByteCount: UInt(frameSize * 2))
                }
            }
            offset += frameSize
        }
        writer.writeFrame(nil, frameByteCount: 0)
        let data: Data = dataItem.data()
        let duration = max(1, Int(writer.encodedDuration().rounded()))

        // Волна для пузыря: 100 пиков по 5 бит, как у записанного голосового.
        var peaks = [Int64](repeating: 0, count: 100)
        for index in 0 ..< pcm.count {
            let sample = Int64(pcm[index])
            let magnitude = sample < 0 ? -sample : sample
            let slot = index * 100 / pcm.count
            if peaks[slot] < magnitude {
                peaks[slot] = magnitude
            }
        }
        var sum: Int64 = 0
        for peak in peaks {
            sum += peak
        }
        let calculatedPeak = max(Int64(2500), Int64(Double(sum) * 1.8 / 100.0))
        var scaled = [Int16](repeating: 0, count: 100)
        for index in 0 ..< 100 {
            scaled[index] = Int16(min(31, min(peaks[index], calculatedPeak) * 31 / calculatedPeak))
        }
        let waveformSamples = scaled.withUnsafeBytes { Data($0) }
        let bitstream = AudioWaveform(samples: waveformSamples, peak: 31).makeBitstream()
        let waveform = AudioWaveform(bitstream: bitstream, bitsPerSample: 5).makeBitstream()
        return (data, duration, waveform)
    }
}

// MARK: - Кружок из галереи

// Видео из галереи: iOS даёт обрезать его до 60 секунд, AyGramm вырезает квадрат по центру 480×480
// и отправляет круглым видеосообщением.
final class AyGrammRoundVideoPicker: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private static var current: AyGrammRoundVideoPicker?
    private let context: AccountContext
    private let peerId: EnginePeer.Id
    private let toast: (String) -> Void

    private init(context: AccountContext, peerId: EnginePeer.Id, toast: @escaping (String) -> Void) {
        self.context = context
        self.peerId = peerId
        self.toast = toast
        super.init()
    }

    static func present(context: AccountContext, peerId: EnginePeer.Id, toast: @escaping (String) -> Void) {
        let handler = AyGrammRoundVideoPicker(context: context, peerId: peerId, toast: toast)
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.mediaTypes = ["public.movie"]
        picker.allowsEditing = true
        picker.videoMaximumDuration = 60.0
        picker.videoQuality = .typeHigh
        picker.delegate = handler
        current = handler
        context.sharedContext.mainWindow?.presentNative(picker)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
        AyGrammRoundVideoPicker.current = nil
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true, completion: nil)
        AyGrammRoundVideoPicker.current = nil
        let toast = self.toast
        guard let url = info[.mediaURL] as? URL else {
            toast("Не удалось открыть видео.")
            return
        }
        toast("Готовлю кружок…")
        let account = self.context.account
        let peerId = self.peerId
        AyGrammRoundVideoPicker.export(url: url, completion: { result in
            DispatchQueue.main.async {
                guard let result = result else {
                    toast("Не удалось сделать кружок из этого видео.")
                    return
                }
                let _ = AyGrammMediaSend.roundVideo(account: account, peerId: peerId, path: result.0, duration: result.1, side: 480).start()
            }
        })
    }

    static func export(url: URL, completion: @escaping ((String, Double)?) -> Void) {
        let asset = AVURLAsset(url: url)
        guard let track = asset.tracks(withMediaType: .video).first else {
            completion(nil)
            return
        }
        let duration = min(CMTimeGetSeconds(asset.duration), 60.0)
        if !(duration > 0.0) {
            completion(nil)
            return
        }
        let side: CGFloat = 480.0
        let transform = track.preferredTransform
        let rect = CGRect(origin: CGPoint(), size: track.naturalSize).applying(transform)
        let width = abs(rect.width)
        let height = abs(rect.height)
        if width < 1.0 || height < 1.0 {
            completion(nil)
            return
        }
        let scale = side / min(width, height)
        let finalTransform = transform
            .concatenating(CGAffineTransform(translationX: -rect.minX, y: -rect.minY))
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: (side - width * scale) / 2.0, y: (side - height * scale) / 2.0))
        let timeRange = CMTimeRange(start: CMTime.zero, duration: CMTime(seconds: duration, preferredTimescale: 600))
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
        layerInstruction.setTransform(finalTransform, at: CMTime.zero)
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = timeRange
        instruction.layerInstructions = [layerInstruction]
        let composition = AVMutableVideoComposition()
        composition.renderSize = CGSize(width: side, height: side)
        composition.frameDuration = CMTime(value: 1, timescale: 30)
        composition.instructions = [instruction]
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetMediumQuality) else {
            completion(nil)
            return
        }
        let path = NSTemporaryDirectory() + "aygramm-round-\(Int64.random(in: 1 ..< Int64.max)).mp4"
        exportSession.outputURL = URL(fileURLWithPath: path)
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        exportSession.videoComposition = composition
        exportSession.timeRange = timeRange
        exportSession.exportAsynchronously {
            completion(exportSession.status == .completed ? (path, duration) : nil)
        }
    }
}

// MARK: - Общие помощники

private let ayGrammWeekdays = ["воскресенье", "понедельник", "вторник", "среда", "четверг", "пятница", "суббота"]

func ayGrammIsGroup(_ peer: EnginePeer?) -> Bool {
    guard let peer = peer else {
        return false
    }
    switch peer {
    case .legacyGroup:
        return true
    case let .channel(channel):
        if case .group = channel.info {
            return true
        }
        return false
    default:
        return false
    }
}

func ayGrammShareImage(context: AccountContext, image: UIImage) {
    let controller = UIActivityViewController(activityItems: [image], applicationActivities: nil)
    context.sharedContext.mainWindow?.presentNative(controller)
}

private func ayGrammDraw(_ text: String, font: UIFont, color: UIColor, in rect: CGRect, alignment: NSTextAlignment) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    paragraph.lineBreakMode = .byWordWrapping
    (text as NSString).draw(in: rect, withAttributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph])
}

private func ayGrammTextSize(_ text: String, font: UIFont, width: CGFloat) -> CGSize {
    let bounds = (text as NSString).boundingRect(with: CGSize(width: width, height: 100000.0), options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: font], context: nil)
    return CGSize(width: ceil(bounds.width), height: ceil(bounds.height))
}

// MARK: - Скриншот сообщений

// Текст сообщения для картинки: медиа подписывается словом, шифровка показывается расшифрованной.
func ayGrammShotText(_ message: EngineMessage) -> String {
    var parts: [String] = []
    for media in message.media {
        if media is TelegramMediaImage {
            parts.append("📷 Фото")
        } else if let file = media as? TelegramMediaFile {
            if file.isSticker {
                parts.append("🖼 Стикер")
            } else if file.isInstantVideo {
                parts.append("⏺ Кружок")
            } else if file.isVoice {
                parts.append("🎤 Голосовое")
            } else if file.isVideo {
                parts.append("🎬 Видео")
            } else if file.isMusic {
                parts.append("🎵 Музыка")
            } else {
                parts.append("📎 Файл")
            }
        }
    }
    let text = AyGrammCipher.displayText(message.text) ?? message.text
    if !text.isEmpty {
        parts.append(text)
    }
    return parts.isEmpty ? "Сообщение" : parts.joined(separator: "\n")
}

private struct AyGrammShotItem {
    let outgoing: Bool
    let name: String?
    let initial: String
    let colorIndex: Int
    let text: String
    let time: String
    let textSize: CGSize
    let bubbleSize: CGSize
}

// Картинка в духе темы Telegram: тёмная или светлая, пузыри, имена и аватары в группах, время.
func ayGrammRenderShot(messages: [EngineMessage], title: String, dark: Bool, isGroup: Bool) -> UIImage? {
    if messages.isEmpty {
        return nil
    }
    let width: CGFloat = 390.0
    let margin: CGFloat = 12.0
    let avatarSize: CGFloat = 30.0
    let textFont = UIFont.systemFont(ofSize: 16.0)
    let nameFont = UIFont.boldSystemFont(ofSize: 13.0)
    let timeFont = UIFont.systemFont(ofSize: 11.0)
    let titleFont = UIFont.boldSystemFont(ofSize: 15.0)
    let nameColors: [UInt32] = [0xe17076, 0xeda86c, 0xa695e7, 0x7bc862, 0x6ec9cb, 0x65aadd, 0xee7aae]
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"

    var items: [AyGrammShotItem] = []
    var height: CGFloat = 58.0
    for message in messages {
        let outgoing = !message.flags.contains(.Incoming)
        let showName = isGroup && !outgoing
        let authorTitle = message.author?.compactDisplayTitle ?? ""
        let name: String? = showName ? authorTitle : nil
        let initial = String(authorTitle.prefix(1)).uppercased()
        let colorIndex = Int(abs((message.author?.id.id._internalGetInt64Value() ?? 0) % Int64(nameColors.count)))
        let text = ayGrammShotText(message)
        let time = formatter.string(from: Date(timeIntervalSince1970: Double(message.timestamp)))
        let maxTextWidth = width * 0.74 - 20.0 - (showName ? avatarSize + 6.0 : 0.0)
        let textSize = ayGrammTextSize(text, font: textFont, width: maxTextWidth)
        var contentWidth = max(textSize.width, ayGrammTextSize(time, font: timeFont, width: 100.0).width)
        if let name = name {
            contentWidth = max(contentWidth, min(maxTextWidth, ayGrammTextSize(name, font: nameFont, width: maxTextWidth).width))
        }
        let bubbleHeight = 8.0 + (name != nil ? 18.0 : 0.0) + textSize.height + 16.0
        let bubbleSize = CGSize(width: contentWidth + 20.0, height: bubbleHeight)
        items.append(AyGrammShotItem(outgoing: outgoing, name: name, initial: initial, colorIndex: colorIndex, text: text, time: time, textSize: textSize, bubbleSize: bubbleSize))
        height += bubbleSize.height + 6.0
    }
    height += 26.0

    let format = UIGraphicsImageRendererFormat()
    format.scale = 3.0
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
    return renderer.image { rendererContext in
        let context = rendererContext.cgContext
        let top = dark ? ayGrammRGB(0x0e1621) : ayGrammRGB(0xd5e7c7)
        let bottom = dark ? ayGrammRGB(0x17212b) : ayGrammRGB(0xa9cf94)
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [top.cgColor, bottom.cgColor] as CFArray, locations: [0.0, 1.0]) {
            context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: 0.0, y: height), options: [])
        }
        let incomingFill = dark ? ayGrammRGB(0x182533) : UIColor.white
        let outgoingFill = dark ? ayGrammRGB(0x2b5278) : ayGrammRGB(0xe1ffc7)
        let textColor = dark ? UIColor.white : UIColor.black
        let timeColor = dark ? UIColor(white: 1.0, alpha: 0.5) : UIColor(white: 0.0, alpha: 0.45)

        let titleSize = ayGrammTextSize(title, font: titleFont, width: width - 80.0)
        let titleRect = CGRect(x: (width - titleSize.width) / 2.0 - 12.0, y: 14.0, width: titleSize.width + 24.0, height: titleSize.height + 10.0)
        UIColor(white: 0.0, alpha: 0.25).setFill()
        UIBezierPath(roundedRect: titleRect, cornerRadius: titleRect.height / 2.0).fill()
        ayGrammDraw(title, font: titleFont, color: UIColor.white, in: titleRect.insetBy(dx: 12.0, dy: 5.0), alignment: .center)

        var y: CGFloat = 58.0
        for item in items {
            let x: CGFloat
            if item.outgoing {
                x = width - margin - item.bubbleSize.width
            } else {
                x = margin + (isGroup ? avatarSize + 6.0 : 0.0)
            }
            let bubbleRect = CGRect(x: x, y: y, width: item.bubbleSize.width, height: item.bubbleSize.height)
            (item.outgoing ? outgoingFill : incomingFill).setFill()
            UIBezierPath(roundedRect: bubbleRect, cornerRadius: 16.0).fill()
            if isGroup && !item.outgoing {
                let avatarRect = CGRect(x: margin, y: bubbleRect.maxY - avatarSize, width: avatarSize, height: avatarSize)
                ayGrammRGB(nameColors[item.colorIndex]).setFill()
                UIBezierPath(ovalIn: avatarRect).fill()
                ayGrammDraw(item.initial, font: UIFont.boldSystemFont(ofSize: 14.0), color: UIColor.white, in: avatarRect.insetBy(dx: 0.0, dy: 6.0), alignment: .center)
            }
            var textY = y + 8.0
            if let name = item.name {
                ayGrammDraw(name, font: nameFont, color: ayGrammRGB(nameColors[item.colorIndex]), in: CGRect(x: x + 10.0, y: textY, width: item.bubbleSize.width - 20.0, height: 16.0), alignment: .left)
                textY += 18.0
            }
            ayGrammDraw(item.text, font: textFont, color: textColor, in: CGRect(x: x + 10.0, y: textY, width: item.textSize.width + 1.0, height: item.textSize.height + 2.0), alignment: .left)
            ayGrammDraw(item.time, font: timeFont, color: timeColor, in: CGRect(x: x + 10.0, y: bubbleRect.maxY - 16.0, width: item.bubbleSize.width - 20.0, height: 13.0), alignment: .right)
            y += item.bubbleSize.height + 6.0
        }
        ayGrammDraw("AyGramm", font: UIFont.boldSystemFont(ofSize: 11.0), color: UIColor(white: dark ? 1.0 : 0.0, alpha: 0.35), in: CGRect(x: margin, y: height - 20.0, width: width - margin * 2.0, height: 14.0), alignment: .right)
    }
}

func ayGrammShareScreenshot(context: AccountContext, anchor: EngineMessage.Id, count: Int, peer: EnginePeer?) {
    let dark = context.sharedContext.currentPresentationData.with { $0 }.theme.overallDarkAppearance
    let isGroup = ayGrammIsGroup(peer)
    let title = peer?.compactDisplayTitle ?? "Чат"
    let _ = (AyGrammShot.messages(account: context.account, anchor: anchor, count: count)
    |> deliverOnMainQueue).start(next: { messages in
        guard let image = ayGrammRenderShot(messages: messages, title: title, dark: dark, isGroup: isGroup) else {
            return
        }
        ayGrammShareImage(context: context, image: image)
    })
}

// MARK: - Статистика чата

private func ayGrammNumber(_ value: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = " "
    return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
}

func ayGrammStatsText(_ stats: AyGrammChatStatsResult, isPrivate: Bool) -> String {
    var lines: [String] = []
    lines.append("Всего сообщений: \(ayGrammNumber(stats.total))")
    if stats.total > 0 {
        let percent = Int((Double(stats.mine) * 100.0 / Double(stats.total)).rounded())
        lines.append("Ваших: \(ayGrammNumber(stats.mine)) (\(percent)%)")
        lines.append((isPrivate ? "Собеседника: " : "Остальных: ") + "\(ayGrammNumber(max(0, stats.total - stats.mine))) (\(max(0, 100 - percent))%)")
    }
    if let firstDate = stats.firstDate {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy"
        let days = max(0, Int((Date().timeIntervalSince1970 - Double(firstDate)) / 86400.0))
        lines.append("Первое сообщение: \(formatter.string(from: Date(timeIntervalSince1970: Double(firstDate)))), дней назад: \(ayGrammNumber(days))")
    }
    lines.append("")
    lines.append("Фото \(ayGrammNumber(stats.photos)) · Видео \(ayGrammNumber(stats.videos)) · Голосовые \(ayGrammNumber(stats.voice)) · Кружки \(ayGrammNumber(stats.round))")
    lines.append("Файлы \(ayGrammNumber(stats.files)) · Ссылки \(ayGrammNumber(stats.links)) · GIF \(ayGrammNumber(stats.gifs)) · Музыка \(ayGrammNumber(stats.music))")
    if let hour = stats.activeHour {
        lines.append("")
        lines.append(String(format: "Самый активный час: %02d:00", hour))
    }
    if let weekday = stats.activeWeekday, weekday >= 0 && weekday < ayGrammWeekdays.count {
        lines.append("Самый активный день: " + ayGrammWeekdays[weekday])
    }
    if !stats.topEmoji.isEmpty {
        lines.append("Любимые эмодзи: " + stats.topEmoji.joined(separator: " "))
    }
    if !stats.topWords.isEmpty {
        lines.append("Частые слова: " + stats.topWords.joined(separator: ", "))
    }
    if stats.scanned > 0 {
        lines.append("")
        lines.append("Час, день, эмодзи и слова посчитаны по \(ayGrammNumber(stats.scanned)) скачанным сообщениям.")
    }
    return lines.joined(separator: "\n")
}

// Карточка 1080×1920 для сторис.
func ayGrammStatsCard(stats: AyGrammChatStatsResult, title: String, isPrivate: Bool) -> UIImage? {
    let size = CGSize(width: 360.0, height: 640.0)
    let format = UIGraphicsImageRendererFormat()
    format.scale = 3.0
    let renderer = UIGraphicsImageRenderer(size: size, format: format)
    return renderer.image { rendererContext in
        let context = rendererContext.cgContext
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [ayGrammRGB(0x5b2bd6).cgColor, ayGrammRGB(0x1f7ae0).cgColor] as CFArray, locations: [0.0, 1.0]) {
            context.drawLinearGradient(gradient, start: CGPoint(), end: CGPoint(x: size.width, y: size.height), options: [])
        }
        let white = UIColor.white
        let soft = UIColor(white: 1.0, alpha: 0.75)
        ayGrammDraw("СТАТИСТИКА ЧАТА", font: UIFont.boldSystemFont(ofSize: 14.0), color: soft, in: CGRect(x: 20.0, y: 48.0, width: 320.0, height: 20.0), alignment: .center)
        ayGrammDraw(title, font: UIFont.boldSystemFont(ofSize: 24.0), color: white, in: CGRect(x: 20.0, y: 74.0, width: 320.0, height: 62.0), alignment: .center)
        ayGrammDraw(ayGrammNumber(stats.total), font: UIFont.systemFont(ofSize: 58.0, weight: .heavy), color: white, in: CGRect(x: 20.0, y: 150.0, width: 320.0, height: 70.0), alignment: .center)
        ayGrammDraw("сообщений", font: UIFont.systemFont(ofSize: 17.0, weight: .medium), color: soft, in: CGRect(x: 20.0, y: 220.0, width: 320.0, height: 22.0), alignment: .center)
        var rows: [(String, String)] = []
        if stats.total > 0 {
            let percent = Int((Double(stats.mine) * 100.0 / Double(stats.total)).rounded())
            rows.append(("Мои сообщения", "\(percent)%"))
            rows.append((isPrivate ? "Собеседник" : "Остальные", "\(max(0, 100 - percent))%"))
        }
        rows.append(("Фото и видео", ayGrammNumber(stats.photos + stats.videos)))
        rows.append(("Голосовые и кружки", ayGrammNumber(stats.voice + stats.round)))
        if let firstDate = stats.firstDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd.MM.yyyy"
            rows.append(("Первое сообщение", formatter.string(from: Date(timeIntervalSince1970: Double(firstDate)))))
        }
        if let hour = stats.activeHour {
            rows.append(("Самый активный час", String(format: "%02d:00", hour)))
        }
        if !stats.topEmoji.isEmpty {
            rows.append(("Любимые эмодзи", stats.topEmoji.prefix(3).joined(separator: " ")))
        }
        var y: CGFloat = 270.0
        for row in rows.prefix(8) {
            let rowRect = CGRect(x: 24.0, y: y, width: 312.0, height: 38.0)
            UIColor(white: 1.0, alpha: 0.14).setFill()
            UIBezierPath(roundedRect: rowRect, cornerRadius: 12.0).fill()
            ayGrammDraw(row.0, font: UIFont.systemFont(ofSize: 15.0, weight: .medium), color: white, in: rowRect.insetBy(dx: 14.0, dy: 9.0), alignment: .left)
            ayGrammDraw(row.1, font: UIFont.boldSystemFont(ofSize: 15.0), color: white, in: rowRect.insetBy(dx: 14.0, dy: 9.0), alignment: .right)
            y += 44.0
        }
        ayGrammDraw("AyGramm", font: UIFont.boldSystemFont(ofSize: 16.0), color: soft, in: CGRect(x: 20.0, y: 600.0, width: 320.0, height: 22.0), alignment: .center)
    }
}

func ayGrammShowChatStats(context: AccountContext, peer: EnginePeer?, peerId: EnginePeer.Id, present: @escaping (ViewController) -> Void, navigate: @escaping (EngineMessage.Id) -> Void, toast: @escaping (String) -> Void) {
    toast("Считаю статистику…")
    let title = peer?.compactDisplayTitle ?? "Чат"
    let isPrivate = peerId.namespace == Namespaces.Peer.CloudUser
    let _ = (AyGrammChatStats.compute(account: context.account, peerId: peerId)
    |> deliverOnMainQueue).start(next: { stats in
        var actions: [TextAlertAction] = [
            TextAlertAction(type: .genericAction, title: "Картинка для сторис", action: {
                if let image = ayGrammStatsCard(stats: stats, title: title, isPrivate: isPrivate) {
                    ayGrammShareImage(context: context, image: image)
                }
            })
        ]
        if let firstId = stats.firstMessageId {
            actions.append(TextAlertAction(type: .genericAction, title: "К первому сообщению", action: {
                navigate(firstId)
            }))
        }
        actions.append(TextAlertAction(type: .defaultAction, title: "Закрыть", action: {}))
        present(textAlertController(context: context, title: "Статистика: \(title)", text: ayGrammStatsText(stats, isPrivate: isPrivate), actions: actions, actionLayout: .vertical))
    })
}

// MARK: - Стереть мои сообщения

func ayGrammConfirmCleanup(context: AccountContext, peer: EnginePeer?, peerId: EnginePeer.Id, present: @escaping (ViewController) -> Void, toast: @escaping (String) -> Void) {
    let title = peer?.compactDisplayTitle ?? "чат"
    toast("Считаю ваши сообщения…")
    let _ = (AyGrammCleaner.count(account: context.account, peerId: peerId)
    |> deliverOnMainQueue).start(next: { count in
        if count == 0 {
            toast("Ваших сообщений в «\(title)» нет.")
            return
        }
        present(textAlertController(context: context, title: "Стереть мои сообщения", text: "Удалить у всех участников ваши сообщения в «\(title)»? Найдено: \(ayGrammNumber(count)). Вернуть их будет нельзя.", actions: [
            TextAlertAction(type: .genericAction, title: "Отмена", action: {}),
            TextAlertAction(type: .destructiveAction, title: "Удалить", action: {
                toast("Удаляю сообщения…")
                let _ = (AyGrammCleaner.deleteAll(account: context.account, peerId: peerId, progress: { _ in })
                |> deliverOnMainQueue).start(next: { deleted in
                    toast("Удалено сообщений: \(ayGrammNumber(deleted)).")
                })
            })
        ], actionLayout: .vertical))
    })
}

// MARK: - Подменю AyGramm в меню сообщения

private func ayGrammMenuIcon(_ name: String) -> (PresentationTheme) -> UIImage? {
    return { theme in
        return generateTintedImage(image: UIImage(systemName: name), color: theme.actionSheet.primaryTextColor)
    }
}

private func ayGrammBackItem(_ presentationData: PresentationData) -> ContextMenuItem {
    return .action(ContextMenuActionItem(text: presentationData.strings.Common_Back, textColor: .primary, icon: { theme in
        return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"), color: theme.actionSheet.primaryTextColor)
    }, iconSource: nil, iconPosition: .left, action: { c, _ in
        c?.popItems()
    }))
}

func ayGrammChatMenuItems(context: AccountContext, message: EngineMessage, peer: EnginePeer?, isCopyProtected: Bool, navigate: @escaping (EngineMessage.Id) -> Void, present: @escaping (ViewController) -> Void, toast: @escaping (String) -> Void) -> [ContextMenuItem] {
    let presentationData = context.sharedContext.currentPresentationData.with { $0 }
    let peerId = message.id.peerId
    var items: [ContextMenuItem] = [ayGrammBackItem(presentationData), .separator]

    items.append(.action(ContextMenuActionItem(text: "Статистика чата", icon: ayGrammMenuIcon("chart.bar.fill"), action: { c, _ in
        c?.dismiss(completion: {
            ayGrammShowChatStats(context: context, peer: peer, peerId: peerId, present: present, navigate: navigate, toast: toast)
        })
    })))
    items.append(.action(ContextMenuActionItem(text: "К первому сообщению", icon: ayGrammMenuIcon("arrow.up.to.line"), action: { c, _ in
        c?.dismiss(completion: {
            toast("Ищу первое сообщение…")
            let _ = (context.engine.messages.searchMessageIdByTimestamp(peerId: peerId, threadId: nil, timestamp: 1)
            |> deliverOnMainQueue).start(next: { id in
                if let id = id {
                    navigate(id)
                } else {
                    toast("Не удалось найти первое сообщение.")
                }
            })
        })
    })))
    if !isCopyProtected {
        items.append(.action(ContextMenuActionItem(text: "Скриншот сообщений", icon: ayGrammMenuIcon("camera.viewfinder"), action: { c, _ in
            var subItems: [ContextMenuItem] = [ayGrammBackItem(presentationData), .separator]
            for count in [1, 3, 5, 10] {
                let title = count == 1 ? "Только это сообщение" : "Это и \(count - 1) следующих"
                subItems.append(.action(ContextMenuActionItem(text: title, icon: { _ in
                    return nil
                }, action: { innerController, _ in
                    innerController?.dismiss(completion: {
                        ayGrammShareScreenshot(context: context, anchor: message.id, count: count, peer: peer)
                    })
                })))
            }
            c?.pushItems(items: .single(ContextController.Items(content: .list(subItems))))
        })))
    }
    if peerId.namespace != Namespaces.Peer.SecretChat {
        items.append(.action(ContextMenuActionItem(text: "Кружок из галереи", icon: ayGrammMenuIcon("video.circle.fill"), action: { c, _ in
            c?.dismiss(completion: {
                AyGrammRoundVideoPicker.present(context: context, peerId: peerId, toast: toast)
            })
        })))
    }
    if ayGrammIsGroup(peer) {
        items.append(.action(ContextMenuActionItem(text: "Стереть мои сообщения", textColor: .destructive, icon: { theme in
            return generateTintedImage(image: UIImage(systemName: "trash.fill"), color: theme.actionSheet.destructiveActionTextColor)
        }, action: { c, _ in
            c?.dismiss(completion: {
                ayGrammConfirmCleanup(context: context, peer: peer, peerId: peerId, present: present, toast: toast)
            })
        })))
    }
    if peerId.namespace == Namespaces.Peer.CloudUser && peerId != context.account.peerId, case let .user(user)? = peer, user.botInfo == nil {
        let excluded = AyGrammAutoReply.isExcluded(peerId)
        items.append(.action(ContextMenuActionItem(text: excluded ? "Автоответ: снова отвечать" : "Автоответ: не отвечать ему", icon: ayGrammMenuIcon(excluded ? "bubble.left.and.bubble.right.fill" : "nosign"), action: { c, _ in
            AyGrammAutoReply.setExcluded(peerId, !excluded)
            c?.dismiss(completion: {
                toast(excluded ? "Автоответ снова отвечает в этом чате." : "Автоответ больше не отвечает в этом чате.")
            })
        })))
    }
    return items
}
