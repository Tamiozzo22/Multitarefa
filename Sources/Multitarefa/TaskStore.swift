import Foundation
import SwiftUI

/// Toda a lógica do app. A tarefa atual é sempre a primeira da fila.
/// O app nunca troca de tarefa sozinho: quando o tempo acaba, o alarme toca e o timer para em 00:00.
final class TaskStore: ObservableObject {
    /// Duração padrão de uma rodada para tarefas novas.
    static let defaultDuration = 10 * 60
    /// Quando avisar que a rodada está acabando.
    static let warningSeconds = 60
    /// Opções rápidas de duração (minutos).
    static let durationPresets = [5, 10, 15, 20, 25, 30, 45, 60]

    @Published var queue: [TaskItem] = []
    @Published var archived: [TaskItem] = []
    @Published var completed: [TaskItem] = []
    @Published var isRunning = false
    @Published var pendingNote: PendingNote?
    @Published var editing: EditTarget?
    @Published var showSettings = false

    private var timer: Timer?
    private var lastTick = Date()
    private var ticksSinceSave = 0

    init() {
        if let saved = Persistence.load() {
            queue = saved.queue
            archived = saved.archived
            completed = saved.completed
        }
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    // MARK: - Leitura

    var current: TaskItem? { queue.first }

    var isTimeUp: Bool { current?.isTimeUp ?? false }

    var menuBarText: String {
        guard let c = current else { return "" }
        return c.isTimeUp ? "Trocar" : Format.clock(c.remaining)
    }

    var completedTotalSeconds: Int {
        completed.reduce(0) { $0 + $1.totalSeconds }
    }

    func task(_ id: UUID) -> TaskItem? {
        queue.first { $0.id == id } ?? archived.first { $0.id == id } ?? completed.first { $0.id == id }
    }

    func isCurrent(_ id: UUID) -> Bool { current?.id == id }

    /// Altera uma tarefa onde quer que ela esteja (fila, arquivadas ou histórico).
    private func mutate(_ id: UUID, _ change: (inout TaskItem) -> Void) {
        if let i = queue.firstIndex(where: { $0.id == id }) {
            change(&queue[i])
        } else if let i = archived.firstIndex(where: { $0.id == id }) {
            change(&archived[i])
        } else if let i = completed.firstIndex(where: { $0.id == id }) {
            change(&completed[i])
        }
    }

    // MARK: - Timer

    func start() {
        guard let c = current, !c.isTimeUp else { return }
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

        if queue[0].durationSeconds > Self.warningSeconds,
           before > Self.warningSeconds, after <= Self.warningSeconds, after > 0 {
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

    /// O tempo acabou: toca o alarme e espera você trocar de tarefa no app.
    private func timeUp() {
        guard let c = queue.first else { return }
        isRunning = false
        Sound.alarm()
        Notifier.send(title: "Tempo de \"\(c.title)\" acabou",
                      body: "Abra o Multitarefa pra passar pra próxima tarefa.")
        save()
    }

    // MARK: - Troca de tarefa (sempre manual)

    /// Manda a tarefa atual pro fim da fila, zerando a contagem dela.
    private func rotateCurrent() {
        guard !queue.isEmpty else { return }
        var t = queue.removeFirst()
        if t.remaining < t.durationSeconds { t.rounds += 1 }
        t.remaining = t.durationSeconds
        queue.append(t)
        pendingNote = PendingNote(taskID: t.id, title: t.title)
    }

    /// Passa pra próxima tarefa da fila e já começa o timer dela.
    func next() {
        guard queue.count > 1 else {
            // Só uma tarefa: começa uma rodada nova dela.
            if var only = queue.first {
                if only.remaining < only.durationSeconds { only.rounds += 1 }
                only.remaining = only.durationSeconds
                queue[0] = only
                start()
                save()
            }
            return
        }
        rotateCurrent()
        start()
        save()
    }

    /// Pula direto pra uma tarefa específica da fila.
    func switchTo(_ id: UUID) {
        guard !isCurrent(id), queue.contains(where: { $0.id == id }) else { return }
        rotateCurrent()
        if let i = queue.firstIndex(where: { $0.id == id }) {
            let t = queue.remove(at: i)
            queue.insert(t, at: 0)
        }
        start()
        save()
    }

    // MARK: - Ações

    func add(_ title: String) {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        queue.append(TaskItem(title: clean, durationSeconds: Self.defaultDuration))
        save()
    }

    func completeCurrent() {
        if let c = current { complete(c.id) }
    }

    func complete(_ id: UUID) {
        guard let i = queue.firstIndex(where: { $0.id == id }) else { return }
        var t = queue.remove(at: i)
        if t.remaining < t.durationSeconds { t.rounds += 1 }
        t.completedAt = Date()
        completed.insert(t, at: 0)
        afterRemoval(at: i, id: id)
    }

    func archive(_ id: UUID) {
        guard let i = queue.firstIndex(where: { $0.id == id }) else { return }
        var t = queue.remove(at: i)
        if t.remaining < t.durationSeconds { t.rounds += 1 }
        t.remaining = t.durationSeconds
        t.archivedAt = Date()
        archived.insert(t, at: 0)
        afterRemoval(at: i, id: id)
    }

    private func afterRemoval(at index: Int, id: UUID) {
        if index == 0 {
            // A próxima tarefa espera você apertar Iniciar.
            isRunning = false
        }
        if queue.isEmpty { isRunning = false }
        if pendingNote?.taskID == id { pendingNote = nil }
        if editing?.id == id { editing = nil }
        save()
    }

    func restore(_ id: UUID) {
        guard let i = archived.firstIndex(where: { $0.id == id }) else { return }
        var t = archived.remove(at: i)
        t.archivedAt = nil
        t.remaining = t.durationSeconds
        queue.append(t)
        save()
    }

    /// Volta uma tarefa concluída pra fila.
    func reopen(_ id: UUID) {
        guard let i = completed.firstIndex(where: { $0.id == id }) else { return }
        var t = completed.remove(at: i)
        t.completedAt = nil
        t.remaining = t.durationSeconds
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

    // MARK: - Edição

    func edit(_ id: UUID) {
        editing = EditTarget(id: id)
    }

    func setTitle(_ id: UUID, _ title: String) {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        mutate(id) { $0.title = clean }
        save()
    }

    /// Muda a duração da rodada. O tempo restante acompanha a diferença.
    func setDuration(_ id: UUID, minutes: Int) {
        let newDuration = max(1, min(240, minutes)) * 60
        mutate(id) { t in
            let diff = newDuration - t.durationSeconds
            t.durationSeconds = newDuration
            t.remaining = max(0, min(newDuration, t.remaining + diff))
        }
        if isCurrent(id), isTimeUp { isRunning = false }
        save()
    }

    /// Adiciona (ou tira) tempo da rodada atual. Se o tempo tinha acabado, já retoma.
    func addTime(_ id: UUID, seconds: Int) {
        let wasTimeUp = isCurrent(id) && isTimeUp
        mutate(id) { t in
            t.remaining = max(0, t.remaining + seconds)
            if t.remaining > t.durationSeconds { t.durationSeconds = t.remaining }
        }
        if isCurrent(id) {
            if isTimeUp {
                isRunning = false
            } else if wasTimeUp && seconds > 0 {
                start()
            }
        }
        save()
    }

    func addNote(_ id: UUID, _ text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        mutate(id) { $0.notes.append(NoteEntry(text: clean)) }
        save()
    }

    func deleteNote(_ id: UUID, noteID: UUID) {
        mutate(id) { $0.notes.removeAll { $0.id == noteID } }
        save()
    }

    func savePendingNote(_ text: String) {
        guard let p = pendingNote else { return }
        addNote(p.taskID, text)
        pendingNote = nil
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
