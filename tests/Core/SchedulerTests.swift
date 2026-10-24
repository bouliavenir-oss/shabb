import XCTest
@testable import ShabbatCore

final class SchedulerTests: XCTestCase {
    let origin = Date(timeIntervalSince1970: 1_800_000_000)
    func fixture(duration: Double = 600) -> (Media, Slot, Schedule) {
        let media = Media(title: "Film", filename: "film.mp4", duration: duration, bytes: 42, sha256: "hash")
        let slot = Slot(mediaID: media.id, start: origin, end: origin.addingTimeInterval(600))
        var plan = Schedule(); plan.timeZoneID = "UTC"; plan.slots = [slot]; plan.nightStart = 0; plan.nightEnd = 0
        return (media, slot, plan)
    }
    func testHalfOpenBoundaries() {
        let (media, slot, plan) = fixture()
        XCTAssertEqual(Scheduler.decision(at: origin.addingTimeInterval(-1), plan: plan, media: [media]), .black)
        XCTAssertEqual(Scheduler.decision(at: origin, plan: plan, media: [media]), .video(slotID: slot.id, mediaID: media.id, offset: 0, volume: 0.65))
        XCTAssertEqual(Scheduler.decision(at: slot.end, plan: plan, media: [media]), .black)
    }
    func testManualRelaunchRejoinsWallClock() {
        let (media, slot, plan) = fixture()
        XCTAssertEqual(Scheduler.decision(at: origin.addingTimeInterval(245), plan: plan, media: [media]), .video(slotID: slot.id, mediaID: media.id, offset: 245, volume: 0.65))
    }
    func testShortMovieBecomesBlackWithoutMovingNextSlot() {
        let (media, _, plan) = fixture(duration: 200)
        XCTAssertEqual(Scheduler.decision(at: origin.addingTimeInterval(201), plan: plan, media: [media]), .black)
        XCTAssertEqual(plan.slots[0].end, origin.addingTimeInterval(600))
    }
    func testLongMovieStopsAtEnd() {
        let (media, _, plan) = fixture(duration: 900)
        XCTAssertEqual(Scheduler.decision(at: origin.addingTimeInterval(600), plan: plan, media: [media]), .black)
    }
    func testAdjacentSlotsAreNotConflict() {
        let (media, slot, initial) = fixture(); var plan = initial
        plan.slots.append(Slot(start: slot.end, end: slot.end.addingTimeInterval(100)))
        XCTAssertTrue(Scheduler.problems(plan, media: [media]).isEmpty)
    }
    func testNestedOverlapRejectedAndFailsBlack() {
        let (media, _, initial) = fixture(); var plan = initial
        plan.slots.append(Slot(start: origin.addingTimeInterval(100), end: origin.addingTimeInterval(200)))
        XCTAssertFalse(Scheduler.problems(plan, media: [media]).isEmpty)
        XCTAssertEqual(Scheduler.decision(at: origin.addingTimeInterval(150), plan: plan, media: [media]), .black)
    }
    func testMissingMediaFailsBlack() {
        let (_, _, plan) = fixture()
        XCTAssertFalse(Scheduler.problems(plan, media: []).isEmpty)
        XCTAssertEqual(Scheduler.decision(at: origin, plan: plan, media: []), .black)
    }
    func testInvalidDurationAndVolumeRejected() {
        var (media, _, plan) = fixture(); media.duration = .nan
        plan.slots[0].volume = 2
        XCTAssertEqual(Scheduler.problems(plan, media: [media]).count, 2)
    }
    func testNightVolumeUsesPlanTimeZone() {
        let (media, slot, initial) = fixture(); var plan = initial
        plan.nightStart = 0; plan.nightEnd = 23; plan.nightVolume = 0.2
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = cal.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 1))!
        plan.slots[0].start = date; plan.slots[0].end = date.addingTimeInterval(600)
        XCTAssertEqual(Scheduler.decision(at: date, plan: plan, media: [media]), .video(slotID: slot.id, mediaID: media.id, offset: 0, volume: 0.2))
    }
    func testDSTGapRejected() {
        let result = Scheduler.resolve(DateComponents(year: 2026, month: 3, day: 29, hour: 2, minute: 30), zone: TimeZone(identifier: "Europe/Paris")!, repeated: .first)
        XCTAssertNil(result)
    }
    func testDSTFoldRequiresOccurrence() {
        let parts = DateComponents(year: 2026, month: 10, day: 25, hour: 2, minute: 30)
        let zone = TimeZone(identifier: "Europe/Paris")!
        let first = Scheduler.resolve(parts, zone: zone, repeated: .first)!
        let last = Scheduler.resolve(parts, zone: zone, repeated: .last)!
        XCTAssertEqual(last.timeIntervalSince(first), 3600)
    }
    func testThirtySixHoursOfDecisions() {
        let (media, _, initial) = fixture(duration: 3600); var plan = initial
        plan.slots = (0..<36).map { hour in
            let start = origin.addingTimeInterval(Double(hour * 3600))
            return Slot(mediaID: hour.isMultiple(of: 2) ? media.id : nil, start: start, end: start.addingTimeInterval(3600))
        }
        XCTAssertTrue(Scheduler.problems(plan, media: [media]).isEmpty)
        for second in stride(from: 0, to: 36 * 3600, by: 17) {
            let decision = Scheduler.decision(at: origin.addingTimeInterval(Double(second)), plan: plan, media: [media])
            if (second / 3600).isMultiple(of: 2) {
                guard case .video(_, _, let offset, _) = decision else { XCTFail("Expected video at \(second)"); return }
                XCTAssertEqual(offset, Double(second % 3600))
            } else { XCTAssertEqual(decision, .black) }
        }
    }
    func testCodableRoundTripPreservesAbsoluteInstants() throws {
        let (_, _, plan) = fixture()
        XCTAssertEqual(try JSONDecoder().decode(Schedule.self, from: JSONEncoder().encode(plan)), plan)
    }
}
