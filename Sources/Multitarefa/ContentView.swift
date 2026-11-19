import SwiftUI

enum Tab: String, CaseIterable, Identifiable {
    case queue, archived, history
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .queue: return "list.bullet"
        case .archived: return "archivebox"
        case .history: return "clock.arrow.circlepath"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var store: TaskStore
    @ObservedObject private var updater = Updater.shared
    @State private var tab: Tab = .queue

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 0) {
                TopBar(updateReady: updater.isReady)
                    .padding(.horizontal, 22)
                    .padding(.top, 34)
                    .padding(.bottom, 14)

                ScrollView {
                    VStack(spacing: 16) {
                        HeroCard()

                        if let pending = store.pendingNote {
                            NoteBanner(pending: pending)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        TabBar(tab: $tab)

                        switch tab {
                        case .queue: QueueSection()
                        case .archived: ArchivedSection()
                        case .history: HistorySection()
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 24)
                    .animation(.spring(response: 0.35, dampingFraction: 0.85), value: store.pendingNote)
                }
                .scrollIndicators(.never)
            }
        }
        .preferredColorScheme(.dark)
        .sheet(item: $store.editing) { target in
            EditTaskView(taskID: target.id)
                .environmentObject(store)
        }
        .sheet(isPresented: $store.showSettings) {
            SettingsView()
                .environmentObject(store)
        }
    }
}

// MARK: - Barra do topo

struct TopBar: View {
    @EnvironmentObject var store: TaskStore
    let updateReady: Bool

    var body: some View {
        HStack(spacing: 12) {
            BrandLogo(height: 34)
            Rectangle()
                .fill(Theme.hairline)
                .frame(width: 1, height: 22)
            Text("Multitarefa")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            if updateReady {
                Button {
                    store.showSettings = true
                } label: {
                    Label("Atualização pronta", systemImage: "arrow.down.circle")
                        .font(.system(size: 12, weight: .semibold))
                }
                .glassButton(prominent: true)
            }
            Button {
                store.showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 18, height: 18)
            }
            .glassButton()
            .help("Configurações")
        }
    }
}

// MARK: - Cartão principal

struct HeroCard: View {
    @EnvironmentObject var store: TaskStore

    var body: some View {
        Group {
            if let c = store.current {
                HStack(alignment: .center, spacing: 24) {
                    TimerRing(remaining: c.remaining, duration: c.durationSeconds, isRunning: store.isRunning)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(c.isTimeUp ? "TEMPO ESGOTADO" : "AGORA")
                            .font(.system(size: 11, weight: .bold))
                            .tracking(2)
                            .foregroundStyle(c.isTimeUp ? Theme.danger : Theme.yellow)

                        Text(c.title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Color.white)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)

                        if let note = c.latestNote {
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "bookmark.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.yellow)
                                    .padding(.top, 2)
                                Text(note.text)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.textSecondary)
                                    .lineLimit(2)
                            }
                        }

                        Text("Rodada de \(c.durationSeconds / 60) min · total \(Format.duration(c.totalSeconds)) · \(c.rounds) rodada(s)")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textMuted)

                        HeroButtons(task: c)
                            .padding(.top, 4)
                    }
                    Spacer(minLength: 0)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Comece pela primeira tarefa")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.white)
                    Text("Cada tarefa ganha uma rodada de \(TaskStore.defaultDuration / 60) minutos. Quando o tempo acabar, o alarme toca e você decide quando trocar.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(22)
        .glassCard(cornerRadius: 28)
    }
}

struct HeroButtons: View {
    @EnvironmentObject var store: TaskStore
    let task: TaskItem

