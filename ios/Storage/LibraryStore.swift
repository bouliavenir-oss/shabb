import Foundation
import AVFoundation
import CryptoKit

struct LibrarySnapshot: Codable, Equatable {
    var version = 1
    var media: [Media] = []
    var plan = Schedule()
}

enum LibraryError: LocalizedError {
    case invalid(String)
    var errorDescription: String? { if case .invalid(let text) = self { return text }; return nil }
}

actor LibraryStore {
    let root: URL
    let mediaRoot: URL
    init() throws {
        root = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                          appropriateFor: nil, create: true).appendingPathComponent("ShabbatTV")
        mediaRoot = root.appendingPathComponent("Media", isDirectory: true)
        try FileManager.default.createDirectory(at: mediaRoot, withIntermediateDirectories: true)
        var folder = mediaRoot
        var values = URLResourceValues(); values.isExcludedFromBackup = true
        try folder.setResourceValues(values)
    }
    func load() throws -> LibrarySnapshot {
        let url = root.appendingPathComponent("library.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return LibrarySnapshot() }
        let snapshot = try JSONDecoder().decode(LibrarySnapshot.self, from: Data(contentsOf: url))
        guard snapshot.version == 1 else { throw LibraryError.invalid("Version de bibliothèque non prise en charge.") }
        return snapshot
    }
    func save(_ snapshot: LibrarySnapshot) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(snapshot).write(to: root.appendingPathComponent("library.json"), options: .atomic)
    }
    func url(for media: Media) throws -> URL {
        guard media.filename == (media.filename as NSString).lastPathComponent,
              !media.filename.isEmpty, media.filename != ".", media.filename != ".." else {
            throw LibraryError.invalid("Nom de fichier local invalide.")
        }
        return mediaRoot.appendingPathComponent(media.filename)
    }
    func availableBytes() throws -> Int64 {
        let values = try root.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        guard let free = values.volumeAvailableCapacityForImportantUsage else {
            throw LibraryError.invalid("Espace disponible indéterminé.")
        }
        return free
    }
    private func digest(_ url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
        var hash = SHA256()
        while let chunk = try handle.read(upToCount: 4 * 1024 * 1024), !chunk.isEmpty { hash.update(data: chunk) }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }
    func importFile(_ source: URL, existing: [Media]) async throws -> Media {
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        let id = UUID()
        let temporary = mediaRoot.appendingPathComponent(id.uuidString + ".partial")
        defer { try? FileManager.default.removeItem(at: temporary) }
        // File providers may materialize the item while coordinating this read.
        var coordinationError: NSError?
        var copyError: Error?
        NSFileCoordinator().coordinate(readingItemAt: source, options: [], error: &coordinationError) { readable in
            do {
                let size = try readable.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                let free = try root.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
                    .volumeAvailableCapacityForImportantUsage ?? 0
                guard free > Int64(size) + 512 * 1024 * 1024 else {
                    throw LibraryError.invalid("Espace insuffisant (réserve de 512 Mo).")
                }
                try FileManager.default.copyItem(at: readable, to: temporary)
            } catch { copyError = error }
        }
        if let error = coordinationError { throw error }
        if let error = copyError { throw error }
        let hash = try digest(temporary)
        if let duplicate = existing.first(where: { $0.sha256 == hash }) { return duplicate }
        let filename = id.uuidString + "." + source.pathExtension.lowercased()
        let final = mediaRoot.appendingPathComponent(filename)
        try FileManager.default.moveItem(at: temporary, to: final)
        do {
            let asset = AVURLAsset(url: final)
            guard try await asset.load(.isPlayable), try await asset.load(.hasProtectedContent) == false else {
                throw LibraryError.invalid("Vidéo illisible ou protégée.")
            }
            let duration = try await asset.load(.duration).seconds
            let video = try await asset.loadTracks(withMediaType: .video)
            let audio = try await asset.loadTracks(withMediaType: .audio)
            guard !video.isEmpty, duration.isFinite, duration > 0 else {
                throw LibraryError.invalid("Aucune vidéo de durée valide.")
            }
            let size = try final.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            return Media(id: id, title: source.deletingPathExtension().lastPathComponent, filename: filename,
                         duration: duration, bytes: Int64(size), sha256: hash, audioTracks: audio.count)
        } catch {
            try? FileManager.default.removeItem(at: final); throw error
        }
    }
    func verify(_ media: Media) async throws {
        let file = try url(for: media)
        let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize
        guard Int64(size ?? -1) == media.bytes, try digest(file) == media.sha256 else {
            throw LibraryError.invalid("Fichier incomplet ou modifié : \(media.title)")
        }
        let asset = AVURLAsset(url: file)
        guard try await asset.load(.isPlayable), try await asset.load(.hasProtectedContent) == false else {
            throw LibraryError.invalid("Film illisible : \(media.title)")
        }
    }
    func delete(_ media: Media, plan: Schedule) throws {
        guard !plan.slots.contains(where: { $0.mediaID == media.id }) else {
            throw LibraryError.invalid("Retirez d’abord ce film de la programmation.")
        }
        let file = try url(for: media)
        if FileManager.default.fileExists(atPath: file.path) { try FileManager.default.removeItem(at: file) }
    }
}
