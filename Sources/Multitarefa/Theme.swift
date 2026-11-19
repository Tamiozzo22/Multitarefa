import AppKit
import SwiftUI

enum Theme {
    static let yellow = Color(red: 1.0, green: 0.78, blue: 0.17)
    static let yellowSoft = Color(red: 1.0, green: 0.886, blue: 0.55)
    static let background = Color(red: 0.035, green: 0.035, blue: 0.04)
    static let danger = Color(red: 1.0, green: 0.42, blue: 0.36)
    static let textSecondary = Color.white.opacity(0.62)
    static let textMuted = Color.white.opacity(0.4)
    static let hairline = Color.white.opacity(0.1)
}

/// Fundo escuro com brilhos amarelos suaves (dá profundidade para o vidro).
struct AppBackground: View {
    var body: some View {
        ZStack {
            Theme.background
            RadialGradient(colors: [Theme.yellow.opacity(0.22), .clear],
                           center: .topLeading, startRadius: 0, endRadius: 520)
            RadialGradient(colors: [Theme.yellow.opacity(0.10), .clear],
                           center: .bottomTrailing, startRadius: 0, endRadius: 460)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Vidro

extension View {
    /// Cartão de vidro. Usa o Liquid Glass nativo no macOS 26+.
    @ViewBuilder
    func glassCard(cornerRadius: CGFloat = 22, tint: Color? = nil) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(macOS 26.0, *) {
            if let tint = tint {
                self.glassEffect(.regular.tint(tint), in: shape)
            } else {
                self.glassEffect(.regular, in: shape)
            }
        } else {
            self
                .background(.ultraThinMaterial, in: shape)
                .background((tint ?? .clear).opacity(0.5), in: shape)
                .overlay(shape.strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
        }
    }

    /// Botão de vidro. `prominent` deixa amarelo (ação principal).
    func glassButton(prominent: Bool = false) -> some View {
        modifier(GlassButtonModifier(prominent: prominent))
    }
}

struct GlassButtonModifier: ViewModifier {
    let prominent: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            if prominent {
                content
                    .buttonStyle(.glassProminent)
                    .tint(Theme.yellow)
                    .foregroundStyle(Color.black)
            } else {
                content
                    .buttonStyle(.glass)
                    .foregroundStyle(Color.white)
            }
        } else {
            content.buttonStyle(FallbackGlassButtonStyle(prominent: prominent))
        }
    }
}

/// Imitação do vidro para macOS anteriores ao 26.
struct FallbackGlassButtonStyle: ButtonStyle {
    let prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .foregroundStyle(prominent ? Color.black : Color.white)
            .background {
                if prominent {
                    Capsule().fill(Theme.yellow)
                } else {
                    Capsule().fill(.ultraThinMaterial)
                }
            }
            .overlay(Capsule().strokeBorder(Color.white.opacity(prominent ? 0.3 : 0.15), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Campo de texto com cara de vidro.
struct GlassField: View {
    let placeholder: String
    @Binding var text: String
    var onSubmit: () -> Void = {}

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(.system(size: 14))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassCard(cornerRadius: 14)
            .onSubmit(onSubmit)
    }
}

// MARK: - Logo

/// Logo da empresa (Resources/logo.png dentro do app). Sem o arquivo, mostra o nome.
struct BrandLogo: View {
    var height: CGFloat = 30

    private static let image: NSImage? = {
        guard let url = Bundle.main.url(forResource: "logo", withExtension: "png") else { return nil }
        return NSImage(contentsOf: url)
    }()

    var body: some View {
        if let img = Self.image {
            Image(nsImage: img)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(height: height)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Text("IMPERA")
                    .font(.system(size: 16, weight: .heavy))
                    .tracking(3)
                    .foregroundStyle(Theme.yellow)
                Text("SERVICES")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(4)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }
}

// MARK: - Anel do timer

struct TimerRing: View {
    let remaining: Int
    let duration: Int
    let isRunning: Bool

    private var progress: Double {
        guard duration > 0 else { return 0 }
        return Double(remaining) / Double(duration)
    }

    private var color: Color {
        if remaining <= 0 { return Theme.danger }
        if remaining <= TaskStore.warningSeconds { return Color.orange }
        return Theme.yellow
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 12)
            Circle()
                .trim(from: 0, to: max(0.0001, progress))
                .stroke(color, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: color.opacity(0.5), radius: 8)
                .animation(.linear(duration: 0.5), value: progress)
            VStack(spacing: 2) {
                Text(Format.clock(remaining))
                    .font(.system(size: 38, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(remaining <= 0 ? Theme.danger : Color.white)
                Text(remaining <= 0 ? "tempo esgotado" : (isRunning ? "em andamento" : "pausado"))
                    .font(.system(size: 11, weight: .medium))
                    .textCase(.uppercase)
                    .tracking(1)
                    .foregroundStyle(Theme.textMuted)
            }
        }
        .frame(width: 168, height: 168)
    }
}

// MARK: - Tags

extension Theme {
    static let tagColors: [Color] = [
        Color(red: 1.0, green: 0.78, blue: 0.17),   // amarelo
        Color(red: 0.36, green: 0.78, blue: 0.98),  // azul
        Color(red: 0.42, green: 0.86, blue: 0.55),  // verde
        Color(red: 1.0, green: 0.55, blue: 0.35),   // laranja
        Color(red: 0.98, green: 0.45, blue: 0.62),  // rosa
        Color(red: 0.72, green: 0.58, blue: 1.0),   // roxo
        Color(red: 0.35, green: 0.85, blue: 0.82),  // turquesa
        Color(red: 0.78, green: 0.78, blue: 0.8),   // cinza
    ]

    static let tagColorNames = ["Amarelo", "Azul", "Verde", "Laranja", "Rosa", "Roxo", "Turquesa", "Cinza"]

    static func tagColor(_ index: Int) -> Color {
        tagColors[((index % tagColors.count) + tagColors.count) % tagColors.count]
    }
}

/// Etiqueta colorida de uma tag.
struct TagChip: View {
    let tag: TagDef
    var selected = true
    var small = false

    var body: some View {
        let color = Theme.tagColor(tag.color)
        HStack(spacing: 5) {
            Circle()
                .fill(color)
                .frame(width: small ? 6 : 7, height: small ? 6 : 7)
            Text(tag.name)
                .font(.system(size: small ? 10.5 : 12, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(selected ? color : Theme.textSecondary)
        .padding(.horizontal, small ? 7 : 10)
        .padding(.vertical, small ? 3 : 5)
        .background(color.opacity(selected ? 0.16 : 0.04), in: Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(selected ? 0.45 : 0.15), lineWidth: 1))
    }
}
