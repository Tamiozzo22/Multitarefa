import AppKit
import Foundation
import UserNotifications

/// Sons do sistema (já existem em todo Mac).
enum Sound {
    private static var playing: [NSSound] = []

    private static func play(_ name: String) {
        let path = "/System/Library/Sounds/\(name).aiff"
        guard let sound = NSSound(contentsOfFile: path, byReference: true) else {
            NSSound.beep()
            return
        }
        playing.append(sound)
        if playing.count > 10 { playing.removeFirst(playing.count - 10) }
        sound.play()
    }

    /// Duração aproximada de uma sequência de alarme (segundos).
    static let alarmLength: Double = 3.3

    /// Alarme de fim de rodada: toca 3 vezes, enquanto `isActive` for verdadeiro.
    static func alarm(isActive: @escaping () -> Bool) {
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 1.1) {
                if isActive() { play("Glass") }
            }
        }
    }

    static func stopAll() {
        for s in playing where s.isPlaying { s.stop() }
        playing.removeAll()
    }

    /// Aviso suave de 1 minuto.
    static func warning() {
        play("Tink")
    }
}

/// Notificações do macOS.
enum Notifier {
    /// Só funciona quando o app roda como .app (com bundle identifier).
    static var available: Bool { Bundle.main.bundleIdentifier != nil }

    static func requestPermission() {
        guard available else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func send(title: String, body: String) {
        guard available else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { _ in }
    }
}

/// Salva e carrega as tarefas em ~/Library/Application Support/Multitarefa/state.json
enum Persistence {
    static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
        return base.appendingPathComponent("Multitarefa", isDirectory: true)
            .appendingPathComponent("state.json")
    }

    static func load() -> SavedState? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(SavedState.self, from: data)
    }

    static func save(_ state: SavedState) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]
        guard let data = try? encoder.encode(state) else { return }
        let dir = fileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }
}
