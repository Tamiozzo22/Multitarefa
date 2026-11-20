import SwiftUI

/// Barra de progresso das subtarefas ("2 de 5").
struct SubtaskProgress: View {
    let done: Int
    let total: Int

    var body: some View {
        HStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(Theme.yellow.opacity(0.85))
                        .frame(width: total == 0 ? 0 : geo.size.width * CGFloat(done) / CGFloat(total))
                        .animation(.spring(response: 0.35), value: done)
                }
            }
            .frame(height: 5)
            Text("\(done) de \(total)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.textSecondary)
                .fixedSize()
        }
    }
}

/// Uma linha de subtarefa com caixa de seleção.
struct SubtaskRow: View {
    @EnvironmentObject var store: TaskStore
    let taskID: UUID
    let subtask: Subtask
    var editable = false
    var compact = false

    @State private var text = ""
    @State private var hover = false

    var body: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.3)) { store.toggleSubtask(taskID, subtask.id) }
            } label: {
                Image(systemName: subtask.done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: compact ? 14 : 16, weight: .regular))
                    .foregroundStyle(subtask.done ? Theme.yellow : Theme.textSecondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .help(subtask.done ? "Marcar como pendente" : "Marcar como concluída")

            if editable {
                TextField("Subtarefa", text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(subtask.done ? Theme.textMuted : Color.white)
                    .strikethrough(subtask.done, color: Theme.textMuted)
                    .onSubmit { store.renameSubtask(taskID, subtask.id, text) }
                    .onAppear { text = subtask.text }
            } else {
                Text(subtask.text)
                    .font(.system(size: compact ? 12 : 13))
                    .foregroundStyle(subtask.done ? Theme.textMuted : Color.white)
                    .strikethrough(subtask.done, color: Theme.textMuted)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if editable {
                HStack(spacing: 2) {
                    miniButton("chevron.up", help: "Mover para cima") { store.moveSubtask(taskID, subtask.id, by: -1) }
                    miniButton("chevron.down", help: "Mover para baixo") { store.moveSubtask(taskID, subtask.id, by: 1) }
                    miniButton("trash", help: "Excluir subtarefa") {
                        withAnimation { store.deleteSubtask(taskID, subtask.id) }
                    }
                }
                .opacity(hover ? 1 : 0.45)
            } else if hover && !compact {
                miniButton("xmark", help: "Excluir subtarefa") {
                    withAnimation { store.deleteSubtask(taskID, subtask.id) }
                }
            }
        }
        .padding(.vertical, compact ? 2 : 4)
        .contentShape(Rectangle())
        .onHover { hover = $0 }
    }

    private func miniButton(_ icon: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 22, height: 22)
                .background(Color.white.opacity(0.06), in: Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

/// Campo para adicionar subtarefa.
struct AddSubtaskField: View {
    @EnvironmentObject var store: TaskStore
    let taskID: UUID
    @State private var text = ""

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle")
                .font(.system(size: 16))
                .foregroundStyle(Theme.yellow.opacity(0.8))
            TextField("Adicionar subtarefa…", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Color.white)
                .onSubmit(add)
            if !text.trimmingCharacters(in: .whitespaces).isEmpty {
                Button("Adicionar", action: add)
                    .glassButton(prominent: true)
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }

    private func add() {
        withAnimation(.spring(response: 0.3)) { store.addSubtask(taskID, text) }
        text = ""
    }
}

/// Painel de subtarefas usado no cartão principal e nas linhas expandidas.
struct SubtaskPanel: View {
    @EnvironmentObject var store: TaskStore
    let task: TaskItem
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 4 : 6) {
            HStack(spacing: 8) {
                Image(systemName: "checklist")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.yellow)
                Text("SUBTAREFAS")
                    .font(.system(size: 10.5, weight: .bold))
                    .tracking(1.5)
                    .foregroundStyle(Theme.textMuted)
                if !task.subtasks.isEmpty {
                    SubtaskProgress(done: task.subtasksDone, total: task.subtasks.count)
                        .frame(maxWidth: 200)
                }
                Spacer()
            }
            .padding(.bottom, 2)

            ForEach(task.subtasks) { sub in
                SubtaskRow(taskID: task.id, subtask: sub, compact: compact)
            }

            AddSubtaskField(taskID: task.id)
        }
    }
}

/// Seleção de data e horário opcional para agendar.
struct SchedulePicker: View {
    @Binding var date: Date
    @Binding var hasTime: Bool

    var body: some View {
        HStack(spacing: 12) {
            DatePicker("", selection: $date, in: Calendar.current.startOfDay(for: Date())...,
                       displayedComponents: hasTime ? [.date, .hourAndMinute] : [.date])
                .labelsHidden()
                .datePickerStyle(.compact)
            Toggle("Definir horário", isOn: $hasTime)
                .toggleStyle(.switch)
                .controlSize(.small)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
        }
    }
}
