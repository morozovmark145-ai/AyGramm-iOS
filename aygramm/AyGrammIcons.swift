import Foundation
import UIKit
import TelegramCore

// Иконки меню AyGramm в стиле настроек iOS: белый символ SF Symbols на цветном квадрате 30×30.
// Одна и та же иконка рисуется один раз и берётся из кэша, поэтому строки списка не перерисовываются.
enum AyGrammColor {
    static let red: UInt32 = 0xff3b30
    static let orange: UInt32 = 0xff9500
    static let yellow: UInt32 = 0xffcc00
    static let green: UInt32 = 0x34c759
    static let teal: UInt32 = 0x30b0c7
    static let blue: UInt32 = 0x007aff
    static let indigo: UInt32 = 0x5856d6
    static let purple: UInt32 = 0xaf52de
    static let pink: UInt32 = 0xff2d55
    static let gray: UInt32 = 0x8e8e93
}

private let ayGrammIconCache = NSCache<NSString, UIImage>()

func ayGrammIcon(_ symbol: String, _ color: UInt32) -> UIImage? {
    let key = "\(symbol)-\(color)" as NSString
    if let image = ayGrammIconCache.object(forKey: key) {
        return image
    }
    let size = CGSize(width: 30.0, height: 30.0)
    let background = UIColor(red: CGFloat((color >> 16) & 0xff) / 255.0, green: CGFloat((color >> 8) & 0xff) / 255.0, blue: CGFloat(color & 0xff) / 255.0, alpha: 1.0)
    let configuration = UIImage.SymbolConfiguration(pointSize: 15.0, weight: .semibold)
    let glyph = UIImage(systemName: symbol, withConfiguration: configuration)?.withTintColor(.white, renderingMode: .alwaysOriginal)
    let renderer = UIGraphicsImageRenderer(size: size)
    let image = renderer.image { _ in
        background.setFill()
        UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: size), cornerRadius: 7.0).fill()
        if let glyph = glyph {
            let scale = min(1.0, 19.0 / max(glyph.size.width, glyph.size.height))
            let glyphSize = CGSize(width: glyph.size.width * scale, height: glyph.size.height * scale)
            glyph.draw(in: CGRect(x: (size.width - glyphSize.width) / 2.0, y: (size.height - glyphSize.height) / 2.0, width: glyphSize.width, height: glyphSize.height))
        }
    }
    ayGrammIconCache.setObject(image, forKey: key)
    return image
}

// Иконка переключателя по его ключу в AyGrammSettings.
func ayGrammKeyIcon(_ key: String) -> UIImage? {
    switch key {
    case AyGrammSettings.hideOnlineKey:
        return ayGrammIcon("wifi.slash", AyGrammColor.indigo)
    case AyGrammSettings.hideReadKey:
        return ayGrammIcon("eye.slash", AyGrammColor.blue)
    case AyGrammSettings.hideTypingKey:
        return ayGrammIcon("keyboard", AyGrammColor.teal)
    case AyGrammSettings.hideStoryViewsKey:
        return ayGrammIcon("play.circle", AyGrammColor.purple)
    case AyGrammSettings.saveDeletedKey:
        return ayGrammIcon("trash", AyGrammColor.red)
    case AyGrammSettings.saveEditsKey:
        return ayGrammIcon("pencil", AyGrammColor.orange)
    case AyGrammSettings.silentSendKey:
        return ayGrammIcon("bell.slash", AyGrammColor.purple)
    case AyGrammSettings.pluginsEnabledKey:
        return ayGrammIcon("power", AyGrammColor.green)
    case AyGrammSettings.keepAliveKey:
        return ayGrammIcon("phone.fill", AyGrammColor.green)
    case AyGrammSettings.keepAliveBatteryKey:
        return ayGrammIcon("battery.25", AyGrammColor.yellow)
    case AyGrammSettings.unlimitedAccountsKey:
        return ayGrammIcon("person.2.fill", AyGrammColor.blue)
    case AyGrammSettings.decorationsKey:
        return ayGrammIcon("gift.fill", AyGrammColor.pink)
    case AyGrammSettings.tokensKey:
        return ayGrammIcon("curlybraces", AyGrammColor.orange)
    case AyGrammSettings.readAloudKey:
        return ayGrammIcon("speaker.wave.2.fill", AyGrammColor.teal)
    case AyGrammSettings.secondsKey:
        return ayGrammIcon("clock.fill", AyGrammColor.orange)
    case AyGrammSettings.showIdKey:
        return ayGrammIcon("number", AyGrammColor.blue)
    case AyGrammSettings.streamerKey:
        return ayGrammIcon("video.fill", AyGrammColor.red)
    case AyGrammSettings.filtersKey:
        return ayGrammIcon("nosign", AyGrammColor.red)
    case AyGrammSettings.exportKey:
        return ayGrammIcon("tray.and.arrow.down.fill", AyGrammColor.teal)
    case AyGrammSettings.fontButtonKey:
        return ayGrammIcon("hand.tap.fill", AyGrammColor.indigo)
    case AyGrammSettings.fontLiveKey:
        return ayGrammIcon("character.cursor.ibeam", AyGrammColor.purple)
    case AyGrammSettings.accountAgeKey:
        return ayGrammIcon("calendar", AyGrammColor.orange)
    case AyGrammSettings.mutualKey:
        return ayGrammIcon("arrow.left.arrow.right", AyGrammColor.green)
    case AyGrammSettings.chatToolsKey:
        return ayGrammIcon("sparkles", AyGrammColor.purple)
    case AyGrammSettings.bombKey:
        return ayGrammIcon("flame.fill", AyGrammColor.red)
    case AyGrammSettings.translateKey:
        return ayGrammIcon("globe", AyGrammColor.blue)
    case AyGrammSettings.cipherKey:
        return ayGrammIcon("lock.fill", AyGrammColor.indigo)
    case AyGrammSettings.voiceSendKey:
        return ayGrammIcon("waveform", AyGrammColor.pink)
    case AyGrammSettings.autoReplyKey:
        return ayGrammIcon("bubble.left.and.bubble.right.fill", AyGrammColor.green)
    case AyGrammSettings.autoReplyMarkKey:
        return ayGrammIcon("tag.fill", AyGrammColor.orange)
    case AyGrammSettings.autoReplyBackgroundKey:
        return ayGrammIcon("moon.fill", AyGrammColor.indigo)
    case AyGrammSettings.autoReplyScheduleKey:
        return ayGrammIcon("calendar.badge.clock", AyGrammColor.teal)
    default:
        return ayGrammIcon("gearshape", AyGrammColor.gray)
    }
}

