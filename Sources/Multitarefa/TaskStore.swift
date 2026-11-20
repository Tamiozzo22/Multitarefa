import AppKit
import Foundation
import SwiftUI

enum Page {
    case tasks, tags
}

/// Toda a lógica do app. A tarefa atual é sempre a primeira da fila.
/// O app nunca troca de tarefa automaticamente: quando o tempo acaba, o alarme toca
/// (e repete) até você agir no app.
final class TaskStore: ObservableObject {
    /// Duração padrão de uma rodada para tarefas novas.
    static let defaultDuration = 10 * 60
    /// Quando avisar que a rodada está acabando.
    static let warningSeconds = 60
    /// Opções rápidas de duração (minutos).
    static let durationPresets = [5, 10, 15, 20, 25, 30, 45, 60]
    /// Dias que uma tarefa fica na lixeira.
    static let trashDays = 5
    /// Intervalo após o alarme antes de tocar novamente.
    static let alarmRepeatDelay: Double = 5

    @Published var queue: [TaskItem] = []
    @Published var archived: [TaskItem] = []
    @Published var completed: [TaskItem] = []
    @Published var trash: [TaskItem] = []
    @Published var tags: [TagDef] = []
    @Published var scheduled: [TaskItem] = []

    @Published var isRunning = false
    @Published var alarmActive = false
    @Published var pendingSwitch: PendingSwitch?
    @Published var editing: EditTarget?
    @Published var showSettings = false
    @Published var page: Page = .tasks

    private var timer: Timer?
    private var alarmTimer: Timer?
    private var housekeepingTimer: Timer?
    private var releaseTimer: Timer?
    private var lastTick = Date()
    private var ticksSinceSave = 0

