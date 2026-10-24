import Foundation
import OSLog
import Combine

@MainActor final class EventLog: ObservableObject {
    struct Event: Codable, Identifiable {
        var id = UUID()
        var time = Date()
        var kind: String
        var detail: String
    }
    @Published private(set) var events: [Event] = []
    @Published private(set) var diskError: String?
    let file: URL
    private let logger = Logger(subsystem: "ShabbatTV", category: "Playback")
    init(root: URL) { file = root.appendingPathComponent("events.jsonl") }
    func add(_ kind: String, _ detail: String) {
        let event = Event(kind: kind, detail: detail)
        events.append(event)
        if events.count > 300 { events.removeFirst(events.count - 300) }
        logger.notice("\(kind, privacy: .public): \(detail, privacy: .private)")
        do {
            // Rotate to keep diagnostics bounded over long runs.
            let fm = FileManager.default
            if let size = (try? fm.attributesOfItem(atPath: file.path)[.size]) as? NSNumber,
               size.intValue > 4 * 1024 * 1024 {
                let previous = file.appendingPathExtension("previous")
                if fm.fileExists(atPath: previous.path) { try fm.removeItem(at: previous) }
                try fm.moveItem(at: file, to: previous)
            }
            if !fm.fileExists(atPath: file.path) { fm.createFile(atPath: file.path, contents: nil) }
            let handle = try FileHandle(forWritingTo: file); defer { try? handle.close() }
            try handle.seekToEnd()
            var data = try JSONEncoder().encode(event); data.append(0x0a)
            try handle.write(contentsOf: data)
        } catch { diskError = error.localizedDescription }
    }
}
