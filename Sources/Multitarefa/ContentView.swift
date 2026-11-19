import SwiftUI

enum Tab: String, CaseIterable, Identifiable {
    case queue, archived, history, trash
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .queue: return "list.bullet"
        case .archived: return "archivebox"
        case .history: return "clock.arrow.circlepath"
        case .trash: return "trash"
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

                switch store.page {
                case .tasks:
                    ScrollView {
                        VStack(spacing: 16) {
                            HeroCard()
                            TabBar(tab: $tab)
                            switch tab {
                            case .queue: QueueSection()
                            case .archived: ArchivedSection()
                            case .history: HistorySection()
                            case .trash: TrashSection()
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.bottom, 24)
                        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: store.pendingSwitch)
                    }
                    .scrollIndicators(.visible)
                case .tags:
                    TagsView()
                }
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
            Text(store.page == .tags ? "Tags" : "Multitarefa")
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
                withAnimation(.spring(response: 0.3)) {
                    store.page = store.page == .tags ? .tasks : .tags
                }
            } label: {
                Image(systemName: store.page == .tags ? "checklist" : "tag")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 18, height: 18)
            }
            .glassButton(prominent: store.page == .tags)
            .help(store.page == .tags ? "Voltar pras tarefas" : "Tags")

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
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .center, spacing: 24) {
                        TimerRing(remaining: c.remaining, duration: c.durationSeconds, isRunning: store.isRunning)

                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Text(c.isTimeUp ? "TEMPO ESGOTADO" : "AGORA")
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(2)
                                    .foregroundStyle(c.isTimeUp ? Theme.danger : Theme.yellow)
                                if store.alarmActive {
                                    AlarmBadge()
                                }
                            }

                            Text(c.title)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(Color.white)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)

                            let tags = store.tags(for: c)
                            if !tags.isEmpty {
                                HStack(spacing: 6) {
                                    ForEach(tags) { TagChip(tag: $0, small: true) }
                                }
                            }

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

                            if store.pendingSwitch == nil {
                                HeroButtons(task: c)
                                    .padding(.top, 4)
                            }
                        }
                        Spacer(minLength: 0)
                    }

                    if let p = store.pendingSwitch, p.taskID == c.id {
                        SwitchBalloon(pending: p)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
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
        .glassCard(cornerRadius: 28, tint: store.alarmActive ? Theme.danger.opacity(0.14) : nil)
    }
}

struct AlarmBadge: View {
    @EnvironmentObject var store: TaskStore
    @State private var pulse = false

    var body: some View {
        Button {
            store.stopAlarm()
        } label: {
            Label("Silenciar alarme", systemImage: "bell.slash.fill")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Theme.danger.opacity(pulse ? 0.9 : 0.55), in: Capsule())
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}

struct HeroButtons: View {
    @EnvironmentObject var store: TaskStore
    let task: TaskItem

