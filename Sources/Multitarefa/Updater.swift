import AppKit
import Foundation

/// Versão publicada no GitHub (arquivo version.json do release "latest").
struct RemoteVersion: Codable {
    let version: String
    let build: Int
    let url: String
}

/// Busca atualização no GitHub, baixa o DMG e instala ao reiniciar (ou ao fechar o app).
final class Updater: ObservableObject {
    static let shared = Updater()

    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case downloading(String)
        case ready(String)
        case installing
        case failed(String)
    }

    @Published var state: State = .idle

    static let feedURL = URL(string: "https://github.com/Tamiozzo22/Multitarefa/releases/download/latest/version.json")!

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }

    var currentBuild: Int {
        Int(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0") ?? 0
    }

    var isBusy: Bool {
        switch state {
        case .checking, .downloading, .installing: return true
        default: return false
        }
    }

    var isReady: Bool {
        if case .ready = state { return true }
        return false
    }

    private var installed = false

    private var stagingDir: URL {
        Persistence.fileURL.deletingLastPathComponent().appendingPathComponent("Update", isDirectory: true)
    }

    private var stagedApp: URL {
        stagingDir.appendingPathComponent("Multitarefa.app", isDirectory: true)
    }

    private var installedApp: URL { Bundle.main.bundleURL }

    // MARK: - Verificar

    func check() {
        guard !isBusy, !isReady else { return }

        guard installedApp.pathExtension == "app" else {
            state = .failed("A atualização só funciona com o aplicativo instalado.")
            return
        }
        let parent = installedApp.deletingLastPathComponent().path
        guard FileManager.default.isWritableFile(atPath: parent), !parent.hasPrefix("/Volumes/") else {
            state = .failed("Mova o Multitarefa para a pasta Aplicativos antes de atualizar.")
            return
        }

        state = .checking
        var request = URLRequest(url: Self.feedURL)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 30
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.handleFeed(data: data, response: response, error: error)
            }
        }.resume()
    }

    private func handleFeed(data: Data?, response: URLResponse?, error: Error?) {
        if error != nil {
            state = .failed("Não foi possível conectar ao GitHub. Tente novamente.")
            return
        }
        guard let http = response as? HTTPURLResponse, http.statusCode == 200, let data = data,
              let remote = try? JSONDecoder().decode(RemoteVersion.self, from: data) else {
            state = .failed("Não foi possível ler a versão publicada. Tente novamente em alguns minutos.")
            return
        }
        guard remote.build > currentBuild, let url = URL(string: remote.url) else {
            state = .upToDate
            return
        }
        download(remote: remote, from: url)
    }

    // MARK: - Baixar e preparar

    private func download(remote: RemoteVersion, from url: URL) {
        state = .downloading(remote.version)
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 120
        URLSession.shared.downloadTask(with: request) { tempURL, response, error in
            guard let tempURL = tempURL, error == nil,
                  (response as? HTTPURLResponse)?.statusCode == 200 else {
                DispatchQueue.main.async { self.state = .failed("O download falhou. Tente novamente.") }
                return
            }
            let fm = FileManager.default
            let dmg = fm.temporaryDirectory.appendingPathComponent("Multitarefa-update-\(UUID().uuidString).dmg")
            do {
                try fm.moveItem(at: tempURL, to: dmg)
                try self.stage(dmg: dmg)
                try? fm.removeItem(at: dmg)
                DispatchQueue.main.async { self.state = .ready(remote.version) }
            } catch {
                try? fm.removeItem(at: dmg)
                DispatchQueue.main.async {
                    self.state = .failed("Não foi possível preparar a atualização (\(error.localizedDescription)).")
                }
            }
        }.resume()
    }

    /// Abre o DMG e copia o app novo para a pasta de preparação.
    private func stage(dmg: URL) throws {
        let fm = FileManager.default
        let mountPoint = fm.temporaryDirectory.appendingPathComponent("MultitarefaMount-\(UUID().uuidString)")
        try fm.createDirectory(at: mountPoint, withIntermediateDirectories: true)
        try run("/usr/bin/hdiutil", ["attach", dmg.path, "-nobrowse", "-readonly", "-noautoopen",
                                     "-mountpoint", mountPoint.path])
        defer {
            _ = try? run("/usr/bin/hdiutil", ["detach", mountPoint.path, "-force"])
            try? fm.removeItem(at: mountPoint)
        }
        let source = mountPoint.appendingPathComponent("Multitarefa.app")
        guard fm.fileExists(atPath: source.path) else {
            throw NSError(domain: "Updater", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "aplicativo não encontrado no DMG"])
        }
        try? fm.removeItem(at: stagedApp)
        try fm.createDirectory(at: stagingDir, withIntermediateDirectories: true)
        try run("/usr/bin/ditto", [source.path, stagedApp.path])
        _ = try? run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", stagedApp.path])
    }

    @discardableResult
    private func run(_ path: String, _ args: [String]) throws -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try p.run()
        p.waitUntilExit()
        if p.terminationStatus != 0 {
            throw NSError(domain: "Updater", code: Int(p.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: "\(URL(fileURLWithPath: path).lastPathComponent) falhou"])
        }
        return p.terminationStatus
    }

    // MARK: - Instalar

    /// Substitui o aplicativo instalado pela versão preparada.
    /// Funciona com o aplicativo aberto: o processo atual continua até ser reiniciado.
    private func swapInstalledApp() throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: stagedApp.path) else {
            throw NSError(domain: "Updater", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "a versão baixada não foi encontrada"])
        }
        let target = installedApp
        let parent = target.deletingLastPathComponent()
        let fresh = parent.appendingPathComponent(".Multitarefa-novo.app", isDirectory: true)
        let old = parent.appendingPathComponent(".Multitarefa-antigo.app", isDirectory: true)
        try? fm.removeItem(at: fresh)
        try? fm.removeItem(at: old)
        log("Instalando em \(target.path)")
        try run("/usr/bin/ditto", [stagedApp.path, fresh.path])
        _ = try? run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", fresh.path])
        try fm.moveItem(at: target, to: old)
        do {
            try fm.moveItem(at: fresh, to: target)
        } catch {
            try? fm.moveItem(at: old, to: target)
            throw error
        }
        try? fm.removeItem(at: old)
        try? fm.removeItem(at: stagedApp)
        installed = true
        log("Instalação concluída")
    }

    /// Instala a nova versão e reinicia o aplicativo.
    func installAndRelaunch() {
        guard isReady else { return }
        state = .installing
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try self.swapInstalledApp()
                DispatchQueue.main.async { self.relaunch() }
            } catch {
                self.log("Falha na instalação: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.state = .failed("Não foi possível instalar a atualização (\(error.localizedDescription)). Verifique se o Multitarefa está na pasta Aplicativos.")
                }
            }
        }
    }

    /// Abre o aplicativo novamente assim que este processo terminar.
    private func relaunch() {
        let pid = ProcessInfo.processInfo.processIdentifier
        let target = installedApp.path
        let script = "while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done; /usr/bin/open \"\(target)\""
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", script]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        do {
            try p.run()
        } catch {
            log("Falha ao agendar a reabertura: \(error.localizedDescription)")
        }
        log("Reiniciando")
        // Fecha janelas e folhas abertas antes de encerrar.
        for window in NSApp.windows {
            if let sheet = window.attachedSheet { window.endSheet(sheet) }
        }
        NSApp.terminate(nil)
        // Garantia: se o encerramento normal for bloqueado, encerra mesmo assim.
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { exit(0) }
    }

    /// Chamado quando o aplicativo é fechado: se já existe atualização baixada, instala.
    func installOnQuitIfReady() {
        guard isReady, !installed else { return }
        do {
            try swapInstalledApp()
        } catch {
            log("Falha na instalação ao fechar: \(error.localizedDescription)")
        }
    }

    // MARK: - Registro

    private func log(_ message: String) {
        let url = Persistence.fileURL.deletingLastPathComponent().appendingPathComponent("update.log")
        let line = "\(ISO8601DateFormatter().string(from: Date())) \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: url)
        }
    }
}
