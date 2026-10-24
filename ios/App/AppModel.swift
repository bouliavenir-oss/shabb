import SwiftUI
import AVFoundation

@MainActor final class AppModel: ObservableObject {
    static let shared = AppModel()
    @Published var snapshot = LibrarySnapshot()
    @Published var busy = false
    @Published var message = ""
    @Published var checks: [String] = []
    @Published var externalConnected = false
    @Published var freeBytes: Int64 = 0
    @Published var loaded = false
    @Published var ready = false
    let store: LibraryStore?
    let log: EventLog
    let engine: PlaybackEngine
    private init() {
        do {
            let storage = try LibraryStore(); store = storage
            let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("ShabbatTV")
            log = EventLog(root: root)
        } catch {
            store = nil
            log = EventLog(root: FileManager.default.temporaryDirectory)
        }
        engine = PlaybackEngine(log: log)
    }
    func load() async {
        guard !loaded, !busy else { return }; busy = true; defer { busy = false }
        guard let store else { message = "Stockage indisponible. Activation impossible."; return }
        do { snapshot = try await store.load(); freeBytes = try await store.availableBytes(); loaded = true }
        catch { message = "Bibliothèque non chargée ; aucune donnée écrasée : \(error.localizedDescription)" }
    }
    func save(_ next: LibrarySnapshot) async {
        guard loaded, !engine.active, !busy, let store else { return }
        busy = true; ready = false; defer { busy = false }
        do { try await store.save(next); snapshot = next; message = "Enregistré." }
        catch { message = error.localizedDescription }
    }
    func importFiles(_ urls: [URL]) async {
        guard loaded, !busy, !engine.active, let store else { return }
        busy = true; ready = false; defer { busy = false }
        var failures: [String] = []
        for (index, url) in urls.enumerated() {
            message = "Import \(index + 1)/\(urls.count) : \(url.lastPathComponent)"
            do {
                let item = try await store.importFile(url, existing: snapshot.media)
                if !snapshot.media.contains(where: { $0.id == item.id }) {
                    var next = snapshot; next.media.append(item)
                    do { try await store.save(next); snapshot = next }
                    catch { try? await store.delete(item, plan: snapshot.plan); throw error }
                }
            } catch { failures.append("\(url.lastPathComponent) : \(error.localizedDescription)") }
        }
        freeBytes = (try? await store.availableBytes()) ?? 0
        message = failures.isEmpty ? "Import terminé." : failures.joined(separator: "\n")
    }
    func delete(_ item: Media) async {
        guard loaded, !busy, !engine.active, let store else { return }
        busy = true; ready = false; defer { busy = false }
        do {
            guard !snapshot.plan.slots.contains(where: { $0.mediaID == item.id }) else {
                throw LibraryError.invalid("Ce film est protégé par la programmation.")
            }
            // Metadata first: failed disk deletion leaves an orphan, never a broken library entry.
            var next = snapshot; next.media.removeAll { $0.id == item.id }
            try await store.save(next); snapshot = next
            try await store.delete(item, plan: next.plan)
            freeBytes = try await store.availableBytes()
        } catch { message = error.localizedDescription }
    }
    func verify(start: Bool = false) async {
        guard loaded, !busy, !engine.active, let store else { return }
        busy = true; ready = false; defer { busy = false }
        checks = []; var errors = Scheduler.problems(snapshot.plan, media: snapshot.media)
        if !snapshot.plan.slots.contains(where: { $0.end > Date() }) { errors.append("Aucun créneau à venir ou en cours.") }
        var files: [UUID: URL] = [:]
        let required = Set(snapshot.plan.slots.compactMap(\.mediaID))
        for item in snapshot.media where required.contains(item.id) {
            message = "Vérification intégrale : \(item.title)"
            do {
                try await store.verify(item); files[item.id] = try await store.url(for: item)
                checks.append("✓ \(item.title) — local, SHA-256 vérifié")
            } catch { errors.append(error.localizedDescription) }
        }
        do {
            freeBytes = try await store.availableBytes()
            if freeBytes < 512 * 1024 * 1024 { errors.append("Moins de 512 Mo libres pour les données de fonctionnement.") }
        } catch { errors.append(error.localizedDescription) }
        if let diskError = log.diskError { errors.append("Journal indisponible : \(diskError)") }
        checks += errors.map { "✗ " + $0 }
        checks.append("Fuseau figé : \(snapshot.plan.timeZoneID)")
        if snapshot.plan.timeZoneID != TimeZone.current.identifier { checks.append("⚠ Le fuseau du planning diffère de celui de l’iPad.") }
        if !externalConnected { checks.append("⚠ Aucun écran externe dédié détecté : vérifier le téléviseur ou utiliser le miroir.") }
        UIDevice.current.isBatteryMonitoringEnabled = true
        if UIDevice.current.batteryState != .charging && UIDevice.current.batteryState != .full {
            checks.append("⚠ Brancher l’iPad au secteur et vérifier la recharge effective.")
        }
        checks.append("⚠ Faire un essai en mode avion et activer Accès guidé avant Shabbat.")
        ready = errors.isEmpty
        message = ready ? "Médias requis vérifiés localement. Essai matériel hors ligne encore nécessaire." : "Corriger les erreurs avant le lancement."
        if start && ready {
            do { try engine.start(plan: snapshot.plan, media: snapshot.media, files: files) }
            catch { message = error.localizedDescription; ready = false; log.add("start-error", message) }
        }
    }
}
