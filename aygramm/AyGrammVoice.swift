import Foundation

// Встроенный плагин «Изменение голоса»: голосовое сообщение меняет звучание ещё при записи.
// Запись идёт пакетами по 960 отсчётов (48 кГц, 16 бит, моно). Эффект меняет отсчёты до кодека Opus,
// поэтому собеседник слышит уже изменённый голос, а прослушивание перед отправкой звучит так же.
public enum AyGrammVoice {
    static let key = "AyGrammVoiceEffect"

    // Название и подпись для меню. Номер эффекта совпадает с номером строки. Номера 0...6 остались
    // со сборки 25, поэтому выбранный раньше эффект не меняется.
    public static let effects: [(String, String)] = [
        ("Без изменений", "Обычный голос"),
        ("Высокий голос", "Выше на 6 полутонов"),
        ("Бурундук", "Выше на 11 полутонов"),
        ("Низкий голос", "Ниже на 5 полутонов"),
        ("Монстр", "Ниже на 10 полутонов"),
        ("Робот", "Металлический голос"),
        ("Эхо", "Повтор через 0,25 секунды"),
        ("Шёпот", "Голос без тона, как шёпот"),
        ("Телефон", "Узкий звук старой линии"),
        ("Рация", "Хрип и шум рации"),
        ("Мегафон", "Громкий рупор"),
        ("Старое радио", "Приёмник с треском"),
        ("Под водой", "Глухой дрожащий голос"),
        ("Пещера", "Отражения от каменных стен"),
        ("Стадион", "Огромный зал с долгим эхом"),
        ("Хор", "Три голоса вместо одного"),
        ("Вибрато", "Дрожащий голос"),
        ("Инопланетянин", "Выше на 4 полутона, с металлом"),
        ("Злодей", "Ниже на 4 полутона, с эхом"),
        ("Ребёнок", "Выше на 8 полутонов"),
        ("Гигант", "Ниже на 8 полутонов, с эхом"),
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

    // Проигрывает фразу-образец с эффектом. Задаётся при запуске из TelegramUI, где есть синтез речи.
    public static var previewPlayer: ((Int) -> Void)?

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

    // Весь звук сразу, для «Отправить голосом»: эффект начинает с чистого состояния.
    public static func processWhole(_ samples: UnsafeMutablePointer<Int16>, count: Int) {
        processWhole(samples, count: count, effect: selectedIndex)
    }

    // То же для образца в меню: эффект задаётся номером.
    public static func processWhole(_ samples: UnsafeMutablePointer<Int16>, count: Int, effect: Int) {
        if effect <= 0 || effect >= effects.count || count == 0 {
            return
        }
        AyGrammVoiceProcessor(effect: effect).process(samples, count: count)
    }
}

// Фильтр второго порядка по формулам RBJ для 48 кГц: срез низких или высоких частот.
struct AyGrammBiquad {
    var b0: Float = 1.0
    var b1: Float = 0.0
    var b2: Float = 0.0
    var a1: Float = 0.0
    var a2: Float = 0.0
    var x1: Float = 0.0
    var x2: Float = 0.0
    var y1: Float = 0.0
    var y2: Float = 0.0

    init() {
    }

    init(lowPass frequency: Float) {
        let w = 2.0 * Float.pi * frequency / 48000.0
        let c = cos(w)
        let alpha = sin(w) / 1.4142
        let a0 = 1.0 + alpha
        self.b0 = (1.0 - c) / 2.0 / a0
        self.b1 = (1.0 - c) / a0
        self.b2 = (1.0 - c) / 2.0 / a0
        self.a1 = -2.0 * c / a0
        self.a2 = (1.0 - alpha) / a0
    }

    init(highPass frequency: Float) {
        let w = 2.0 * Float.pi * frequency / 48000.0
        let c = cos(w)
        let alpha = sin(w) / 1.4142
        let a0 = 1.0 + alpha
        self.b0 = (1.0 + c) / 2.0 / a0
        self.b1 = -(1.0 + c) / a0
        self.b2 = (1.0 + c) / 2.0 / a0
        self.a1 = -2.0 * c / a0
        self.a2 = (1.0 - alpha) / a0
    }

    mutating func process(_ x: Float) -> Float {
        let y = self.b0 * x + self.b1 * self.x1 + self.b2 * self.x2 - self.a1 * self.y1 - self.a2 * self.y2
        self.x2 = self.x1
        self.x1 = x
        self.y2 = self.y1
        self.y1 = y
        return y
    }
}

// Реверберация по схеме Шрёдера: 4 гребенчатых фильтра с затуханием верхов и 2 фазовых фильтра.
// size растягивает задержки (больше помещение), feedback задаёт длину хвоста, wet долю отражений.
final class AyGrammReverb {
    var combs: [[Float]]
    var combIndex: [Int] = [0, 0, 0, 0]
    var combStore: [Float] = [0.0, 0.0, 0.0, 0.0]
    var allpasses: [[Float]]
    var allpassIndex: [Int] = [0, 0]
    let feedback: Float
    let wet: Float
    let damp: Float = 0.3

