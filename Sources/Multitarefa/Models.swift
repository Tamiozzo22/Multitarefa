import Foundation

/// Uma tarefa da fila.
struct TaskItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    /// Segundos restantes na rodada atual.
    var remaining: Int
    /// Tempo total gasto nesta tarefa (todas as rodadas somadas).
    var totalSeconds: Int = 0
    /// Quantas rodadas (turnos) a tarefa já teve.
    var rounds: Int = 0
    /// Anotação "onde parei".
    var note: String = ""
    var createdAt: Date = Date()
    var completedAt: Date? = nil
    var archivedAt: Date? = nil
}

/// Pedido de anotação mostrado quando uma rodada termina.
struct PendingNote: Equatable {
    let taskID: UUID
    let title: String
}

/// Estado salvo em disco.
struct SavedState: Codable {
    var queue: [TaskItem]
    var archived: [TaskItem]
    var completed: [TaskItem]
}

enum Format {
    /// 07:32
    static func clock(_ seconds: Int) -> String {
        let s = max(0, seconds)
        return String(format: "%02ld:%02ld", s / 60, s % 60)
    }

    /// 1 h 05 min · 12 min · 45 s
    static func duration(_ seconds: Int) -> String {
        let s = max(0, seconds)
        if s < 60 { return "\(s) s" }
        let minutes = s / 60
        if minutes < 60 { return "\(minutes) min" }
        return String(format: "%ld h %02ld min", minutes / 60, minutes % 60)
    }

    static func date(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateStyle = .short
        f.timeStyle = .short
        return f.string(from: date)
    }
}