// Логотип AyGramm для пункта «AyGramm» в настройках Telegram и для шапки меню AyGramm:
// четыре грани буквы «A» с иконки приложения на тёмно-фиолетовом градиенте. Заменяет лампочку «Советов».
func ayGrammLogoIcon(size side: CGFloat = 30.0) -> UIImage? {
    let key = "aygramm-logo-\(side)" as NSString
    if let image = ayGrammIconCache.object(forKey: key) {
        return image
    }
    let size = CGSize(width: side, height: side)
    let renderer = UIGraphicsImageRenderer(size: size)
    let image = renderer.image { context in
        UIBezierPath(roundedRect: CGRect(origin: CGPoint(), size: size), cornerRadius: side * 7.0 / 30.0).addClip()
        let colors = [UIColor(red: 0.30, green: 0.24, blue: 0.42, alpha: 1.0).cgColor, UIColor(red: 0.14, green: 0.11, blue: 0.21, alpha: 1.0).cgColor] as CFArray
        let locations: [CGFloat] = [0.0, 1.0]
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: locations) {
            context.cgContext.drawLinearGradient(gradient, start: CGPoint(x: 0.0, y: 0.0), end: CGPoint(x: 0.0, y: side), options: [])
        }
        // Координаты граней в долях стороны, сняты с AppIcon.png 1024×1024.
        let shards: [(UInt32, [CGPoint])] = [
            (0xe1e0e5, [CGPoint(x: 0.432, y: 0.172), CGPoint(x: 0.455, y: 0.184), CGPoint(x: 0.340, y: 0.745), CGPoint(x: 0.075, y: 0.745)]),
            (0xd6d6df, [CGPoint(x: 0.449, y: 0.414), CGPoint(x: 0.477, y: 0.425), CGPoint(x: 0.477, y: 0.860), CGPoint(x: 0.455, y: 0.876), CGPoint(x: 0.374, y: 0.772)]),
            (0xc3b6e3, [CGPoint(x: 0.551, y: 0.414), CGPoint(x: 0.523, y: 0.425), CGPoint(x: 0.523, y: 0.860), CGPoint(x: 0.545, y: 0.876), CGPoint(x: 0.626, y: 0.772)]),
            (0xa991d3, [CGPoint(x: 0.568, y: 0.172), CGPoint(x: 0.545, y: 0.184), CGPoint(x: 0.660, y: 0.745), CGPoint(x: 0.925, y: 0.745)]),
        ]
        for (color, points) in shards {
            let path = UIBezierPath()
            for (index, point) in points.enumerated() {
                let scaled = CGPoint(x: point.x * side, y: point.y * side)
                if index == 0 {
                    path.move(to: scaled)
                } else {
                    path.addLine(to: scaled)
                }
            }
            path.close()
            UIColor(red: CGFloat((color >> 16) & 0xff) / 255.0, green: CGFloat((color >> 8) & 0xff) / 255.0, blue: CGFloat(color & 0xff) / 255.0, alpha: 1.0).setFill()
            path.fill()
        }
    }
    ayGrammIconCache.setObject(image, forKey: key)
    return image
}
