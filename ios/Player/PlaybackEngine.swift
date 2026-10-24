import AVFoundation
import UIKit
import Combine

@MainActor final class PlaybackEngine: ObservableObject {
    enum State: String { case idle, black, loading, playing, recovering, interrupted, failed }
    @Published private(set) var state: State = .idle
    @Published private(set) var isBlack = true
    @Published private(set) var active = false
    @Published private(set) var player = AVPlayer()
    private var task: Task<Void, Never>?
    private var plan = Schedule()
    private var media: [Media] = []
    private var files: [UUID: URL] = [:]
    private var currentSlot: UUID?
    private var failedSlots: Set<UUID> = []
    private var retries: [UUID: Int] = [:]
    private var generation = UUID()
    private var loadingSince = Date()
    private var lastProgress = Date()
    private var lastPosition = -1.0
    private var seeking = false
    private var interrupted = false
    private var suspended = false
    private var systemFailure = false
    private var lastMetrics = Date.distantPast
    private var observers: [NSObjectProtocol] = []
    let log: EventLog

    init(log: EventLog) {
        self.log = log
        player.allowsExternalPlayback = false // use our local external-display scene
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            let type = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let options = note.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            Task { @MainActor in
                guard let self, self.active else { return }
                if type == AVAudioSession.InterruptionType.began.rawValue {
                    self.interrupted = true; self.black(.interrupted)
                    self.log.add("interruption", "Début de l’interruption audio")
                } else if AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume) {
                    self.interrupted = false; self.currentSlot = nil
                    self.log.add("recovery", "Fin de l’interruption ; recalage sur l’horloge")
                    do { try self.configureAudio() } catch { self.systemFailure = true; self.log.add("audio-error", error.localizedDescription) }
                } else {
                    self.log.add("interruption", "Le système n’autorise pas la reprise ; maintien au noir")
                }
            }
        })
        observers.append(center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.systemFailure = true; self.black(.failed)
                self.player = AVPlayer(); self.player.allowsExternalPlayback = false
                self.log.add("system-failure", "Services multimédias réinitialisés : relancement manuel nécessaire selon les règles Apple")
            }
        })
        observers.append(center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let route = AVAudioSession.sharedInstance().currentRoute.outputs.map(\.portName).joined(separator: ", ")
                self.log.add("audio-route", route)
            }
        })
    }
    private func configureAudio() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .moviePlayback)
        try session.setActive(true)
    }
    func start(plan: Schedule, media: [Media], files: [UUID: URL]) throws {
        stop()
        try configureAudio()
        self.plan = plan; self.media = media; self.files = files
        failedSlots = []; retries = [:]; systemFailure = false; interrupted = false; suspended = false
        active = true; UIApplication.shared.isIdleTimerDisabled = true
        UIDevice.current.isBatteryMonitoringEnabled = true
        log.add("start", "Programme figé : \(plan.title), fuseau \(plan.timeZoneID)")
        task = Task { [weak self] in
            while !Task.isCancelled {
                self?.tick(Date())
                do { try await Task.sleep(nanoseconds: 250_000_000) } catch { break }
            }
        }
    }
    func stop() {
        task?.cancel(); task = nil; active = false; currentSlot = nil
        black(.idle); UIApplication.shared.isIdleTimerDisabled = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    func background() {
        guard active else { return }
        suspended = true; currentSlot = nil; black(.interrupted)
        log.add("background", "Application en arrière-plan : exécution vidéo non garantie, sortie mise au noir")
    }
    func foreground() {
        suspended = false
        if active { UIApplication.shared.isIdleTimerDisabled = true; log.add("foreground", "Reprise au premier plan, recalage horaire") }
    }
    private func black(_ next: State) {
        generation = UUID(); seeking = false
        isBlack = true; player.pause(); player.volume = 0
        player.replaceCurrentItem(with: nil)
        setState(next)
    }
    private func setState(_ next: State) {
        guard state != next else { return }
        state = next; log.add("state", next.rawValue)
    }
    private func load(slot: UUID, url: URL, now: Date) {
        black(.loading); currentSlot = slot
        loadingSince = now; lastProgress = now; lastPosition = -1
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
        log.add("load", slot.uuidString)
    }
    private func recover(slot: UUID, now: Date, reason: String) {
        let count = retries[slot, default: 0]
        log.add("playback-error", "\(slot): \(reason), tentative \(count)")
        if count < 2, case .video(_, let id, _, _) = Scheduler.decision(at: now, plan: plan, media: media), let url = files[id] {
            retries[slot] = count + 1; load(slot: slot, url: url, now: now); setState(.recovering)
        } else {
            failedSlots.insert(slot); black(.failed)
        }
    }
    private func tick(_ now: Date) {
        guard active, !interrupted, !suspended, !systemFailure else { return }
        if now.timeIntervalSince(lastMetrics) >= 60 {
            lastMetrics = now
            log.add("health", "battery=\(UIDevice.current.batteryLevel), charging=\(UIDevice.current.batteryState.rawValue), thermal=\(ProcessInfo.processInfo.thermalState.rawValue)")
        }
        switch Scheduler.decision(at: now, plan: plan, media: media) {
        case .black:
            if state != .black { currentSlot = nil; black(.black) }
        case .video(let slot, let id, let offset, let volume):
            guard !failedSlots.contains(slot) else { if state != .failed { black(.failed) }; return }
            guard let url = files[id], FileManager.default.fileExists(atPath: url.path) else {
                failedSlots.insert(slot); black(.failed); log.add("missing", id.uuidString); return
            }
            if currentSlot != slot { load(slot: slot, url: url, now: now) }
            guard let item = player.currentItem else { return }
            if item.status == .failed { recover(slot: slot, now: now, reason: item.error?.localizedDescription ?? "AVPlayerItem failed"); return }
            guard item.status == .readyToPlay else {
                if now.timeIntervalSince(loadingSince) > 15 { recover(slot: slot, now: now, reason: "Chargement > 15 s") }
                return
            }
            guard !seeking else {
                if now.timeIntervalSince(lastProgress) > 15 { recover(slot: slot, now: now, reason: "Repositionnement bloqué") }
                return
            }
            let position = player.currentTime().seconds
            if position.isFinite && position > lastPosition + 0.1 { lastProgress = now; lastPosition = position }
            if now.timeIntervalSince(lastProgress) > 12 { recover(slot: slot, now: now, reason: "Absence de progression > 12 s"); return }
            if isBlack || !position.isFinite || abs(position - offset) > 2 {
                seeking = true
                let token = generation
                player.seek(to: CMTime(seconds: offset, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
                    Task { @MainActor in
                        guard let self, self.generation == token, self.active else { return }
                        self.seeking = false
                        guard finished else { return }
                        // Never expose a stale frame after crossing a schedule boundary.
                        guard case .video(let stillSlot, _, _, let currentVolume) = Scheduler.decision(at: Date(), plan: self.plan, media: self.media), stillSlot == slot else { return }
                        // A successful seek is not evidence of decoded playback progress.
                        // Preserve the watchdog deadline so repeated seeks cannot hide a stall.
                        self.lastPosition = self.player.currentTime().seconds
                        self.player.volume = currentVolume; self.isBlack = false
                        self.player.play(); self.setState(.playing)
                        self.log.add("seek", "\(slot): position=\(offset)")
                    }
                }
            } else {
                player.volume = volume
                if player.timeControlStatus == .paused { player.play() }
                setState(.playing)
            }
        }
    }
}
