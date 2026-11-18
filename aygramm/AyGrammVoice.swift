import Foundation

// Встроенный плагин «Изменение голоса»: голосовое сообщение меняет звучание ещё при записи.
// Запись идёт пакетами по 960 отсчётов (16 кГц, 16 бит, моно). Эффект меняет отсчёты до кодека Opus,
// поэтому собеседник слышит уже изменённый голос, а прослушивание перед отправкой звучит так же.
public enum AyGrammVoice {
    static let key = "AyGrammVoiceEffect"

    // Название и подпись для меню. Номер эффекта совпадает с номером строки.
    public static let effects: [(String, String)] = [
        ("Без изменений", "Обычный голос"),
        ("Высокий голос", "Выше на 6 полутонов"),
        ("Бурундук", "Выше на 11 полутонов"),
        ("Низкий голос", "Ниже на 5 полутонов"),
        ("Монстр", "Ниже на 10 полутонов"),
        ("Робот", "Металлический голос"),
        ("Эхо", "Повтор через 0,25 секунды"),
    ]

    public static var selectedIndex: Int {
        get {
            let value = UserDefaults.standard.integer(forKey: key)
            return value >= 0 && value < effects.count ? value : 0
        }
        set {
            UserDefaults.standard.set(newValue, forKey: key)
        }
    }

    public static var selectedName: String {
        return effects[selectedIndex].0
    }

    static var processor: AyGrammVoiceProcessor?
    static var lastPacketTime: Double = 0

    // Вызывается очередью записи для каждого пакета. Пауза больше секунды значит новую запись:
    // эффект начинает с чистого состояния, хвост прошлого сообщения не попадает в новое.
    public static func process(_ samples: UnsafeMutablePointer<Int16>, count: Int) {
        let effect = selectedIndex
        if effect == 0 {
            processor = nil
            return
        }
        let now = Date().timeIntervalSince1970
        if let current = processor, current.effect == effect, now - lastPacketTime < 1.0 {
            current.process(samples, count: count)
        } else {
            let created = AyGrammVoiceProcessor(effect: effect)
            processor = created
            created.process(samples, count: count)
        }
        lastPacketTime = now
    }
}

final class AyGrammVoiceProcessor {
    let effect: Int
    let ratio: Double
    // Сдвиг высоты: две читающие головки идут по кольцевому буферу со скоростью ratio
    // и плавно сменяют друг друга в окне 100 мс, поэтому скорость речи не меняется.
    let window: Double = 1600.0
    var buffer = [Float](repeating: 0.0, count: 4096)
    var writeIndex = 0
    var delay: Double = 0.0
    // Эхо: задержка 4000 отсчётов, это 0,25 секунды.
    var echo = [Float](repeating: 0.0, count: 4000)
    var echoIndex = 0
    // Робот: умножение на синус 60 Гц, за 16000 отсчётов проходит ровно 60 периодов.
    var robotPhase = 0

    init(effect: Int) {
        self.effect = effect
        switch effect {
        case 1:
            self.ratio = 1.45
        case 2:
            self.ratio = 1.9
        case 3:
            self.ratio = 0.75
        case 4:
            self.ratio = 0.55
        default:
            self.ratio = 1.0
        }
    }

    func read(_ delay: Double) -> Float {
        let count = self.buffer.count
        let position = Double(self.writeIndex) - delay
        let base = floor(position)
        let fraction = Float(position - base)
        var first = Int(base) % count
        if first < 0 {
            first += count
        }
        let second = (first + 1) % count
        return self.buffer[first] * (1.0 - fraction) + self.buffer[second] * fraction
    }

    func shift(_ input: Float) -> Float {
        self.buffer[self.writeIndex] = input
        self.delay += 1.0 - self.ratio
        if self.delay < 0.0 {
            self.delay += self.window
        } else if self.delay >= self.window {
            self.delay -= self.window
        }
        var otherDelay = self.delay + self.window / 2.0
        if otherDelay >= self.window {
            otherDelay -= self.window
        }
        let weight = Float(1.0 - abs(2.0 * self.delay / self.window - 1.0))
        let output = self.read(self.delay) * weight + self.read(otherDelay) * (1.0 - weight)
        self.writeIndex = (self.writeIndex + 1) % self.buffer.count
        return output
    }

    func process(_ samples: UnsafeMutablePointer<Int16>, count: Int) {
        for i in 0 ..< count {
            let input = Float(samples[i]) / 32768.0
            var output: Float
            switch self.effect {
            case 1, 2, 3, 4:
                output = self.shift(input)
            case 5:
                let angle = 2.0 * Float.pi * 60.0 * Float(self.robotPhase) / 16000.0
                output = input * (0.25 + 0.75 * sin(angle))
                self.robotPhase = (self.robotPhase + 1) % 16000
            case 6:
                let delayed = self.echo[self.echoIndex]
                output = input + 0.5 * delayed
                self.echo[self.echoIndex] = input + 0.35 * delayed
                self.echoIndex = (self.echoIndex + 1) % self.echo.count
            default:
                output = input
            }
            let clamped = max(Float(-1.0), min(Float(1.0), output))
            samples[i] = Int16(clamped * 32767.0)
        }
    }
}