    init(size: Float, feedback: Float, wet: Float) {
        self.combs = [1694, 1760, 1623, 1548].map { [Float](repeating: 0.0, count: Int(Float($0) * size)) }
        self.allpasses = [605, 480].map { [Float](repeating: 0.0, count: $0) }
        self.feedback = feedback
        self.wet = wet
    }

    func process(_ input: Float) -> Float {
        var sum: Float = 0.0
        for i in 0 ..< 4 {
            let index = self.combIndex[i]
            let output = self.combs[i][index]
            self.combStore[i] = output * (1.0 - self.damp) + self.combStore[i] * self.damp
            self.combs[i][index] = input * 0.35 + self.combStore[i] * self.feedback
            sum += output
            self.combIndex[i] = (index + 1) % self.combs[i].count
        }
        var value = sum * 0.25
        for i in 0 ..< 2 {
            let index = self.allpassIndex[i]
            let buffered = self.allpasses[i][index]
            self.allpasses[i][index] = value + buffered * 0.5
            value = buffered - value
            self.allpassIndex[i] = (index + 1) % self.allpasses[i].count
        }
        return input * (1.0 - self.wet * 0.5) + value * self.wet * 2.0
    }
}

// Линия задержки на 4096 отсчётов (85 мс) с чтением между отсчётами: хор, вибрато, «под водой».
final class AyGrammDelayLine {
    var buffer = [Float](repeating: 0.0, count: 4096)
    var index = 0

    func write(_ value: Float) {
        self.buffer[self.index] = value
        self.index = (self.index + 1) % self.buffer.count
    }

    func read(_ delay: Float) -> Float {
        let count = self.buffer.count
        var position = Float(self.index) - 1.0 - delay
        while position < 0.0 {
            position += Float(count)
        }
        let base = Int(position)
        let fraction = position - Float(base)
        let first = base % count
        let second = (first + 1) % count
        return self.buffer[first] * (1.0 - fraction) + self.buffer[second] * fraction
    }
}

final class AyGrammVoiceProcessor {
    let effect: Int
    let ratio: Double
    // Сдвиг высоты: две читающие головки идут по кольцевому буферу со скоростью ratio
    // и плавно сменяют друг друга в окне 100 мс (4800 отсчётов), поэтому скорость речи не меняется.
    let window: Double = 4800.0
    var buffer = [Float](repeating: 0.0, count: 8192)
    var writeIndex = 0
    var delay: Double = 0.0
    // Эхо: задержка 12000 отсчётов, это 0,25 секунды.
    var echo = [Float](repeating: 0.0, count: 12000)
    var echoIndex = 0
    // Робот: умножение на синус 60 Гц, за 48000 отсчётов проходит ровно 60 периодов.
    var robotPhase = 0
    // Инопланетянин: несущая 430 Гц, за 48000 отсчётов ровно 430 периодов.
    var carrier = 0
    var low = AyGrammBiquad()
    var high = AyGrammBiquad()
    var reverb: AyGrammReverb?
    let line = AyGrammDelayLine()
    var lfo: Float = 0.0
    var seed: UInt32 = 0x9e3779b9

