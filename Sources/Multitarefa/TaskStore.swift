import Foundation
import SwiftUI

/// Toda a lógica do app: fila em rodízio, timer, arquivo e histórico.
/// A tarefa atual é sempre a primeira da fila.
final class TaskStore: ObservableObject {
    /// Duração de cada rodada. Mude aqui se quiser outro padrão.
    static let slotSeconds = 10 * 60
    /// Quando avisar que a rodada está acabando.
    static let warningSeconds = 60

    @Published var queue: [TaskItem] = []
    @Published var archived: [TaskItem] = []
    @Published var completed: [TaskItem] = []
    @Published var isRunning = false
    @Published var pendingNote: PendingNote?

    private var timer: Timer?
    private var lastTick = Date()
    private var ticksSinceSave = 0

    init() {
        if let saved = Persistence.load() {
            queue = saved.queue
            archived = saved.archived
            completed = saved.completed
        }
        let t = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    // MARK: - Leitura

    var current: TaskItem? { queue.first }

    var menuBarText: String {
        guard let c = current else { return "" }
        return Format.clock(c.remaining)
    }

    var completedTotalSeconds: Int {
        completed.reduce(0) { $0 + $1.totalSeconds }
    }

    // MARK: - Timer

    func start() {
        guard !queue.isEmpty else { return }
        lastTick = Date()
        isRunning = true
    }

    func pause() {
        isRunning = false
        save()
    }

    func toggleRunning() {
        isRunning ? pause() : start()
    }

    private func tick() {
        guard isRunning, !queue.isEmpty else { return }
        let now = Date()
        let elapsed = Int(now.timeIntervalSince(lastTick))
        guard elapsed >= 1 else { return }
        lastTick = lastTick.addingTimeInterval(Double(elapsed))

        // Se o Mac dormiu, não conta mais que o restante da rodada.
        let before = queue[0].remaining
        let used = min(elapsed, before)
        queue[0].remaining -= used
        queue[0].totalSeconds += used
        let after = queue[0].remaining

        if before > Self.warningSeconds && after <= Self.warningSeconds && after > 0 {
            Sound.warning()
            Notifier.send(title: "Falta 1 minuto",
                          body: "Vá fechando o raciocínio em \"\(queue[0].title)\".")
        }

        if after <= 0 {
            timeUp()
        } else {
            ticksSinceSave += 1
            if ticksSinceSave >= 15 { save() }
        }
    }

    private func timeUp() {
        guard let finished = queue.first else { return }
        rotate()
        Sound.alarm()
        if let next = queue.first {
            let body = next.id == finished.id
                ? "Mais uma rodada em \"\(next.title)\"."
                : "Agora: \"\(next.title)\"."
            Notifier.send(title: "Tempo de \"\(finished.title)\" acabou", body: body)
        }
        pendingNote = PendingNote(taskID: finished.id, title: finished.title)
        save()
    }

    /// Manda a tarefa atual pro fim da fila e zera a contagem dela.
    private func rotate() {
        guard !queue.isEmpty else { return }
        var t = queue.removeFirst()
        t.remaining = Self.slotSeconds
        t.rounds += 1
        queue.append(t)
        lastTick = Date()
    }

    // MARK: - Ações

    func add(_ title: String) {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        queue.append(TaskItem(title: clean, remaining: Self.slotSeconds))
        save()
    }

    /// Pula pra próxima tarefa antes do alarme.
    func skip() {
        guard let finished = queue.first else { return }
        rotate()
        pendingNote = PendingNote(taskID: finished.id, title: finished.title)
        save()
    }

    func completeCurrent() {
        if let c = current { complete(c.id) }
    }

    func complete(_ id: UUID) {
        guard let i = queue.firstIndex(where: { $0.id == id }) else { return }
        var t = queue.remove(at: i)
        if t.remaining < Self.slotSeconds { t.rounds += 1 }
        t.completedAt = Date()
        completed.insert(t, at: 0)
        if i == 0 { lastTick = Date() }
        if queue.isEmpty { isRunning = false }
        if pendingNote?.taskID == id { pendingNote = nil }
        save()
    }

    func archive(_ id: UUID) {
        guard let i = queue.firstIndex(where: { $0.id == id }) else { return }
        var t = queue.remove(at: i)
        if t.remaining < Self.slotSeconds { t.rounds += 1 }
        t.remaining = Self.slotSeconds
        t.archivedAt = Date()
        archived.insert(t, at: 0)
        if i == 0 { lastTick = Date() }
        if queue.isEmpty { isRunning = false }
        if pendingNote?.taskID == id { pendingNote = nil }
        save()
    }

    func restore(_ id: UUID) {
        guard let i = archived.firstIndex(where: { $0.id == id }) else { return }
        var t = archived.remove(at: i)
        t.archivedAt = nil
        t.remaining = Self.slotSeconds
        queue.append(t)
        save()
    }

    /// Volta uma tarefa concluída pra fila (se marcou sem querer).
    func reopen(_ id: UUID) {
        guard let i = completed.firstIndex(where: { $0.id == id }) else { return }
        var t = completed.remove(at: i)
        t.completedAt = nil
        t.remaining = Self.slotSeconds
        queue.append(t)
        save()
    }

    func deleteArchived(_ id: UUID) {
        archived.removeAll { $0.id == id }
        save()
    }

    func deleteCompleted(_ id: UUID) {
        completed.removeAll { $0.id == id }
        save()
    }

    func clearHistory() {
        completed.removeAll()
        save()
    }

    func saveNote(_ text: String, for id: UUID) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let i = queue.firstIndex(where: { $0.id == id }) {
            queue[i].note = clean
        }
        if pendingNote?.taskID == id { pendingNote = nil }
        save()
    }

    func dismissNote() {
        pendingNote = nil
    }

    // MARK: - Disco

    func save() {
        ticksSinceSave = 0
        Persistence.save(SavedState(queue: queue, archived: archived, completed: completed))
    }
}
