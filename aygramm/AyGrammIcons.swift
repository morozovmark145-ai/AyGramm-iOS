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
    default:
        return ayGrammIcon("gearshape", AyGrammColor.gray)
    }
}
