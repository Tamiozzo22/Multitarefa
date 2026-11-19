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
        case .checking, .downloading: return true
        default: return false
        }
    }

    var isReady: Bool {
        if case .ready = state { return true }
        return false
    }

    private var installerLaunched = false

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
            state = .failed("A atualização só funciona no app instalado.")
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
            state = .failed("Sem conexão com o GitHub. Tente de novo.")
            return
        }
        guard let http = response as? HTTPURLResponse, http.statusCode == 200, let data = data,
              let remote = try? JSONDecoder().decode(RemoteVersion.self, from: data) else {
            state = .failed("Não consegui ler a versão publicada. Tente de novo em alguns minutos.")
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
                DispatchQueue.main.async { self.state = .failed("O download falhou. Tente de novo.") }
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
                    self.state = .failed("Não consegui preparar a atualização (\(error.localizedDescription)).")
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
                          userInfo: [NSLocalizedDescriptionKey: "app não encontrado no DMG"])
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

    /// Fecha o app, troca pela versão nova e abre de novo.
    func installAndRelaunch() {
        guard isReady else { return }
        launchInstaller(relaunch: true)
        NSApp.terminate(nil)
    }

    /// Chamado quando o app fecha: se já tem atualização baixada, instala.
    func installOnQuitIfReady() {
        guard isReady else { return }
        launchInstaller(relaunch: false)
    }

    private func launchInstaller(relaunch: Bool) {
        guard !installerLaunched, FileManager.default.fileExists(atPath: stagedApp.path) else { return }
        installerLaunched = true
        let pid = ProcessInfo.processInfo.processIdentifier
        let target = installedApp.path
        let staged = stagedApp.path
        let script = """
        while kill -0 \(pid) 2>/dev/null; do sleep 0.3; done
        rm -rf "\(target).novo"
        if /usr/bin/ditto "\(staged)" "\(target).novo"; then
          rm -rf "\(target)" && mv "\(target).novo" "\(target)" && rm -rf "\(staged)"
        fi
        /usr/bin/xattr -dr com.apple.quarantine "\(target)" 2>/dev/null
        \(relaunch ? "/usr/bin/open \"\(target)\"" : "")
        """
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", script]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try? p.run()
    }
}