    var body: some View {
        HStack(spacing: 8) {
            if task.isTimeUp {
                Button {
                    store.requestNext()
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
                    store.requestNext()
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

// MARK: - Onde parei (antes de trocar)

struct SwitchBalloon: View {
    @EnvironmentObject var store: TaskStore
    let pending: PendingSwitch
    @State private var text = ""
    @FocusState private var focused: Bool

    private var goLabel: String {
        if let name = store.switchTargetTitle(pending) {
            return "Salvar e ir pra \"\(name)\""
        }
        return "Salvar e começar nova rodada"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "bookmark")
                    .foregroundStyle(Theme.yellow)
                Text("Antes de trocar: onde você parou em \"\(pending.title)\"?")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.white)
            }
            TextField("Ex: parei no item 3 da planilha", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .focused($focused)
                .onSubmit(confirm)
            HStack(spacing: 8) {
                Button(goLabel, action: confirm)
                    .glassButton(prominent: true)
                Button("Ir sem anotar") { store.confirmSwitch(note: "") }
                    .glassButton()
                Spacer()
                if pending.automatic {
                    Button("+5 min") {
                        if let c = store.current { store.addTime(c.id, seconds: 5 * 60) }
                    }
                    .glassButton()
                } else {
                    Button("Cancelar") { store.cancelSwitch() }
                        .glassButton()
                        .keyboardShortcut(.cancelAction)
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 20, tint: Theme.yellow.opacity(0.18))
        .onAppear {
            text = ""
            focused = true
        }
        .id("\(pending.taskID)-\(pending.targetID?.uuidString ?? "next")")
    }

    private func confirm() {
        store.confirmSwitch(note: text)
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
        case .trash: return "Lixeira \(store.trash.count)"
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

struct TaskTagsLine: View {
    @EnvironmentObject var store: TaskStore
    let task: TaskItem

    var body: some View {
        let tags = store.tags(for: task)
        if !tags.isEmpty {
            HStack(spacing: 5) {
                ForEach(tags) { TagChip(tag: $0, small: true) }
            }
        }
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

            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(size: 14, weight: isCurrent ? .semibold : .regular))
                    .foregroundStyle(Color.white)
                TaskTagsLine(task: task)
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
                    RowIconButton(icon: "play.fill", help: "Fazer agora") { store.requestSwitch(to: task.id) }
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
                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.title)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.white)
                            TaskTagsLine(task: task)
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
                        RowIconButton(icon: "trash", help: "Mover pra lixeira") {
                            withAnimation { store.moveToTrash(task.id) }
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
                    CompletedRow(task: task)
                }
            }
        }
        .confirmationDialog("Mandar todo o histórico pra lixeira?", isPresented: $confirmClear) {
            Button("Mover pra lixeira", role: .destructive) { store.clearHistory() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Você ainda pode recuperar pela Lixeira por \(TaskStore.trashDays) dias.")
        }
    }
}

struct CompletedRow: View {
    @EnvironmentObject var store: TaskStore
    let task: TaskItem

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(Theme.yellow)
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.white)
                TaskTagsLine(task: task)
                Text("\(Format.duration(task.totalSeconds)) · \(task.rounds) rodada(s)" +
                     (task.completedAt.map { " · \(Format.date($0))" } ?? ""))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textMuted)
            }
            Spacer()
            TagMenuButton(task: task)
            RowIconButton(icon: "text.bubble", help: "Ver e editar") { store.edit(task.id) }
            RowIconButton(icon: "arrow.uturn.left", help: "Reabrir") {
                withAnimation { store.reopen(task.id) }
            }
            RowIconButton(icon: "trash", help: "Mover pra lixeira") {
                withAnimation { store.moveToTrash(task.id) }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassCard(cornerRadius: 18)
    }
}

/// Menu rápido pra marcar/desmarcar tags de uma tarefa.
struct TagMenuButton: View {
    @EnvironmentObject var store: TaskStore
    let task: TaskItem

    var body: some View {
        Menu {
            if store.tags.isEmpty {
                Text("Crie tags na tela de Tags ou ao editar a tarefa")
            }
            ForEach(store.tags) { tag in
                Button {
                    store.toggleTag(task.id, tag.id)
                } label: {
                    if task.tagIDs.contains(tag.id) {
                        Label(tag.name, systemImage: "checkmark")
                    } else {
                        Text(tag.name)
                    }
                }
            }
        } label: {
            Image(systemName: "tag")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 30, height: 30)
                .background(Color.white.opacity(0.04), in: Circle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Tags")
    }
}

// MARK: - Lixeira

struct TrashSection: View {
    @EnvironmentObject var store: TaskStore
    @State private var confirmEmpty = false

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundStyle(Theme.yellow)
                Text("Tarefas ficam \(TaskStore.trashDays) dias na lixeira e depois são apagadas de vez.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                if !store.trash.isEmpty {
                    Button("Esvaziar lixeira") { confirmEmpty = true }
                        .glassButton()
                }
            }

            if store.trash.isEmpty {
                EmptyHint(icon: "trash", text: "A lixeira está vazia.")
            } else {
                ForEach(store.trash) { task in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.title)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.white)
                            TaskTagsLine(task: task)
                            let days = store.daysLeftInTrash(task)
                            Text("Veio de \(task.deletedFrom?.label ?? "Fila") · some em \(days) dia\(days == 1 ? "" : "s")")
                                .font(.system(size: 11))
                                .foregroundStyle(days <= 1 ? Theme.danger : Theme.textMuted)
                        }
                        Spacer()
                        Button {
                            withAnimation { store.restoreFromTrash(task.id) }
                        } label: {
                            Label("Recuperar", systemImage: "arrow.uturn.left")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .glassButton()
                        RowIconButton(icon: "xmark", help: "Apagar de vez") {
                            withAnimation { store.deleteForever(task.id) }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .glassCard(cornerRadius: 18)
                }
            }
        }
        .confirmationDialog("Apagar de vez tudo que está na lixeira?", isPresented: $confirmEmpty) {
            Button("Apagar tudo", role: .destructive) { store.emptyTrash() }
            Button("Cancelar", role: .cancel) {}
        }
    }
}

// MARK: - Peças

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
