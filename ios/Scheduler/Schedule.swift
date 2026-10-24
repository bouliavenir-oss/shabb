import Foundation

public struct Media: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var filename: String
    public var duration: Double
    public var bytes: Int64
    public var sha256: String
    public var audioTracks: Int
    public init(id: UUID = UUID(), title: String, filename: String, duration: Double,
                bytes: Int64, sha256: String, audioTracks: Int = 0) {
        self.id = id; self.title = title; self.filename = filename; self.duration = duration
        self.bytes = bytes; self.sha256 = sha256; self.audioTracks = audioTracks
    }
}

public struct Slot: Codable, Identifiable, Equatable, Sendable {
    public var id: UUID
    public var mediaID: UUID? // nil means an explicitly silent black interval
    public var start: Date
    public var end: Date
    public var volume: Float
    public init(id: UUID = UUID(), mediaID: UUID? = nil, start: Date, end: Date, volume: Float = 0.65) {
        self.id = id; self.mediaID = mediaID; self.start = start; self.end = end; self.volume = volume
    }
}

public struct Schedule: Codable, Equatable, Sendable {
    public var title = "Mon Shabbat"
    public var timeZoneID = TimeZone.current.identifier
    public var slots: [Slot] = []
    public var volumeLimit: Float = 0.85
    public var nightVolume: Float = 0.35
    public var nightStart = 23
    public var nightEnd = 7
    public init() {}
}

public enum Decision: Equatable {
    case black
    case video(slotID: UUID, mediaID: UUID, offset: Double, volume: Float)
}

public enum Scheduler {
    public static func problems(_ plan: Schedule, media: [Media]) -> [String] {
        var errors: [String] = []
        if TimeZone(identifier: plan.timeZoneID) == nil { errors.append("Fuseau horaire invalide.") }
        if !plan.volumeLimit.isFinite || !(0...1).contains(plan.volumeLimit) ||
            !plan.nightVolume.isFinite || !(0...1).contains(plan.nightVolume) {
            errors.append("Limites de volume invalides.")
        }
        if !(0...23).contains(plan.nightStart) || !(0...23).contains(plan.nightEnd) {
            errors.append("Heures de nuit invalides.")
        }
        if Set(plan.slots.map(\.id)).count != plan.slots.count { errors.append("Identifiants de créneaux dupliqués.") }
        let sorted = plan.slots.sorted { $0.start < $1.start }
        for (index, slot) in sorted.enumerated() {
            if slot.end <= slot.start { errors.append("Créneau de durée nulle ou négative.") }
            if !slot.volume.isFinite || !(0...1).contains(slot.volume) { errors.append("Volume invalide.") }
            if sorted.prefix(index).contains(where: { max($0.start, slot.start) < min($0.end, slot.end) }) {
                errors.append("Chevauchement de programmes.")
            }
            if let id = slot.mediaID {
                guard let item = media.first(where: { $0.id == id }) else {
                    errors.append("Film absent de la bibliothèque."); continue
                }
                if !item.duration.isFinite || item.duration <= 0 { errors.append("Durée du film invalide.") }
            }
        }
        return errors
    }

    public static func decision(at now: Date, plan: Schedule, media: [Media]) -> Decision {
        let active = plan.slots.filter { $0.start <= now && now < $0.end }
        guard active.count == 1, let slot = active.first, let id = slot.mediaID,
              let item = media.first(where: { $0.id == id }) else { return .black }
        let offset = now.timeIntervalSince(slot.start)
        guard offset < item.duration else { return .black }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: plan.timeZoneID) ?? TimeZone(secondsFromGMT: 0)!
        let hour = calendar.component(.hour, from: now)
        let night = plan.nightStart > plan.nightEnd
            ? hour >= plan.nightStart || hour < plan.nightEnd
            : hour >= plan.nightStart && hour < plan.nightEnd
        let cap = night ? min(plan.volumeLimit, plan.nightVolume) : plan.volumeLimit
        return .video(slotID: slot.id, mediaID: id, offset: offset, volume: max(0, min(slot.volume, cap)))
    }

    // Strict local-time conversion: nonexistent times are rejected and repeated times
    // require an explicit first/last occurrence. Storage always contains absolute instants.
    public static func resolve(_ components: DateComponents, zone: TimeZone,
                               repeated: Calendar.RepeatedTimePolicy) -> Date? {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = zone
        guard let year = components.year, let month = components.month, let day = components.day,
              let noon = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))
        else { return nil }
        let anchor = calendar.startOfDay(for: noon).addingTimeInterval(-1)
        guard let date = calendar.nextDate(after: anchor, matching: components,
             matchingPolicy: .strict, repeatedTimePolicy: repeated, direction: .forward),
             calendar.isDate(date, inSameDayAs: noon) else { return nil }
        return date
    }
}
