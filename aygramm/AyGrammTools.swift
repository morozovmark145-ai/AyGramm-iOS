import Foundation

// Журнал вылетов: при падении AyGramm записывает причину и стек вызовов в файл.
// Swift-ошибки (принудительное извлечение nil, выход за границы массива) приходят как сигналы,
// ошибки Objective-C как исключения. После записи падение идёт дальше обычным путём.
public enum AyGrammCrashLog {
    static var installed = false

    static var fileUrl: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("aygramm-crash.txt")
    }

    public static func install() {
        if installed {
            return
        }
        installed = true
        NSSetUncaughtExceptionHandler { exception in
            AyGrammCrashLog.save("Исключение \(exception.name.rawValue): \(exception.reason ?? "")\n" + exception.callStackSymbols.joined(separator: "\n"))
        }
        for code in [SIGABRT, SIGILL, SIGSEGV, SIGFPE, SIGBUS, SIGTRAP] {
            signal(code) { received in
                AyGrammCrashLog.save("Сигнал \(received)\n" + Thread.callStackSymbols.joined(separator: "\n"))
                signal(received, SIG_DFL)
                raise(received)
            }
        }
    }

    static func save(_ text: String) {
        let header = "AyGramm 0.\(AyGrammSettings.currentVersion), \(Date())\n"
        try? (header + text).write(to: fileUrl, atomically: false, encoding: .utf8)
    }

    public static var lastReport: String? {
        return try? String(contentsOf: fileUrl, encoding: .utf8)
    }

    public static func clear() {
        try? FileManager.default.removeItem(at: fileUrl)
    }
}

// Резервная копия: настройки AyGramm, свои плагины и украшения в одном тексте JSON.
// Флаг блокировки автором не копируется и не восстанавливается.
public enum AyGrammBackup {
    static let skippedKeys: Set<String> = ["AyGrammBanned"]

    public static func export() -> String? {
        var defaults: [String: Any] = [:]
        for (key, value) in UserDefaults.standard.dictionaryRepresentation() where key.hasPrefix("AyGramm") && !skippedKeys.contains(key) {
            if JSONSerialization.isValidJSONObject([value]) {
                defaults[key] = value
            }
        }
        var plugins: [String: String] = [:]
        if let files = try? FileManager.default.contentsOfDirectory(at: AyGrammPlugins.directory, includingPropertiesForKeys: nil) {
            for file in files {
                if let text = try? String(contentsOf: file, encoding: .utf8) {
                    plugins[file.lastPathComponent] = text
                }
            }
        }
        var root: [String: Any] = ["aygrammBackup": 1, "defaults": defaults, "plugins": plugins]
        if let data = try? Data(contentsOf: AyGrammDecorations.fileUrl), let text = String(data: data, encoding: .utf8) {
            root["decorations"] = text
        }
        guard let data = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys]) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    public static func restore(_ text: String) -> Bool {
        guard let data = text.data(using: .utf8), let root = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any], root["aygrammBackup"] != nil else {
            return false
        }
        if let defaults = root["defaults"] as? [String: Any] {
            for (key, value) in defaults where key.hasPrefix("AyGramm") && !skippedKeys.contains(key) {
                UserDefaults.standard.set(value, forKey: key)
            }
        }
        if let plugins = root["plugins"] as? [String: String] {
            try? FileManager.default.createDirectory(at: AyGrammPlugins.directory, withIntermediateDirectories: true, attributes: nil)
            for (name, code) in plugins where !name.contains("/") && !name.hasPrefix(".") {
                try? code.write(to: AyGrammPlugins.directory.appendingPathComponent(name), atomically: true, encoding: .utf8)
            }
        }
        if let decorations = root["decorations"] as? String, let data = decorations.data(using: .utf8) {
            try? data.write(to: AyGrammDecorations.fileUrl, options: .atomic)
            AyGrammDecorations.notifyUpdated()
        }
        return true
    }
}