    var body: some View {
        HStack(spacing: 8) {
            if task.isTimeUp {
                Button {
                    store.next()
                } label: {
                    Label("Próxima tarefa", systemImage: "forward.fill")
                        .font(.system(size: 13, weight: .semibold))
                }
                .glassButton(prominent: true)

                Button {
                    store.addTime(task.id, seconds: 5 * 60)
                } label: {
                    Label("+5 min", systemImage: "plus")
                        .font(.system(size: 13, weight: .semibold))
                }
                .glassButton()
            } else {
                Button {
                    store.toggleRunning()
                } label: {
                    Label(store.isRunning ? "Pausar" : "Iniciar",
                          systemImage: store.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 13, weight: .semibold))
                }
                .glassButton(prominent: true)

                Button {
                    store.next()
                } label: {
                    Label("Próxima", systemImage: "forward.fill")
                        .font(.system(size: 13, weight: .semibold))
                }
                .glassButton()
            }

            Button {
                store.completeCurrent()
            } label: {
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
            }
            .glassButton()
            .help("Concluir tarefa")

            Button {
                store.edit(task.id)
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 13, weight: .bold))
            }
            .glassButton()
            .help("Editar tarefa")
        }
    }
}

// MARK: - Onde parei

struct NoteBanner: View {
    @EnvironmentObject var store: TaskStore
    let pending: PendingNote
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "bookmark")
                    .foregroundStyle(Theme.yellow)
                Text("Onde você parou em \"\(pending.title)\"?")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white)
            }
            HStack(spacing: 8) {
                TextField("Ex: parei no item 3 da planilha", text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .focused($focused)
                    .onSubmit(saveNote)
                Button("Salvar", action: saveNote)
                    .glassButton(prominent: true)
                Button("Agora não") { store.dismissNote() }
                    .glassButton()
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 20, tint: Theme.yellow.opacity(0.18))
        .onAppear {
            text = ""
            focused = true
        }
        .id(pending.taskID)
    }

    private func saveNote() {
        store.savePendingNote(text)
        text = ""
    }
}

// MARK: - Abas

struct TabBar: View {
    @EnvironmentObject var store: TaskStore
    @Binding var tab: Tab

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Tab.allCases) { t in
                Button {
                    withAnimation(.spring(response: 0.3)) { tab = t }
                } label: {
                    Label(title(t), systemImage: t.icon)
                        .font(.system(size: 13, weight: .semibold))
                }
                .glassButton(prominent: tab == t)
            }
            Spacer()
        }
    }

    private func title(_ t: Tab) -> String {
        switch t {
        case .queue: return "Fila \(store.queue.count)"
        case .archived: return "Arquivadas \(store.archived.count)"
        case .history: return "Histórico \(store.completed.count)"
        }
    }
}

// MARK: - Fila

struct QueueSection: View {
    @EnvironmentObject var store: TaskStore
    @State private var newTitle = ""

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                GlassField(placeholder: "Nova tarefa…", text: $newTitle, onSubmit: add)
                Button(action: add) {
                    Label("Adicionar", systemImage: "plus")
                        .font(.system(size: 13, weight: .semibold))
                }
                .glassButton(prominent: true)
            }

            if store.queue.isEmpty {
                EmptyHint(icon: "tray", text: "A fila está vazia. Escreva uma tarefa acima e aperte Enter.")
            } else {
                ForEach(Array(store.queue.enumerated()), id: \.element.id) { index, task in
                    QueueRow(task: task, position: index)
                }
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
    let position: Int

    private var isCurrent: Bool { position == 0 }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation { store.complete(task.id) }
            } label: {
                Image(systemName: "circle")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(isCurrent ? Theme.yellow : Theme.textSecondary)
            }
            .buttonStyle(.plain)
            .help("Concluir tarefa")

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.system(size: 14, weight: isCurrent ? .semibold : .regular))
                    .foregroundStyle(Color.white)
                if let note = task.latestNote {
                    Text(note.text)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                Text("\(task.durationSeconds / 60) min por rodada · total \(Format.duration(task.totalSeconds))")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textMuted)
            }

            Spacer()

            Text(isCurrent ? Format.clock(task.remaining) : "#\(position + 1)")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isCurrent ? Theme.yellow : Theme.textMuted)

            HStack(spacing: 4) {
                if !isCurrent {
                    RowIconButton(icon: "play.fill", help: "Fazer agora") { store.switchTo(task.id) }
                }
                RowIconButton(icon: "pencil", help: "Editar") { store.edit(task.id) }
                RowIconButton(icon: "archivebox", help: "Arquivar para depois") {
                    withAnimation { store.archive(task.id) }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassCard(cornerRadius: 18, tint: isCurrent ? Theme.yellow.opacity(0.12) : nil)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isCurrent ? Theme.yellow.opacity(0.55) : Color.clear, lineWidth: 1)
        )
    }
}

