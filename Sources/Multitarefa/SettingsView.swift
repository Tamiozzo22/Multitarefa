import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: TaskStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var updater = Updater.shared

    var body: some View {
        ZStack {
            AppBackground()
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Configurações")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Color.white)
                    Spacer()
                    Button("Fechar") { dismiss() }
                        .glassButton()
                        .keyboardShortcut(.cancelAction)
                }

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.yellow)
                        Text("Atualizações")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.white)
                    }

                    Text("Versão instalada: \(updater.currentVersion)")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)

                    status

                    HStack(spacing: 8) {
                        if updater.isReady {
                            Button {
                                updater.installAndRelaunch()
                            } label: {
                                Label("Reiniciar e atualizar", systemImage: "arrow.clockwise")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .glassButton(prominent: true)
                        } else {
                            Button {
                                updater.check()
                            } label: {
                                Label("Buscar atualização", systemImage: "arrow.down.circle")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .glassButton(prominent: true)
                            .disabled(updater.isBusy)
                        }
                    }

                    Text("A nova versão é baixada e instalada automaticamente. Caso não reinicie agora, ela será aplicada quando o aplicativo for fechado.")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                .glassCard(cornerRadius: 20)

                Spacer(minLength: 0)

                HStack {
                    BrandLogo(height: 22)
                    Spacer()
                }
            }
            .padding(24)
        }
        .frame(width: 440, height: 380)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var status: some View {
        switch updater.state {
        case .idle:
            EmptyView()
        case .checking:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Verificando no GitHub…").statusStyle()
            }
        case .upToDate:
            Label("Você já está na versão mais recente.", systemImage: "checkmark.circle.fill")
                .statusStyle(color: Theme.yellow)
        case .downloading(let v):
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Baixando a versão \(v)…").statusStyle()
            }
        case .ready(let v):
            Label("A versão \(v) está pronta. Reinicie o aplicativo para utilizá-la.", systemImage: "sparkles")
                .statusStyle(color: Theme.yellow)
        case .installing:
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Instalando e reiniciando…").statusStyle()
            }
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .statusStyle(color: Theme.danger)
        }
    }
}

private extension View {
    func statusStyle(color: Color = Theme.textSecondary) -> some View {
        self.font(.system(size: 13, weight: .medium))
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }
}
