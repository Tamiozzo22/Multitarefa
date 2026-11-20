import SwiftUI

enum Tab: String, CaseIterable, Identifiable {
    case queue, scheduled, archived, history, trash
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .queue: return "list.bullet"
        case .scheduled: return "calendar"
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
                    .padding(.top, 30)
                    .padding(.bottom, 16)

                switch store.page {
                case .tasks:
                    ScrollView {
                        VStack(spacing: 16) {
                            HeroCard()
                            TabBar(tab: $tab)
                            switch tab {
                            case .queue: QueueSection()
                            case .scheduled: ScheduledSection()
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
            BrandLogo(height: 30)
            Rectangle()
                .fill(Theme.hairline)
                .frame(width: 1, height: 22)
            Text(store.page == .tags ? "Tags" : "Multitarefa")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            GlassGroup(spacing: 6) {
                HStack(spacing: 6) {
                    if updateReady {
                        Button {
                            store.showSettings = true
                        } label: {
                            Label("Atualização disponível", systemImage: "arrow.down.circle")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .glassButton(prominent: true)
                    }
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            store.page = store.page == .tags ? .tasks : .tags
                        }
                    } label: {
                        Image(systemName: store.page == .tags ? "checklist" : "tag")
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: 18, height: 18)
                    }
                    .glassButton(prominent: store.page == .tags)
                    .help(store.page == .tags ? "Voltar para as tarefas" : "Tags")

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
        .padding(.leading, 18)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .glassCard(cornerRadius: 26)
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
                                LastStopNote(note: note)
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

                    SubtaskPanel(task: c)
                        .padding(14)
                        .glassCard(cornerRadius: 18)

                    if let p = store.pendingSwitch, p.taskID == c.id {
                        SwitchBalloon(pending: p)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Adicione a primeira tarefa")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.white)
                    Text("Cada tarefa recebe uma rodada de \(TaskStore.defaultDuration / 60) minutos. Ao fim do tempo, o alarme toca e você decide quando trocar.")
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

/// Destaque da última nota de "onde parei".
struct LastStopNote: View {
    let note: NoteEntry

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "bookmark.fill")
                .font(.system(size: 11))
                .foregroundStyle(Theme.yellow)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text("ONDE PAREI · \(Format.date(note.date))")
                    .font(.system(size: 9.5, weight: .bold))
                    .tracking(1)
                    .foregroundStyle(Theme.textMuted)
                Text(note.text)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white.opacity(0.85))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Theme.yellow.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(Theme.yellow.opacity(0.2), lineWidth: 1))
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
        GlassGroup(spacing: 8) {
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
}

// MARK: - Onde parei (antes de trocar)

struct SwitchBalloon: View {
    @EnvironmentObject var store: TaskStore
    let pending: PendingSwitch
    @State private var text = ""
    @FocusState private var focused: Bool

    private var goLabel: String {
        if let name = store.switchTargetTitle(pending) {
            return "Salvar e ir para \"\(name)\""
        }
        return "Salvar e iniciar nova rodada"
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
            TextField("Exemplo: parei no item 3 da planilha", text: $text)
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
                Button("Continuar sem anotar") { store.confirmSwitch(note: "") }
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
    @Namespace private var selection

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Tab.allCases) { t in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { tab = t }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: t.icon)
                            .font(.system(size: 12, weight: .semibold))
                        Text(title(t))
                            .font(.system(size: 12.5, weight: .semibold))
                        Text("\(count(t))")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background((tab == t ? Color.black : Color.white).opacity(0.12), in: Capsule())
                    }
                    .foregroundStyle(tab == t ? Color.black : Color.white.opacity(0.8))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .background {
                        if tab == t {
                            Capsule()
                                .fill(Theme.yellow)
                                .matchedGeometryEffect(id: "tab", in: selection)
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .glassCard(cornerRadius: 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func title(_ t: Tab) -> String {
        switch t {
        case .queue: return "Fila"
        case .scheduled: return "Agendadas"
        case .archived: return "Arquivadas"
        case .history: return "Histórico"
        case .trash: return "Lixeira"
        }
    }

    private func count(_ t: Tab) -> Int {
        switch t {
        case .queue: return store.queue.count
        case .scheduled: return store.scheduled.count
        case .archived: return store.archived.count
        case .history: return store.completed.count
        case .trash: return store.trash.count
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
                EmptyHint(icon: "tray", text: "A fila está vazia. Digite uma tarefa acima e pressione Enter.")
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
    @State private var expanded = false

    private var isCurrent: Bool { position == 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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
                    HStack(spacing: 8) {
                        Text("\(task.durationSeconds / 60) min por rodada · total \(Format.duration(task.totalSeconds))")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textMuted)
                    }
                }

                Spacer()

                if !isCurrent {
                    ExpandChip(task: task, expanded: $expanded)
                }

                Text(isCurrent ? Format.clock(task.remaining) : "#\(position + 1)")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isCurrent ? Theme.yellow : Theme.textMuted)

                HStack(spacing: 4) {
                    if !isCurrent {
                        RowIconButton(icon: "play.fill", help: "Iniciar agora") { store.requestSwitch(to: task.id) }
                    }
                    RowIconButton(icon: "pencil", help: "Editar") { store.edit(task.id) }
                    RowIconButton(icon: "archivebox", help: "Arquivar para depois") {
                        withAnimation { store.archive(task.id) }
                    }
                }
            }

            if expanded && !isCurrent {
                VStack(alignment: .leading, spacing: 8) {
                    if let note = task.latestNote {
                        LastStopNote(note: note)
                    }
                    SubtaskPanel(task: task, compact: true)
                }
                .padding(.leading, 32)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassCard(cornerRadius: 18, tint: isCurrent ? Theme.yellow.opacity(0.1) : nil, interactive: true)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(isCurrent ? Theme.yellow.opacity(0.45) : Color.clear, lineWidth: 1)
        )
    }
}

/// Botão que mostra o progresso das subtarefas e expande a linha.
struct ExpandChip: View {
    let task: TaskItem
    @Binding var expanded: Bool

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { expanded.toggle() }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "checklist")
                    .font(.system(size: 11, weight: .semibold))
                if task.subtasks.isEmpty {
                    Text(task.notes.isEmpty ? "Subtarefas" : "Notas")
                        .font(.system(size: 11, weight: .semibold))
                } else {
                    Text("\(task.subtasksDone)/\(task.subtasks.count)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .monospacedDigit()
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .rotationEffect(.degrees(expanded ? 180 : 0))
            }
            .foregroundStyle(expanded ? Theme.yellow : Theme.textSecondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Color.white.opacity(expanded ? 0.1 : 0.05), in: Capsule())
            .overlay(Capsule().strokeBorder(expanded ? Theme.yellow.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .help(expanded ? "Recolher" : "Ver subtarefas e notas")
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

// MARK: - Agendadas

struct ScheduledSection: View {
    @EnvironmentObject var store: TaskStore
    @State private var title = ""
    @State private var date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var hasTime = false

    private var groups: [(day: Date, tasks: [TaskItem])] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: store.scheduled) { cal.startOfDay(for: $0.scheduledFor ?? Date()) }
        return grouped.keys.sorted().map { ($0, grouped[$0] ?? []) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    GlassField(placeholder: "Nova tarefa agendada…", text: $title, onSubmit: add)
                    Button(action: add) {
                        Label("Agendar", systemImage: "calendar.badge.plus")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .glassButton(prominent: true)
                }
                SchedulePicker(date: $date, hasTime: $hasTime)
                Text(hasTime
                     ? "A tarefa entrará na fila no dia e horário escolhidos, com notificação."
                     : "A tarefa entrará na fila no início do dia escolhido.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textMuted)
            }
            .padding(16)
            .glassCard(cornerRadius: 20)

            if store.scheduled.isEmpty {
                EmptyHint(icon: "calendar", text: "Nenhuma tarefa agendada. Use o campo acima para planejar tarefas de outros dias.")
            } else {
                ForEach(groups, id: \.day) { group in
                    Text(Format.day(group.day).uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .tracking(1.5)
                        .foregroundStyle(Theme.yellow.opacity(0.9))
                        .padding(.top, 6)
                        .padding(.leading, 4)
                    ForEach(group.tasks) { task in
                        ScheduledRow(task: task)
                    }
                }
            }
        }
    }

    private func add() {
        var when = date
        if !hasTime { when = Calendar.current.startOfDay(for: date) }
        store.addScheduled(title, date: when, hasTime: hasTime)
        title = ""
    }
}

struct ScheduledRow: View {
    @EnvironmentObject var store: TaskStore
    let task: TaskItem
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: task.scheduleHasTime ? "clock" : "calendar")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.yellow)
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.white)
                    TaskTagsLine(task: task)
                    if let d = task.scheduledFor {
                        Text("Entra na fila: \(Format.schedule(d, hasTime: task.scheduleHasTime))")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textMuted)
                    }
                }
                Spacer()
                ExpandChip(task: task, expanded: $expanded)
                Button {
                    withAnimation { store.moveScheduledToQueue(task.id) }
                } label: {
                    Label("Adicionar à fila", systemImage: "arrow.right.circle")
                        .font(.system(size: 12, weight: .semibold))
                }
                .glassButton()
                RowIconButton(icon: "pencil", help: "Editar e reagendar") { store.edit(task.id) }
                RowIconButton(icon: "trash", help: "Mover para a lixeira") {
                    withAnimation { store.moveToTrash(task.id) }
                }
            }
            if expanded {
                SubtaskPanel(task: task, compact: true)
                    .padding(.leading, 28)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassCard(cornerRadius: 18, interactive: true)
    }
}