struct RowIconButton: View {
    let icon: String
    let help: String
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(hover ? Theme.yellow : Theme.textSecondary)
                .frame(width: 30, height: 30)
                .background(Color.white.opacity(hover ? 0.1 : 0.04), in: Circle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help(help)
    }
}

// MARK: - Arquivadas

struct ArchivedSection: View {
    @EnvironmentObject var store: TaskStore

    var body: some View {
        VStack(spacing: 10) {
            if store.archived.isEmpty {
                EmptyHint(icon: "archivebox", text: "Tarefas arquivadas ficam aqui até você trazer de volta pra fila.")
            } else {
                ForEach(store.archived) { task in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(task.title)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.white)
                            if let note = task.latestNote {
                                Text(note.text)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.textSecondary)
                                    .lineLimit(1)
                            }
                            Text("Total \(Format.duration(task.totalSeconds))")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.textMuted)
                        }
                        Spacer()
                        Button {
                            withAnimation { store.restore(task.id) }
                        } label: {
                            Label("Voltar pra fila", systemImage: "arrow.uturn.left")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .glassButton()
                        RowIconButton(icon: "pencil", help: "Editar") { store.edit(task.id) }
                        RowIconButton(icon: "trash", help: "Excluir") {
                            withAnimation { store.deleteArchived(task.id) }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .glassCard(cornerRadius: 18)
                }
            }
        }
    }
}

// MARK: - Histórico

struct HistorySection: View {
    @EnvironmentObject var store: TaskStore
    @State private var confirmClear = false

    var body: some View {
        VStack(spacing: 10) {
            if store.completed.isEmpty {
                EmptyHint(icon: "checkmark.seal", text: "Quando você concluir uma tarefa, ela aparece aqui com o tempo total que levou.")
            } else {
                HStack(spacing: 12) {
                    StatTile(value: "\(store.completed.count)", label: "concluídas")
                    StatTile(value: Format.duration(store.completedTotalSeconds), label: "tempo total")
                    Spacer()
                    Button("Limpar histórico") { confirmClear = true }
                        .glassButton()
                }

                ForEach(store.completed) { task in
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Theme.yellow)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(task.title)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.white)
                            Text("\(Format.duration(task.totalSeconds)) · \(task.rounds) rodada(s)" +
                                 (task.completedAt.map { " · \(Format.date($0))" } ?? ""))
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.textMuted)
                        }
                        Spacer()
                        RowIconButton(icon: "text.bubble", help: "Ver anotações") { store.edit(task.id) }
                        RowIconButton(icon: "arrow.uturn.left", help: "Reabrir") {
                            withAnimation { store.reopen(task.id) }
                        }
                        RowIconButton(icon: "trash", help: "Excluir do histórico") {
                            withAnimation { store.deleteCompleted(task.id) }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .glassCard(cornerRadius: 18)
                }
            }
        }
        .confirmationDialog("Limpar todo o histórico?", isPresented: $confirmClear) {
            Button("Limpar", role: .destructive) { store.clearHistory() }
            Button("Cancelar", role: .cancel) {}
        }
    }
}

struct StatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.yellow)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textMuted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassCard(cornerRadius: 14)
    }
}

struct EmptyHint: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(Theme.yellow.opacity(0.8))
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 24)
        .glassCard(cornerRadius: 20)
    }
}
