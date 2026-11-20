import Foundation

/// Uma anotação da tarefa, com data e hora.
struct NoteEntry: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var text: String
    var date: Date = Date()
}

/// Uma subtarefa (item de checklist dentro da tarefa).
struct Subtask: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var text: String
    var done: Bool = false
    var createdAt: Date = Date()
    var doneAt: Date? = nil
}

/// Uma tarefa.
struct TaskItem: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    /// Duração de cada rodada desta tarefa, em segundos.
    var durationSeconds: Int
    /// Segundos restantes na rodada atual.
    var remaining: Int
    /// Tempo total gasto nesta tarefa (todas as rodadas somadas).
    var totalSeconds: Int = 0
    /// Quantas rodadas a tarefa já teve.
    var rounds: Int = 0
    /// Anotações, da mais antiga para mais nova.
    var notes: [NoteEntry] = []
    var createdAt: Date = Date()
    var completedAt: Date? = nil
    var archivedAt: Date? = nil
    /// Tags (ids de TagDef).
    var tagIDs: [UUID] = []
    /// Quando foi para lixeira e de onde veio.
    var deletedAt: Date? = nil
    var deletedFrom: TaskOrigin? = nil
    /// Subtarefas (checklist).
    var subtasks: [Subtask] = []
    /// Agendamento: data em que a tarefa entra na fila.
    var scheduledFor: Date? = nil
    /// Se o agendamento tem horário (senão, entra no início do dia).
    var scheduleHasTime: Bool = false

    init(title: String, durationSeconds: Int) {
        self.title = title
        self.durationSeconds = durationSeconds
        self.remaining = durationSeconds
    }

    var latestNote: NoteEntry? { notes.last }
    var subtasksDone: Int { subtasks.filter { $0.done }.count }

    /// Momento em que a tarefa agendada deve entrar na fila.
    var releaseDate: Date? {
        guard let d = scheduledFor else { return nil }
        return scheduleHasTime ? d : Calendar.current.startOfDay(for: d)
    }
    var isTimeUp: Bool { remaining <= 0 }

    // Lê também o formato da versão 1 (campo "note" único, sem duração por tarefa).
    private enum CodingKeys: String, CodingKey {
        case id, title, durationSeconds, remaining, totalSeconds, rounds, notes
        case createdAt, completedAt, archivedAt
        case tagIDs, deletedAt, deletedFrom
        case subtasks, scheduledFor, scheduleHasTime
        case note
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decode(String.self, forKey: .title)
        durationSeconds = try c.decodeIfPresent(Int.self, forKey: .durationSeconds) ?? TaskStore.defaultDuration
        remaining = try c.decodeIfPresent(Int.self, forKey: .remaining) ?? durationSeconds
        totalSeconds = try c.decodeIfPresent(Int.self, forKey: .totalSeconds) ?? 0
        rounds = try c.decodeIfPresent(Int.self, forKey: .rounds) ?? 0
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        completedAt = try c.decodeIfPresent(Date.self, forKey: .completedAt)
        archivedAt = try c.decodeIfPresent(Date.self, forKey: .archivedAt)
        tagIDs = try c.decodeIfPresent([UUID].self, forKey: .tagIDs) ?? []
        deletedAt = try c.decodeIfPresent(Date.self, forKey: .deletedAt)
        deletedFrom = try c.decodeIfPresent(TaskOrigin.self, forKey: .deletedFrom)
        subtasks = try c.decodeIfPresent([Subtask].self, forKey: .subtasks) ?? []
        scheduledFor = try c.decodeIfPresent(Date.self, forKey: .scheduledFor)
        scheduleHasTime = try c.decodeIfPresent(Bool.self, forKey: .scheduleHasTime) ?? false
        if let list = try c.decodeIfPresent([NoteEntry].self, forKey: .notes) {
            notes = list
        } else if let old = try c.decodeIfPresent(String.self, forKey: .note), !old.isEmpty {
            notes = [NoteEntry(text: old)]
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(durationSeconds, forKey: .durationSeconds)
        try c.encode(remaining, forKey: .remaining)
        try c.encode(totalSeconds, forKey: .totalSeconds)
        try c.encode(rounds, forKey: .rounds)
        try c.encode(notes, forKey: .notes)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encodeIfPresent(completedAt, forKey: .completedAt)
        try c.encodeIfPresent(archivedAt, forKey: .archivedAt)
        try c.encode(tagIDs, forKey: .tagIDs)
        try c.encodeIfPresent(deletedAt, forKey: .deletedAt)
        try c.encodeIfPresent(deletedFrom, forKey: .deletedFrom)
        try c.encode(subtasks, forKey: .subtasks)
        try c.encodeIfPresent(scheduledFor, forKey: .scheduledFor)
        try c.encode(scheduleHasTime, forKey: .scheduleHasTime)
    }
}

