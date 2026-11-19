import SwiftUI

/// Edição de uma tarefa. As mudanças valem na hora, mesmo com o timer rodando.
struct EditTaskView: View {
    @EnvironmentObject var store: TaskStore
    @Environment(\.dismiss) private var dismiss
    let taskID: UUID

    @State private var title = ""
    @State private var newNote = ""
    @State private var minutes = 10
    @State private var newTag = ""

    var body: some View {
        ZStack {
            AppBackground()
            if let task = store.task(taskID) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack {
                            Text("Editar tarefa")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(Color.white)
                            Spacer()
                            Button("Concluído") { commitTitle(); dismiss() }
                                .glassButton(prominent: true)
                                .keyboardShortcut(.defaultAction)
                        }

                        section("Título") {
                            GlassField(placeholder: "Nome da tarefa", text: $title, onSubmit: commitTitle)
                        }

                        section("Tags") {
                            VStack(alignment: .leading, spacing: 10) {
                                if !store.tags.isEmpty {
                                    WrapHStack(spacing: 6) {
                                        ForEach(store.tags) { tag in
                                            Button {
                                                store.toggleTag(taskID, tag.id)
                                            } label: {
                                                TagChip(tag: tag, selected: task.tagIDs.contains(tag.id))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                                HStack(spacing: 8) {
                                    GlassField(placeholder: "Criar tag e marcar nesta tarefa…", text: $newTag, onSubmit: addTag)
                                    Button(action: addTag) {
                                        Image(systemName: "plus")
                                    }
                                    .glassButton()
                                }
                            }
                        }

                        section("Duração de cada rodada") {
                            VStack(alignment: .leading, spacing: 10) {
                                FlowChips(selected: minutes) { m in
                                    minutes = m
                                    store.setDuration(taskID, minutes: m)
                                }
                                HStack(spacing: 10) {
                                    Text("Personalizado")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.textSecondary)
                                    Stepper(value: Binding(
                                        get: { minutes },
                                        set: { m in
                                            minutes = m
                                            store.setDuration(taskID, minutes: m)
                                        }), in: 1...240) {
                                        Text("\(minutes) min")
                                            .font(.system(size: 13, weight: .semibold))
                                            .monospacedDigit()
                                            .foregroundStyle(Color.white)
                                    }
                                }
                            }
                        }

                        if store.queue.contains(where: { $0.id == taskID }) {
                            section("Tempo restante desta rodada") {
                                HStack(spacing: 8) {
                                    Text(Format.clock(task.remaining))
                                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                                        .monospacedDigit()
                                        .foregroundStyle(task.isTimeUp ? Theme.danger : Theme.yellow)
                                        .frame(minWidth: 86, alignment: .leading)
                                    ForEach([-5, -1, 1, 5], id: \.self) { m in
                                        Button(m > 0 ? "+\(m) min" : "\(m) min") {
                                            store.addTime(taskID, seconds: m * 60)
                                            minutes = (store.task(taskID)?.durationSeconds ?? minutes * 60) / 60
                                        }
                                        .glassButton()
                                    }
                                }
                            }
                        }

                        section("Anotações") {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 8) {
                                    GlassField(placeholder: "Nova anotação…", text: $newNote, onSubmit: addNote)
                                    Button(action: addNote) {
                                        Label("Adicionar", systemImage: "plus")
                                    }
                                    .glassButton(prominent: true)
                                }
                                if task.notes.isEmpty {
                                    Text("Nenhuma anotação ainda.")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.textMuted)
                                } else {
                                    ForEach(Array(task.notes.reversed())) { note in
                                        HStack(alignment: .top, spacing: 10) {
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(Format.date(note.date))
                                                    .font(.system(size: 11, weight: .semibold))
                                                    .foregroundStyle(Theme.yellow)
                                                Text(note.text)
                                                    .font(.system(size: 13))
                                                    .foregroundStyle(Color.white)
                                                    .textSelection(.enabled)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                            Spacer()
                                            RowIconButton(icon: "trash", help: "Apagar anotação") {
                                                store.deleteNote(taskID, noteID: note.id)
                                            }
                                        }
                                        .padding(12)
                                        .glassCard(cornerRadius: 14)
                                    }
                                }
                            }
                        }

                        HStack(spacing: 12) {
                            StatTile(value: Format.duration(task.totalSeconds), label: "tempo total")
                            StatTile(value: "\(task.rounds)", label: "rodadas")
                            Spacer()
                            if task.deletedAt == nil {
                                Button(role: .destructive) {
                                    store.moveToTrash(taskID)
                                    dismiss()
                                } label: {
                                    Label("Mover pra lixeira", systemImage: "trash")
                                        .foregroundStyle(Theme.danger)
                                }
                                .glassButton()
                            }
                        }
                    }
                    .padding(24)
                }
                .scrollIndicators(.visible)
                .onAppear {
                    title = task.title
                    minutes = task.durationSeconds / 60
                }
            } else {
                Text("Essa tarefa não existe mais.")
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .frame(width: 520, height: 620)
        .preferredColorScheme(.dark)
        .onDisappear(perform: commitTitle)
    }

    @ViewBuilder
    private func section<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(1.5)
                .foregroundStyle(Theme.textMuted)
            content()
        }
    }

    private func commitTitle() {
        store.setTitle(taskID, title)
    }

    private func addTag() {
        if let t = store.createTag(newTag), !(store.task(taskID)?.tagIDs.contains(t.id) ?? true) {
            store.toggleTag(taskID, t.id)
        }
        newTag = ""
    }

    private func addNote() {
        store.addNote(taskID, newNote)
        newNote = ""
    }
}

/// Botões rápidos de duração (5, 10, 15… min).
struct FlowChips: View {
    let selected: Int
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(TaskStore.durationPresets, id: \.self) { m in
                Button("\(m)") { onSelect(m) }
                    .glassButton(prominent: m == selected)
            }
            Text("min")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textMuted)
        }
    }
}

/// Linha que quebra quando não cabe (pras tags).
struct WrapHStack: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, lineHeight: CGFloat = 0, widest: CGFloat = 0
        for v in subviews {
            let size = v.sizeThatFits(.unspecified)
            if x > 0 && x + size.width > maxWidth {
                y += lineHeight + spacing
                x = 0
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: min(widest, maxWidth), height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, lineHeight: CGFloat = 0
        for v in subviews {
            let size = v.sizeThatFits(.unspecified)
            if x > bounds.minX && x + size.width > bounds.maxX {
                y += lineHeight + spacing
                x = bounds.minX
                lineHeight = 0
            }
            v.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}