// MARK: - Arquivadas

struct ArchivedSection: View {
    @EnvironmentObject var store: TaskStore

    var body: some View {
        VStack(spacing: 10) {
            if store.archived.isEmpty {
                EmptyHint(icon: "archivebox", text: "As tarefas arquivadas ficam aqui até que você as devolva à fila.")
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
                            Label("Voltar para a fila", systemImage: "arrow.uturn.left")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .glassButton()
                        RowIconButton(icon: "pencil", help: "Editar") { store.edit(task.id) }
                        RowIconButton(icon: "trash", help: "Mover para a lixeira") {
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
                EmptyHint(icon: "checkmark.seal", text: "As tarefas concluídas aparecem aqui com o tempo total dedicado a cada uma.")
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
        .confirmationDialog("Mover todo o histórico para a lixeira?", isPresented: $confirmClear) {
            Button("Mover para a lixeira", role: .destructive) { store.clearHistory() }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("As tarefas poderão ser recuperadas pela Lixeira por \(TaskStore.trashDays) dias.")
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
                     (task.subtasks.isEmpty ? "" : " · \(task.subtasksDone)/\(task.subtasks.count) subtarefas") +
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
            RowIconButton(icon: "trash", help: "Mover para a lixeira") {
                withAnimation { store.moveToTrash(task.id) }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassCard(cornerRadius: 18)
    }
}

/// Menu rápido para marcar/desmarcar tags de uma tarefa.
struct TagMenuButton: View {
    @EnvironmentObject var store: TaskStore
    let task: TaskItem

    var body: some View {
        Menu {
            if store.tags.isEmpty {
                Text("Crie tags na tela de Tags ou na edição da tarefa")
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
                Text("As tarefas permanecem na lixeira por \(TaskStore.trashDays) dias e depois são excluídas definitivamente.")
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
                            Text("Origem: \(task.deletedFrom?.label ?? "Fila") · exclusão definitiva em \(days) dia\(days == 1 ? "" : "s")")
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
                        RowIconButton(icon: "xmark", help: "Excluir definitivamente") {
                            withAnimation { store.deleteForever(task.id) }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .glassCard(cornerRadius: 18)
                }
            }
        }
        .confirmationDialog("Excluir definitivamente todos os itens da lixeira?", isPresented: $confirmEmpty) {
            Button("Excluir tudo", role: .destructive) { store.emptyTrash() }
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