    init(effect: Int) {
        self.effect = effect
        var ratio = 1.0
        switch effect {
        case 1:
            ratio = 1.45
        case 2:
            ratio = 1.9
        case 3:
            ratio = 0.75
        case 4:
            ratio = 0.55
        case 7:
            self.high = AyGrammBiquad(highPass: 400.0)
            self.low = AyGrammBiquad(lowPass: 6000.0)
        case 8:
            self.high = AyGrammBiquad(highPass: 300.0)
            self.low = AyGrammBiquad(lowPass: 3400.0)
        case 9:
            self.high = AyGrammBiquad(highPass: 500.0)
            self.low = AyGrammBiquad(lowPass: 2600.0)
        case 10:
            self.high = AyGrammBiquad(highPass: 600.0)
            self.low = AyGrammBiquad(lowPass: 3200.0)
        case 11:
            self.high = AyGrammBiquad(highPass: 400.0)
            self.low = AyGrammBiquad(lowPass: 3000.0)
        case 12:
            self.low = AyGrammBiquad(lowPass: 450.0)
        case 13:
            self.reverb = AyGrammReverb(size: 1.0, feedback: 0.8, wet: 0.45)
        case 14:
            self.reverb = AyGrammReverb(size: 1.6, feedback: 0.88, wet: 0.55)
        case 17:
            ratio = 1.26
        case 18:
            ratio = 0.794
            self.low = AyGrammBiquad(lowPass: 3500.0)
            self.reverb = AyGrammReverb(size: 0.8, feedback: 0.7, wet: 0.3)
        case 19:
            ratio = 1.587
        case 20:
            ratio = 0.63
            self.reverb = AyGrammReverb(size: 1.3, feedback: 0.8, wet: 0.35)
        default:
            break
        }
        self.ratio = ratio
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

    // Белый шум от -1 до 1 (xorshift32).
    func noise() -> Float {
        self.seed ^= self.seed << 13
        self.seed ^= self.seed >> 17
        self.seed ^= self.seed << 5
        return Float(self.seed) / 2147483648.0 - 1.0
    }

    // Медленный генератор для хора, вибрато и «под водой»: фаза от 0 до 2π.
    func advance(_ frequency: Float) -> Float {
        self.lfo += 2.0 * Float.pi * frequency / 48000.0
        if self.lfo > 2.0 * Float.pi {
            self.lfo -= 2.0 * Float.pi
        }
        return self.lfo
    }

    func processSample(_ input: Float) -> Float {
        switch self.effect {
        case 1, 2, 3, 4, 19:
            return self.shift(input)
        case 5:
            let angle = 2.0 * Float.pi * 60.0 * Float(self.robotPhase) / 48000.0
            self.robotPhase = (self.robotPhase + 1) % 48000
            return input * (0.25 + 0.75 * sin(angle))
        case 6:
            let delayed = self.echo[self.echoIndex]
            self.echo[self.echoIndex] = input + 0.35 * delayed
            self.echoIndex = (self.echoIndex + 1) % self.echo.count
            return input + 0.5 * delayed
        case 7:
            // Шёпот: огибающая голоса умножается на шум, тон голоса пропадает.
            let band = self.high.process(input)
            return self.low.process(band * self.noise() * 2.2)
        case 8:
            let band = self.low.process(self.high.process(input))
            return tanh(band * 2.0) * 0.8
        case 9:
            let band = self.low.process(self.high.process(input))
            return max(Float(-0.35), min(Float(0.35), band * 4.0)) * 1.8 + self.noise() * 0.015
        case 10:
            let band = self.low.process(self.high.process(input * 1.5))
            return tanh(band * 5.0) * 0.6
        case 11:
            let band = self.low.process(self.high.process(input))
            var crackle: Float = 0.0
            if self.noise() > 0.9993 {
                crackle = self.noise() * 0.35
            }
            return band * 1.3 + self.noise() * 0.012 + crackle
        case 12:
            // Под водой: глухой фильтр и медленное колебание задержки, голос плавает.
            let phase = self.advance(0.9)
            self.line.write(self.low.process(input) * 1.6)
            return self.line.read(120.0 + 90.0 * sin(phase))
        case 13, 14:
            return self.reverb?.process(input) ?? input
        case 15:
            // Хор: три копии голоса с плавающей задержкой от 20 до 37 мс.
            let phase = self.advance(0.4)
            self.line.write(input)
            let first = self.line.read(1100.0 + 150.0 * sin(phase))
            let second = self.line.read(1350.0 + 150.0 * sin(phase + 2.1))
            let third = self.line.read(1600.0 + 150.0 * sin(phase + 4.2))
            return input * 0.55 + (first + second + third) * 0.3
        case 16:
            // Вибрато: задержка колеблется 6 раз в секунду, высота голоса дрожит на 1,3 полутона.
            let phase = self.advance(6.0)
            self.line.write(input)
            return self.line.read(200.0 + 100.0 * sin(phase))
        case 17:
            let shifted = self.shift(input)
            let angle = 2.0 * Float.pi * 430.0 * Float(self.carrier) / 48000.0
            self.carrier = (self.carrier + 1) % 48000
            return shifted * 0.5 + shifted * sin(angle) * 0.7
        case 18:
            let driven = tanh(self.low.process(self.shift(input)) * 1.8)
            return self.reverb?.process(driven) ?? driven
        case 20:
            let shifted = self.shift(input)
            return self.reverb?.process(shifted) ?? shifted
        default:
            return input
        }
    }

    func process(_ samples: UnsafeMutablePointer<Int16>, count: Int) {
        for i in 0 ..< count {
            let output = self.processSample(Float(samples[i]) / 32768.0)
            let clamped = max(Float(-1.0), min(Float(1.0), output))
            samples[i] = Int16(clamped * 32767.0)
        }
    }
}