    init() {
        if let saved = Persistence.load() {
            queue = saved.queue
            archived = saved.archived
            completed = saved.completed
            trash = saved.trash
            tags = saved.tags
            scheduled = saved.scheduled
        }
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t

        let h = Timer(timeInterval: 3600, repeats: true) { [weak self] _ in
            self?.purgeTrash()
        }
        RunLoop.main.add(h, forMode: .common)
        housekeepingTimer = h
        purgeTrash()

        let r = Timer(timeInterval: 15, repeats: true) { [weak self] _ in
            self?.releaseDueTasks()
        }
        RunLoop.main.add(r, forMode: .common)
        releaseTimer = r
        releaseDueTasks()
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

    /// Todas as tarefas que não estão na lixeira.
    var allTasks: [TaskItem] { queue + scheduled + archived + completed }

    func task(_ id: UUID) -> TaskItem? {
        queue.first { $0.id == id }
            ?? scheduled.first { $0.id == id }
            ?? archived.first { $0.id == id }
            ?? completed.first { $0.id == id }
            ?? trash.first { $0.id == id }
    }

    func origin(of id: UUID) -> TaskOrigin? {
        if queue.contains(where: { $0.id == id }) { return .queue }
        if scheduled.contains(where: { $0.id == id }) { return .scheduled }
        if archived.contains(where: { $0.id == id }) { return .archived }
        if completed.contains(where: { $0.id == id }) { return .completed }
        return nil
    }

    func isCurrent(_ id: UUID) -> Bool { current?.id == id }

    /// Nome da tarefa para onde a troca vai levar.
    func switchTargetTitle(_ p: PendingSwitch) -> String? {
        if let t = p.targetID { return task(t)?.title }
        return queue.count > 1 ? queue[1].title : nil
    }

    private func mutate(_ id: UUID, _ change: (inout TaskItem) -> Void) {
        if let i = queue.firstIndex(where: { $0.id == id }) {
            change(&queue[i])
        } else if let i = scheduled.firstIndex(where: { $0.id == id }) {
            change(&scheduled[i])
        } else if let i = archived.firstIndex(where: { $0.id == id }) {
            change(&archived[i])
        } else if let i = completed.firstIndex(where: { $0.id == id }) {
            change(&completed[i])
        } else if let i = trash.firstIndex(where: { $0.id == id }) {
            change(&trash[i])
        }
    }

    // MARK: - Timer

    func start() {
        guard let c = current, !c.isTimeUp else { return }
        stopAlarm()
        lastTick = Date()
        isRunning = true
    }

    func pause() {
        stopAlarm()
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

        let before = queue[0].remaining
        let used = min(elapsed, before)
        queue[0].remaining -= used
        queue[0].totalSeconds += used
        let after = queue[0].remaining

        if queue[0].durationSeconds > Self.warningSeconds,
           before > Self.warningSeconds, after <= Self.warningSeconds, after > 0 {
            Sound.warning()
            Notifier.send(title: "Falta 1 minuto",
                          body: "Comece a concluir o raciocínio em \"\(queue[0].title)\".")
        }

        if after <= 0 {
            timeUp()
        } else {
            ticksSinceSave += 1
            if ticksSinceSave >= 15 { save() }
        }
    }

    /// O tempo acabou: alarme (repetindo) e o balão de "onde parei" na tarefa atual.
    private func timeUp() {
        guard let c = queue.first else { return }
        isRunning = false
        if pendingSwitch == nil {
            pendingSwitch = PendingSwitch(taskID: c.id, title: c.title, targetID: nil, automatic: true)
        }
        Notifier.send(title: "Tempo de \"\(c.title)\" acabou",
                      body: "Abra o Multitarefa, anote onde parou e passe para a próxima tarefa.")
        startAlarm()
        save()
    }

    // MARK: - Alarme

    private func startAlarm() {
        alarmActive = true
        ring()
    }

    private func ring() {
        guard alarmActive else { return }
        Sound.alarm { [weak self] in self?.alarmActive ?? false }
        NSApp.requestUserAttention(.criticalRequest)
        alarmTimer?.invalidate()
        let t = Timer(timeInterval: Sound.alarmLength + Self.alarmRepeatDelay, repeats: false) { [weak self] _ in
            self?.ring()
        }
        RunLoop.main.add(t, forMode: .common)
        alarmTimer = t
    }

    /// Para o alarme. Qualquer ação sua no app chama isso.
    func stopAlarm() {
        guard alarmActive else { return }
        alarmActive = false
        alarmTimer?.invalidate()
        alarmTimer = nil
        Sound.stopAll()
    }

    // MARK: - Troca de tarefa (sempre manual, com "onde parei" antes)

    /// Pede para ir para próxima: abre o balão na tarefa atual.
    func requestNext() {
        guard let c = current else { return }
        stopAlarm()
        pendingSwitch = PendingSwitch(taskID: c.id, title: c.title, targetID: nil,
                                      automatic: c.isTimeUp)
    }

    /// Pede para ir direto para uma tarefa da fila.
    func requestSwitch(to id: UUID) {
        guard let c = current, c.id != id, queue.contains(where: { $0.id == id }) else { return }
        stopAlarm()
        pendingSwitch = PendingSwitch(taskID: c.id, title: c.title, targetID: id,
                                      automatic: c.isTimeUp)
    }

    /// Salva a anotação (se tiver) e faz a troca.
    func confirmSwitch(note: String) {
        guard let p = pendingSwitch else { return }
        stopAlarm()
        addNote(p.taskID, note)
        pendingSwitch = nil
        if let target = p.targetID {
            performSwitch(to: target)
        } else {
            performNext()
        }
    }

    func cancelSwitch() {
        stopAlarm()
        pendingSwitch = nil
    }

    private func finishRound(_ t: inout TaskItem) {
        if t.remaining < t.durationSeconds { t.rounds += 1 }
        t.remaining = t.durationSeconds
    }

    private func performNext() {
        guard !queue.isEmpty else { return }
        var t = queue.removeFirst()
        finishRound(&t)
        queue.append(t)
        start()
        save()
    }

    private func performSwitch(to id: UUID) {
        guard !queue.isEmpty, !isCurrent(id) else { return }
        var t = queue.removeFirst()
        finishRound(&t)
        queue.append(t)
        if let i = queue.firstIndex(where: { $0.id == id }) {
            let target = queue.remove(at: i)
            queue.insert(target, at: 0)
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
        finishRound(&t)
        t.archivedAt = Date()
        archived.insert(t, at: 0)
        afterRemoval(at: i, id: id)
    }

    private func afterRemoval(at index: Int, id: UUID) {
        if index == 0 {
            stopAlarm()
            isRunning = false
            pendingSwitch = nil
        }
        if queue.isEmpty { isRunning = false }
        if pendingSwitch?.taskID == id || pendingSwitch?.targetID == id { pendingSwitch = nil }
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

    func reopen(_ id: UUID) {
        guard let i = completed.firstIndex(where: { $0.id == id }) else { return }
        var t = completed.remove(at: i)
        t.completedAt = nil
        t.remaining = t.durationSeconds
        queue.append(t)
        save()
    }

    // MARK: - Lixeira

    /// Manda para lixeira (de qualquer lista).
    func moveToTrash(_ id: UUID) {
        var item: TaskItem?
        var from: TaskOrigin?
        if let i = queue.firstIndex(where: { $0.id == id }) {
            var t = queue.remove(at: i)
            finishRound(&t)
            item = t
            from = .queue
            afterRemoval(at: i, id: id)
        } else if let i = scheduled.firstIndex(where: { $0.id == id }) {
            item = scheduled.remove(at: i)
            from = .scheduled
        } else if let i = archived.firstIndex(where: { $0.id == id }) {
            item = archived.remove(at: i)
            from = .archived
        } else if let i = completed.firstIndex(where: { $0.id == id }) {
            item = completed.remove(at: i)
            from = .completed
        }
        guard var t = item else { return }
        t.deletedAt = Date()
        t.deletedFrom = from
        trash.insert(t, at: 0)
        if editing?.id == id { editing = nil }
        save()
    }

    /// Volta da lixeira para o lugar de onde saiu.
    func restoreFromTrash(_ id: UUID) {
        guard let i = trash.firstIndex(where: { $0.id == id }) else { return }
        var t = trash.remove(at: i)
        let from = t.deletedFrom ?? .queue
        t.deletedAt = nil
        t.deletedFrom = nil
        switch from {
        case .queue:
            t.remaining = t.durationSeconds
            queue.append(t)
        case .scheduled:
            scheduled.append(t)
            sortScheduled()
            releaseDueTasks()
        case .archived:
            archived.insert(t, at: 0)
        case .completed:
            completed.insert(t, at: 0)
            completed.sort { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
        }
        save()
    }

    func deleteForever(_ id: UUID) {
        trash.removeAll { $0.id == id }
        save()
    }

    func emptyTrash() {
        trash.removeAll()
        save()
    }

    /// Dias até a tarefa sumir da lixeira.
    func daysLeftInTrash(_ t: TaskItem) -> Int {
        guard let d = t.deletedAt else { return Self.trashDays }
        let limit = d.addingTimeInterval(Double(Self.trashDays) * 86_400)
        let left = limit.timeIntervalSinceNow / 86_400
        return max(0, Int(left.rounded(.up)))
    }

    func purgeTrash() {
        let cutoff = Date().addingTimeInterval(-Double(Self.trashDays) * 86_400)
        let before = trash.count
        trash.removeAll { ($0.deletedAt ?? Date()) < cutoff }
        if trash.count != before { save() }
    }

    /// "Limpar histórico" manda tudo para lixeira.
    func clearHistory() {
        let now = Date()
        for var t in completed {
            t.deletedAt = now
            t.deletedFrom = .completed
            trash.insert(t, at: 0)
        }
        completed.removeAll()
        save()
    }

    // MARK: - Edição

    func edit(_ id: UUID) {
        if isCurrent(id) { stopAlarm() }
        editing = EditTarget(id: id)
    }

    func setTitle(_ id: UUID, _ title: String) {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, task(id)?.title != clean else { return }
        mutate(id) { $0.title = clean }
        save()
    }

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
        if isCurrent(id) { stopAlarm() }
        mutate(id) { t in
            t.remaining = max(0, t.remaining + seconds)
            if t.remaining > t.durationSeconds { t.durationSeconds = t.remaining }
        }
        if isCurrent(id) {
            if isTimeUp {
                isRunning = false
            } else if wasTimeUp && seconds > 0 {
                if pendingSwitch?.automatic == true { pendingSwitch = nil }
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

    // MARK: - Subtarefas

    func addSubtask(_ id: UUID, _ text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        mutate(id) { $0.subtasks.append(Subtask(text: clean)) }
        save()
    }

    func toggleSubtask(_ id: UUID, _ subID: UUID) {
        mutate(id) { t in
            guard let i = t.subtasks.firstIndex(where: { $0.id == subID }) else { return }
            t.subtasks[i].done.toggle()
            t.subtasks[i].doneAt = t.subtasks[i].done ? Date() : nil
        }
        save()
    }

    func renameSubtask(_ id: UUID, _ subID: UUID, _ text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        mutate(id) { t in
            guard let i = t.subtasks.firstIndex(where: { $0.id == subID }) else { return }
            t.subtasks[i].text = clean
        }
        save()
    }

    func deleteSubtask(_ id: UUID, _ subID: UUID) {
        mutate(id) { $0.subtasks.removeAll { $0.id == subID } }
        save()
    }

    func moveSubtask(_ id: UUID, _ subID: UUID, by offset: Int) {
        mutate(id) { t in
            guard let i = t.subtasks.firstIndex(where: { $0.id == subID }) else { return }
            let j = i + offset
            guard t.subtasks.indices.contains(j) else { return }
            t.subtasks.swapAt(i, j)
        }
        save()
    }

    // MARK: - Agendamento

    private func sortScheduled() {
        scheduled.sort { ($0.releaseDate ?? .distantFuture) < ($1.releaseDate ?? .distantFuture) }
    }

    /// Cria uma tarefa agendada. Se a data já chegou, vai direto para a fila.
    func addScheduled(_ title: String, date: Date, hasTime: Bool) {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        var t = TaskItem(title: clean, durationSeconds: Self.defaultDuration)
        t.scheduledFor = date
        t.scheduleHasTime = hasTime
        scheduled.append(t)
        sortScheduled()
        releaseDueTasks(notify: false)
        save()
    }

    /// Agenda (ou reagenda) uma tarefa existente.
    func schedule(_ id: UUID, date: Date, hasTime: Bool) {
        var item: TaskItem?
        if let i = scheduled.firstIndex(where: { $0.id == id }) {
            item = scheduled.remove(at: i)
        } else if let i = queue.firstIndex(where: { $0.id == id }) {
            var t = queue.remove(at: i)
            finishRound(&t)
            item = t
            afterRemoval(at: i, id: id)
        } else if let i = archived.firstIndex(where: { $0.id == id }) {
            var t = archived.remove(at: i)
            t.archivedAt = nil
            item = t
        }
        guard var t = item else { return }
        t.scheduledFor = date
        t.scheduleHasTime = hasTime
        scheduled.append(t)
        sortScheduled()
        releaseDueTasks(notify: false)
        save()
    }

    /// Tira o agendamento e coloca a tarefa na fila agora.
    func moveScheduledToQueue(_ id: UUID) {
        guard let i = scheduled.firstIndex(where: { $0.id == id }) else { return }
        var t = scheduled.remove(at: i)
        t.scheduledFor = nil
        t.scheduleHasTime = false
        t.remaining = t.durationSeconds
        queue.append(t)
        save()
    }

    /// Move para a fila as tarefas cuja data chegou.
    func releaseDueTasks(notify: Bool = true) {
        let now = Date()
        let due = scheduled.filter { ($0.releaseDate ?? .distantFuture) <= now }
        guard !due.isEmpty else { return }
        scheduled.removeAll { ($0.releaseDate ?? .distantFuture) <= now }
        for var t in due {
            t.scheduledFor = nil
            t.scheduleHasTime = false
            t.remaining = t.durationSeconds
            queue.append(t)
        }
        if notify {
            if due.count == 1 {
                Notifier.send(title: "Nova tarefa na fila", body: "\"\(due[0].title)\" chegou à fila de hoje.")
            } else {
                Notifier.send(title: "Novas tarefas na fila", body: "\(due.count) tarefas agendadas chegaram à fila de hoje.")
            }
        }
        save()
    }

    // MARK: - Tags

    func tag(_ id: UUID) -> TagDef? { tags.first { $0.id == id } }

    func tags(for task: TaskItem) -> [TagDef] {
        task.tagIDs.compactMap { tag($0) }
    }

    func count(for tagID: UUID) -> Int {
        allTasks.filter { $0.tagIDs.contains(tagID) }.count
    }

    @discardableResult
    func createTag(_ name: String) -> TagDef? {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        if let existing = tags.first(where: { $0.name.lowercased() == clean.lowercased() }) {
            return existing
        }
        let t = TagDef(name: clean, color: tags.count % Theme.tagColors.count)
        tags.append(t)
        tags.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        save()
        return t
    }

    func renameTag(_ id: UUID, _ name: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, let i = tags.firstIndex(where: { $0.id == id }) else { return }
        tags[i].name = clean
        tags.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        save()
    }

    func setTagColor(_ id: UUID, _ color: Int) {
        guard let i = tags.firstIndex(where: { $0.id == id }) else { return }
        tags[i].color = color
        save()
    }

    func deleteTag(_ id: UUID) {
        tags.removeAll { $0.id == id }
        for i in queue.indices { queue[i].tagIDs.removeAll { $0 == id } }
        for i in archived.indices { archived[i].tagIDs.removeAll { $0 == id } }
        for i in scheduled.indices { scheduled[i].tagIDs.removeAll { $0 == id } }
        for i in completed.indices { completed[i].tagIDs.removeAll { $0 == id } }
        for i in trash.indices { trash[i].tagIDs.removeAll { $0 == id } }
        save()
    }

    func toggleTag(_ taskID: UUID, _ tagID: UUID) {
        mutate(taskID) { t in
            if t.tagIDs.contains(tagID) {
                t.tagIDs.removeAll { $0 == tagID }
            } else {
                t.tagIDs.append(tagID)
            }
        }
        save()
    }

    // MARK: - Disco

    func save() {
        ticksSinceSave = 0
        Persistence.save(SavedState(queue: queue, archived: archived, completed: completed,
                                    trash: trash, tags: tags, scheduled: scheduled))
    }
}
