import AppKit
import SwiftUI
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if Notifier.available {
            UNUserNotificationCenter.current().delegate = self
            Notifier.requestPermission()
        }
    }

    /// Fechar a janela não fecha o app: o timer continua na barra de menus.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Se tem atualização baixada, instala quando o app fecha.
    func applicationWillTerminate(_ notification: Notification) {
        Updater.shared.installOnQuitIfReady()
    }

    /// Mostra a notificação mesmo com o app em primeiro plano.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .list])
    }
}

@main
struct MultitarefaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = TaskStore()

    var body: some Scene {
        Window("Multitarefa", id: "main") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 740, minHeight: 680)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 780, height: 880)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Configurações…") { store.showSettings = true }
                    .keyboardShortcut(",", modifiers: .command)
            }
            CommandMenu("Tarefas") {
                Button("Iniciar ou pausar") { store.toggleRunning() }
                    .keyboardShortcut(.return, modifiers: .command)
                Button("Próxima tarefa") { store.requestNext() }
                    .keyboardShortcut(.rightArrow, modifiers: .command)
                Button("Silenciar alarme") { store.stopAlarm() }
                    .keyboardShortcut(".", modifiers: .command)
                Button("Concluir tarefa atual") { store.completeCurrent() }
                    .keyboardShortcut("d", modifiers: .command)
                Button("Editar tarefa atual") {
                    if let c = store.current { store.edit(c.id) }
                }
                .keyboardShortcut("e", modifiers: .command)
            }
        }

        MenuBarExtra {
            MenuBarContent()
                .environmentObject(store)
        } label: {
            MenuBarLabel(store: store)
        }
    }
}

struct MenuBarLabel: View {
    @ObservedObject var store: TaskStore

    var body: some View {
        let icon = store.isTimeUp ? "bell.fill" : (store.isRunning ? "timer" : "pause.circle")
        if store.current == nil {
            Image(systemName: "timer")
        } else {
            Text("\(Image(systemName: icon)) \(store.menuBarText)")
                .monospacedDigit()
        }
    }
}

struct MenuBarContent: View {
    @EnvironmentObject var store: TaskStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        if let c = store.current {
            Text("Agora: \(c.title)")
            Text(c.isTimeUp ? "Tempo esgotado" : "Restam \(Format.clock(c.remaining)) · total \(Format.duration(c.totalSeconds))")
            Divider()
            if c.isTimeUp {
                Button("+5 min") { store.addTime(c.id, seconds: 5 * 60) }
            } else {
                Button(store.isRunning ? "Pausar" : "Iniciar") { store.toggleRunning() }
            }
            Button("Próxima tarefa…") {
                store.page = .tasks
                store.requestNext()
                openMain()
            }
            Button("Concluir tarefa atual") { store.completeCurrent() }
        } else {
            Text("Nenhuma tarefa na fila")
        }
        if store.alarmActive {
            Divider()
            Button("Silenciar alarme") { store.stopAlarm() }
        }
        Divider()
        Button("Abrir janela") { openMain() }
        Button("Sair do Multitarefa") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private func openMain() {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }
}
