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
                .frame(minWidth: 460, minHeight: 520)
        }
        .defaultSize(width: 520, height: 680)
        .commands {
            CommandMenu("Tarefas") {
                Button("Iniciar ou pausar") { store.toggleRunning() }
                    .keyboardShortcut(.return, modifiers: .command)
                Button("Próxima tarefa") { store.skip() }
                    .keyboardShortcut(.rightArrow, modifiers: .command)
                Button("Concluir tarefa atual") { store.completeCurrent() }
                    .keyboardShortcut("d", modifiers: .command)
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
        let icon = store.isRunning ? "timer" : "pause.circle"
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
            Text("Restam \(Format.clock(c.remaining)) · total \(Format.duration(c.totalSeconds))")
            Divider()
            Button(store.isRunning ? "Pausar" : "Iniciar") { store.toggleRunning() }
            Button("Próxima tarefa") { store.skip() }
            Button("Concluir tarefa atual") { store.completeCurrent() }
        } else {
            Text("Nenhuma tarefa na fila")
        }
        Divider()
        Button("Abrir janela") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        Button("Sair do Multitarefa") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
