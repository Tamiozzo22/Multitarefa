import SwiftUI

enum Tab: String, CaseIterable, Identifiable {
    case queue = "Fila"
    case archived = "Arquivadas"
    case history = "Histórico"
    var id: String { rawValue }
}

struct ContentView: View {
    @EnvironmentObject var store: TaskStore
    @State private var tab: Tab = .queue

    var body: some View {
        VStack(spacing: 0) {
            CurrentTaskHeader()
                .padding(16)

            if let pending = store.pendingNote {
                NoteBanner(pending: pending)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }

            Divider()

            Picker("", selection: $tab) {
                ForEach(Tab.allCases) { t in
                    Text(label(for: t)).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(12)

            switch tab {
            case .queue: QueueView()
            case .archived: ArchivedView()
            case .history: HistoryView()
            }
        }
    }

    private func label(for t: Tab) -> String {
        switch t {
        case .queue: return "Fila (\(store.queue.count))"
        case .archived: return "Arquivadas (\(store.archived.count))"
        case .history: return "Histórico (\(store.completed.count))"
        }
    }
}

// MARK: - Topo: tarefa atual

struct CurrentTaskHeader: View {
    @EnvironmentObject var store: TaskStore

    var body: some View {
        if let c = store.current {
            VStack(alignment: .leading, spacing: 8) {
                Text("Agora")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline) {
                    Text(c.title)
                        .font(.title2.weight(.semibold))
                        .lineLimit(2)
                    Spacer()
                    Text(Format.clock(c.remaining))
                        .font(.system(size: 40, weight: .medium, design: .monospaced))
                        .foregroundStyle(c.remaining <= TaskStore.warningSeconds ? Color.orange : Color.primary)
                }
                ProgressView(value: Double(TaskStore.slotSeconds - c.remaining),
                             total: Double(TaskStore.slotSeconds))
                if !c.note.isEmpty {
                    Label("Onde parei: \(c.note)", systemImage: "bookmark")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Text("Tempo total nesta tarefa: \(Format.duration(c.totalSeconds))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    Button {
                        store.toggleRunning()
                    } label: {
                        Label(store.isRunning ? "Pausar" : "Iniciar",
                              systemImage: store.isRunning ? "pause.fill" : "play.fill")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        store.skip()
                    } label: {
                        Label("Próxima", systemImage: "forward.fill")
                    }

                    Button {
                        store.completeCurrent()
                    } label: {
                        Label("Concluir", systemImage: "checkmark")
                    }
                }
                .padding(.top, 4)
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("Adicione sua primeira tarefa")
                    .font(.title2.weight(.semibold))
                Text("Cada tarefa ganha uma rodada de \(TaskStore.slotSeconds / 60) minutos. Quando o alarme tocar, o app passa pra próxima.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Aviso "onde parei"

struct NoteBanner: View {
    @EnvironmentObject var store: TaskStore
    let pending: PendingNote
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Rodada de \"\(pending.title)\" terminou. Onde você parou?",
                  systemImage: "bell")
                .font(.callout.weight(.medium))
            HStack {
                TextField("Ex: parei no item 3 da planilha", text: $text)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)
                    .onSubmit(saveNote)
                Button("Salvar", action: saveNote)
                Button("Agora não") { store.dismissNote() }
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onAppear {
            text = ""
            focused = true
        }
        .id(pending.taskID)
    }

    private func saveNote() {
        store.saveNote(text, for: pending.taskID)
        text = ""
    }
}

// MARK: - Fila

struct QueueView: View {
    @EnvironmentObject var store: TaskStore
    @State private var newTitle = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Nova tarefa", text: $newTitle)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(add)
                Button(action: add) {
                    Label("Adicionar", systemImage: "plus")
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            if store.queue.isEmpty {
                EmptyHint(text: "A fila está vazia. Escreva uma tarefa acima e aperte Enter.")
            } else {
                List {
                    ForEach(Array(store.queue.enumerated()), id: \.element.id) { index, task in
                        QueueRow(task: task, isCurrent: index == 0, position: index)
                    }
                }
                .listStyle(.inset)
            }
        }
    }

    private func add() {
        store.add(newTitle)
        newTitle = ""
    }
}

struct QueueRow: View {
    @EnvironmentObject var store: TaskStore
    let task: TaskItem
    let isCurrent: Bool
    let position: Int

    var body: some View {
        HStack(spacing: 10) {
            Button {
                store.complete(task.id)
            } label: {
                Image(systemName: "circle")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .help("Concluir tarefa")

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if isCurrent {
                        Text("Agora")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Color.accentColor.opacity(0.18))
                            .clipShape(Capsule())
                    }
                    Text(task.title)
                        .fontWeight(isCurrent ? .semibold : .regular)
                }
                if !task.note.isEmpty {
                    Text("Onde parei: \(task.note)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text("Total: \(Format.duration(task.totalSeconds)) · \(task.rounds) rodada(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(isCurrent ? Format.clock(task.remaining) : "#\(position + 1)")
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(isCurrent ? Color.primary : Color.secondary)

            Button {
                store.archive(task.id)
            } label: {
                Image(systemName: "archivebox")
            }
            .buttonStyle(.borderless)
            .help("Arquivar para depois")
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Arquivadas

struct ArchivedView: View {
    @EnvironmentObject var store: TaskStore

    var body: some View {
        if store.archived.isEmpty {
            EmptyHint(text: "Tarefas arquivadas ficam aqui até você trazer de volta pra fila.")
        } else {
            List {
                ForEach(store.archived) { task in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.title)
                            if !task.note.isEmpty {
                                Text("Onde parei: \(task.note)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text("Total: \(Format.duration(task.totalSeconds))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Voltar pra fila") { store.restore(task.id) }
                        Button {
                            store.deleteArchived(task.id)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                        .help("Excluir")
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.inset)
        }
    }
}

// MARK: - Histórico

struct HistoryView: View {
    @EnvironmentObject var store: TaskStore
    @State private var confirmClear = false

    var body: some View {
        if store.completed.isEmpty {
            EmptyHint(text: "Quando você concluir uma tarefa, ela aparece aqui com o tempo total que levou.")
        } else {
            VStack(spacing: 0) {
                HStack {
                    Text("\(store.completed.count) concluída(s) · \(Format.duration(store.completedTotalSeconds)) no total")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Limpar histórico") { confirmClear = true }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

                List {
                    ForEach(store.completed) { task in
                        HStack {
                            Image(systemName: "checkmark.circle")
                                .foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.title)
                                Text("\(Format.duration(task.totalSeconds)) · \(task.rounds) rodada(s)" +
                                     (task.completedAt.map { " · \(Format.date($0))" } ?? ""))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Reabrir") { store.reopen(task.id) }
                                .buttonStyle(.borderless)
                            Button {
                                store.deleteCompleted(task.id)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .help("Excluir do histórico")
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.inset)
            }
            .confirmationDialog("Limpar todo o histórico?", isPresented: $confirmClear) {
                Button("Limpar", role: .destructive) { store.clearHistory() }
                Button("Cancelar", role: .cancel) {}
            }
        }
    }
}

struct EmptyHint: View {
    let text: String

    var body: some View {
        VStack {
            Spacer()
            Text(text)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(24)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
