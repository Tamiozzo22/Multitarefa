import SwiftUI

enum TagFilter: Hashable {
    case all
    case untagged
    case tag(UUID)
}

enum TagScope: String, CaseIterable, Identifiable {
    case completed = "Concluídas"
    case all = "Todas"
    var id: String { rawValue }
}

/// Tela de tags: organiza e encontra tarefas (principalmente o histórico).
struct TagsView: View {
    @EnvironmentObject var store: TaskStore
    @State private var filter: TagFilter = .all
    @State private var scope: TagScope = .completed
    @State private var search = ""
    @State private var newTag = ""
    @State private var renaming: TagDef?
    @State private var renameText = ""

    private var baseTasks: [TaskItem] {
        switch scope {
        case .completed: return store.completed
        case .all: return store.queue + store.archived + store.completed
        }
    }

    private var results: [TaskItem] {
        let query = search.trimmingCharacters(in: .whitespaces).lowercased()
        return baseTasks.filter { t in
            let matchesFilter: Bool
            switch filter {
            case .all: matchesFilter = true
            case .untagged: matchesFilter = t.tagIDs.isEmpty
            case .tag(let id): matchesFilter = t.tagIDs.contains(id)
            }
            guard matchesFilter else { return false }
            if query.isEmpty { return true }
            return t.title.lowercased().contains(query)
                || t.notes.contains { $0.text.lowercased().contains(query) }
        }
    }

    private func count(_ f: TagFilter) -> Int {
        baseTasks.filter { t in
            switch f {
            case .all: return true
            case .untagged: return t.tagIDs.isEmpty
            case .tag(let id): return t.tagIDs.contains(id)
            }
        }.count
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            sidebar
                .frame(width: 230)
            resultsPane
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 22)
        .alert("Renomear tag", isPresented: Binding(
            get: { renaming != nil },
            set: { if !$0 { renaming = nil } })) {
            TextField("Nome da tag", text: $renameText)
            Button("Salvar") {
                if let r = renaming { store.renameTag(r.id, renameText) }
                renaming = nil
            }
            Button("Cancelar", role: .cancel) { renaming = nil }
        }
    }

    // MARK: Lateral

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                GlassField(placeholder: "Nova tag…", text: $newTag, onSubmit: createTag)
                Button(action: createTag) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                }
                .glassButton(prominent: true)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    filterRow(.all, label: "Todas", icon: "square.stack", color: Color.white)
                    filterRow(.untagged, label: "Sem tag", icon: "tag.slash", color: Theme.textSecondary)

                    if !store.tags.isEmpty {
                        Text("SUAS TAGS")
                            .font(.system(size: 10, weight: .bold))
                            .tracking(1.5)
                            .foregroundStyle(Theme.textMuted)
                            .padding(.top, 10)
                            .padding(.leading, 10)
                    }

                    ForEach(store.tags) { tag in
                        filterRow(.tag(tag.id), label: tag.name, icon: "circle.fill",
                                  color: Theme.tagColor(tag.color))
                            .contextMenu {
                                Button("Renomear…") {
                                    renameText = tag.name
                                    renaming = tag
                                }
                                Menu("Cor") {
                                    ForEach(Theme.tagColorNames.indices, id: \.self) { i in
                                        Button(Theme.tagColorNames[i]) { store.setTagColor(tag.id, i) }
                                    }
                                }
                                Divider()
                                Button("Excluir tag", role: .destructive) {
                                    if filter == .tag(tag.id) { filter = .all }
                                    store.deleteTag(tag.id)
                                }
                            }
                    }

                    if store.tags.isEmpty {
                        Text("Crie sua primeira tag acima. Depois marque as tarefas pelo botão de etiqueta ou ao editar.")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(10)
                    } else {
                        Text("Clique com o botão direito numa tag pra renomear, mudar a cor ou excluir.")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(10)
                    }
                }
            }
            .scrollIndicators(.visible)
        }
        .padding(14)
        .glassCard(cornerRadius: 22)
    }

    private func filterRow(_ f: TagFilter, label: String, icon: String, color: Color) -> some View {
        let selected = filter == f
        return Button {
            withAnimation(.spring(response: 0.25)) { filter = f }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: icon == "circle.fill" ? 8 : 12, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 16)
                Text(label)
                    .font(.system(size: 13, weight: selected ? .semibold : .regular))
                    .foregroundStyle(Color.white)
                    .lineLimit(1)
                Spacer()
                Text("\(count(f))")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textMuted)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(selected ? Theme.yellow.opacity(0.16) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(selected ? Theme.yellow.opacity(0.45) : Color.clear, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func createTag() {
        if let t = store.createTag(newTag) {
            filter = .tag(t.id)
        }
        newTag = ""
    }

    // MARK: Resultados

    private var resultsPane: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                GlassField(placeholder: "Buscar por título ou anotação…", text: $search)
                ForEach(TagScope.allCases) { s in
                    Button(s.rawValue) {
                        withAnimation(.spring(response: 0.25)) { scope = s }
                    }
                    .glassButton(prominent: scope == s)
                }
            }

            ScrollView {
                VStack(spacing: 10) {
                    if results.isEmpty {
                        EmptyHint(icon: "tag", text: emptyText)
                    } else {
                        ForEach(results) { task in
                            TagResultRow(task: task)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
            .scrollIndicators(.visible)
        }
    }

    private var emptyText: String {
        if !search.isEmpty { return "Nada encontrado pra \"\(search)\"." }
        switch filter {
        case .all: return scope == .completed ? "Nenhuma tarefa concluída ainda." : "Nenhuma tarefa ainda."
        case .untagged: return "Todas as tarefas já têm tag."
        case .tag: return "Nenhuma tarefa com essa tag. Marque pelo botão de etiqueta das tarefas."
        }
    }
}

struct TagResultRow: View {
    @EnvironmentObject var store: TaskStore
    let task: TaskItem

    private var status: (String, Color) {
        switch store.origin(of: task.id) {
        case .queue: return ("Na fila", Theme.yellow)
        case .archived: return ("Arquivada", Theme.textSecondary)
        case .completed: return ("Concluída", Color(red: 0.42, green: 0.86, blue: 0.55))
        case .none: return ("", Theme.textMuted)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(task.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.white)
                    Text(status.0)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(status.1)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(status.1.opacity(0.12), in: Capsule())
                }
                TaskTagsLine(task: task)
                Text("Total \(Format.duration(task.totalSeconds)) · \(task.rounds) rodada(s)" +
                     (task.completedAt.map { " · concluída \(Format.date($0))" } ?? ""))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textMuted)
            }
            Spacer()
            TagMenuButton(task: task)
            RowIconButton(icon: "pencil", help: "Ver e editar") { store.edit(task.id) }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassCard(cornerRadius: 18)
    }
}