/// De onde a tarefa veio (para voltar da lixeira para o lugar certo).
enum TaskOrigin: String, Codable {
    case queue, scheduled, archived, completed

    var label: String {
        switch self {
        case .queue: return "Fila"
        case .scheduled: return "Agendadas"
        case .archived: return "Arquivadas"
        case .completed: return "Histórico"
        }
    }
}

/// Uma tag criada por você.
struct TagDef: Identifiable, Codable, Equatable, Hashable {
    var id: UUID = UUID()
    var name: String
    var color: Int
}

/// Troca de tarefa esperando você anotar onde parou.
struct PendingSwitch: Equatable {
    let taskID: UUID
    let title: String
    /// Pra qual tarefa ir (nil = próxima da fila).
    let targetID: UUID?
    /// true quando foi aberta porque o tempo acabou.
    let automatic: Bool
}

/// Tarefa sendo editada (para a janela de edição).
struct EditTarget: Identifiable, Equatable {
    let id: UUID
}

/// Estado salvo em disco.
struct SavedState: Codable {
    var queue: [TaskItem]
    var archived: [TaskItem]
    var completed: [TaskItem]
    var trash: [TaskItem]
    var tags: [TagDef]
    var scheduled: [TaskItem]

    init(queue: [TaskItem], archived: [TaskItem], completed: [TaskItem], trash: [TaskItem],
         tags: [TagDef], scheduled: [TaskItem]) {
        self.scheduled = scheduled
        self.queue = queue
        self.archived = archived
        self.completed = completed
        self.trash = trash
        self.tags = tags
    }

    private enum CodingKeys: String, CodingKey {
        case queue, archived, completed, trash, tags, scheduled
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        queue = try c.decodeIfPresent([TaskItem].self, forKey: .queue) ?? []
        archived = try c.decodeIfPresent([TaskItem].self, forKey: .archived) ?? []
        completed = try c.decodeIfPresent([TaskItem].self, forKey: .completed) ?? []
        trash = try c.decodeIfPresent([TaskItem].self, forKey: .trash) ?? []
        tags = try c.decodeIfPresent([TagDef].self, forKey: .tags) ?? []
        scheduled = try c.decodeIfPresent([TaskItem].self, forKey: .scheduled) ?? []
    }
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

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "dd/MM 'às' HH:mm"
        return f
    }()

    static func date(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.dateFormat = "EEEE, dd 'de' MMMM"
        return f
    }()

    /// "Hoje", "Amanhã" ou "sexta-feira, 21 de novembro".
    static func day(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Hoje" }
        if cal.isDateInTomorrow(date) { return "Amanhã" }
        let text = dayFormatter.string(from: date)
        return text.prefix(1).uppercased() + text.dropFirst()
    }

    /// "Amanhã às 14:00" ou "Amanhã".
    static func schedule(_ date: Date, hasTime: Bool) -> String {
        hasTime ? "\(day(date)) às \(timeFormatter.string(from: date))" : day(date)
    }
}
