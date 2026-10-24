import SwiftUI
import UniformTypeIdentifiers
import AVKit

struct RootView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var engine: PlaybackEngine
    @State private var tab = 0
    init(model: AppModel) { self.model = model; engine = model.engine }
    var body: some View {
        Group {
            if engine.active {
                ZStack {
                    if model.externalConnected { Color.black.ignoresSafeArea() }
                    else { OutputView(engine: engine) }
                }
                // Hidden emergency exit; Guided Access protects against accidental interaction.
                .contentShape(Rectangle())
                .onLongPressGesture(minimumDuration: 4) { engine.stop(); model.log.add("stop", "Arrêt manuel par appui long") }
            } else {
                TabView(selection: $tab) {
                    home.tabItem { Label("Accueil", systemImage: "house") }.tag(0)
                    LibraryView(model: model).tabItem { Label("Bibliothèque", systemImage: "film.stack") }.tag(1)
                    ScheduleView(model: model).tabItem { Label("Programmation", systemImage: "calendar") }.tag(2)
                    preparation.tabItem { Label("Préparation", systemImage: "checkmark.shield") }.tag(3)
                    SettingsView(model: model).tabItem { Label("Paramètres", systemImage: "gearshape") }.tag(4)
                    DiagnosticsView(log: model.log).tabItem { Label("Diagnostics", systemImage: "waveform.path.ecg") }.tag(5)
                }
                .safeAreaInset(edge: .bottom) {
                    if !model.message.isEmpty {
                        HStack { if model.busy { ProgressView() }; Text(model.message).font(.footnote).textSelection(.enabled) }
                            .padding(10).frame(maxWidth: .infinity).background(.ultraThinMaterial)
                    }
                }
            }
        }.preferredColorScheme(.dark).tint(.cyan).task { await model.load() }
    }
    private var home: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text("Votre cinéma.\nÀ l’heure, hors ligne.").font(.system(size: 42, weight: .bold))
                    Text("ShabbatTV iPad · version de développement").foregroundStyle(.secondary)
                    HStack(spacing: 24) {
                        metric("Films locaux", "\(model.snapshot.media.count)", "film")
                        metric("Espace libre", ByteCountFormatter.string(fromByteCount: model.freeBytes, countStyle: .file), "internaldrive")
                        metric("Sortie dédiée", model.externalConnected ? "Connectée" : "Non détectée", "tv")
                    }
                    Text(model.snapshot.plan.title).font(.title)
                    if let next = model.snapshot.plan.slots.filter({ $0.end > Date() }).sorted(by: { $0.start < $1.start }).first {
                        Text("Prochain créneau : \(next.start.formatted(date: .abbreviated, time: .shortened))")
                    } else { Text("Ajoutez vos films, puis préparez votre programmation.") }
                    Button("Préparer mon Shabbat") { tab = 3 }.buttonStyle(.borderedProminent).controlSize(.large)
                    Text("Pour la diffusion : alimentation secteur, application au premier plan et essai HDMI préalable. Maintenir le doigt 4 secondes sur l’écran permet d’arrêter le mode autonome.")
                        .foregroundStyle(.secondary)
                }.padding(32)
            }.navigationTitle("ShabbatTV")
        }
    }
    private func metric(_ title: String, _ value: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon).foregroundStyle(.secondary)
            Text(value).font(.title2.bold())
        }.padding(24).frame(maxWidth: .infinity, alignment: .leading).background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 20))
    }
    private var preparation: some View {
        NavigationStack {
            List {
                Section("Avant de démarrer") {
                    Text("Vérification intégrale des fichiers requis : taille, SHA-256 et lecture locale. Cela peut prendre plusieurs minutes pour une grande vidéothèque.")
                    Button("VÉRIFIER MON SHABBAT HORS LIGNE") { Task { await model.verify() } }
                        .disabled(model.busy || !model.loaded)
                    ForEach(Array(model.checks.enumerated()), id: \.offset) { _, check in Text(check) }
                }
                Section {
                    Button("LANCER SHABBATTV") { Task { await model.verify(start: true) } }
                        .font(.title2.bold()).foregroundStyle(.cyan).disabled(model.busy || !model.loaded)
                    Text("Le lancement vérifie à nouveau les fichiers. Ensuite, les commandes sont masquées et le téléviseur affiche la vidéo ou du noir. La programmation continue jusqu’au dernier créneau, puis reste noire.")
                    Text("Vérifiez le son du téléviseur avant activation. Le volume logiciel ne règle pas le volume physique du téléviseur.")
                }
            }.navigationTitle("Prêt pour Shabbat")
        }
    }
}

struct LibraryView: View {
    @ObservedObject var model: AppModel
    @State private var importing = false
    @State private var query = ""
    @State private var rename: Media?
    @State private var title = ""
    @State private var preview: PreviewMedia?
    struct PreviewMedia: Identifiable { let id = UUID(); let url: URL }
    var body: some View {
        NavigationStack {
            List {
                ForEach(model.snapshot.media.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) }) { item in
                    HStack(spacing: 16) {
                        Image(systemName: "film").font(.largeTitle).foregroundStyle(.cyan)
                        VStack(alignment: .leading) {
                            Text(item.title).font(.headline)
                            Text("\(Int(item.duration / 60)) min · \(ByteCountFormatter.string(fromByteCount: item.bytes, countStyle: .file)) · \(item.audioTracks) piste(s) audio").font(.caption).foregroundStyle(.secondary)
                            if model.snapshot.plan.slots.contains(where: { $0.mediaID == item.id }) { Label("Protégé par le programme", systemImage: "lock.fill").font(.caption) }
                        }
                        Spacer()
                        Button("Voir") {
                            Task {
                                do { if let url = try await model.store?.url(for: item) { preview = PreviewMedia(url: url) } }
                                catch { model.message = error.localizedDescription }
                            }
                        }.buttonStyle(.bordered)
                        Menu {
                            Button("Renommer") { rename = item; title = item.title }
                            Button("Supprimer", role: .destructive) { Task { await model.delete(item) } }
                                .disabled(model.snapshot.plan.slots.contains { $0.mediaID == item.id })
                        } label: { Image(systemName: "ellipsis.circle").font(.title2) }
                    }.padding(.vertical, 10)
                }
            }.overlay { if model.snapshot.media.isEmpty { ContentUnavailableView("Votre bibliothèque locale", systemImage: "film.stack", description: Text("Importez des vidéos depuis Fichiers.")) } }
                .searchable(text: $query, prompt: "Rechercher un film")
                .navigationTitle("Bibliothèque")
                .toolbar { Button("Importer des vidéos", systemImage: "plus") { importing = true }.disabled(model.busy || !model.loaded) }
                .fileImporter(isPresented: $importing, allowedContentTypes: [.movie], allowsMultipleSelection: true) { result in
                    switch result {
                    case .success(let urls): Task { await model.importFiles(urls) }
                    case .failure(let error): model.message = error.localizedDescription
                    }
                }
                .sheet(item: $preview) { item in PreviewView(url: item.url) }
                .alert("Renommer", isPresented: Binding(get: { rename != nil }, set: { if !$0 { rename = nil } })) {
                    TextField("Titre", text: $title)
                    Button("Enregistrer") {
                        if let item = rename, let index = model.snapshot.media.firstIndex(where: { $0.id == item.id }) {
                            var next = model.snapshot; next.media[index].title = title
                            Task { await model.save(next) }
                        }
                        rename = nil
                    }
                    Button("Annuler", role: .cancel) { rename = nil }
                }.disabled(model.busy)
        }
    }
}
struct PreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer
    init(url: URL) { _player = State(initialValue: AVPlayer(url: url)) }
    var body: some View {
        NavigationStack {
            VideoPlayer(player: player).navigationTitle("Prévisualisation sur iPad")
                .toolbar { Button("Fermer") { dismiss() } }
                .onAppear { player.play() }.onDisappear { player.pause(); player.replaceCurrentItem(with: nil) }
        }
    }
}

struct ScheduleView: View {
    @ObservedObject var model: AppModel
    @State private var editing: Slot?
    private var zone: TimeZone { TimeZone(identifier: model.snapshot.plan.timeZoneID) ?? .current }
    var body: some View {
        NavigationStack {
            List {
                Section("\(model.snapshot.plan.title) · \(zone.identifier)") {
                    Text("Les horaires sont fixes. Les espaces vides sont noirs et silencieux. Touchez un créneau pour le déplacer, le raccourcir ou régler son volume.").font(.footnote)
                    ForEach(model.snapshot.plan.slots.sorted { $0.start < $1.start }) { slot in
                        Button { editing = slot } label: {
                            HStack(alignment: .top, spacing: 20) {
                                VStack(alignment: .leading) {
                                    Text(slot.start, format: Date.FormatStyle(date: .abbreviated, time: .shortened, timeZone: zone))
                                    Text(slot.end, format: Date.FormatStyle(date: .abbreviated, time: .shortened, timeZone: zone)).foregroundStyle(.secondary)
                                }.frame(width: 190, alignment: .leading)
                                RoundedRectangle(cornerRadius: 3).fill(slot.mediaID == nil ? Color.gray : .cyan).frame(width: 5)
                                VStack(alignment: .leading) {
                                    Text(model.snapshot.media.first { $0.id == slot.mediaID }?.title ?? "Écran noir").font(.headline)
                                    Text("\(Int(slot.end.timeIntervalSince(slot.start) / 60)) min · volume \(Int(slot.volume * 100)) %").font(.caption)
                                }
                            }.padding(.vertical, 12)
                        }.buttonStyle(.plain)
                        .contextMenu {
                            Button("Copier à la suite") {
                                var copy = slot; copy.id = UUID()
                                copy.start = slot.end; copy.end = slot.end.addingTimeInterval(slot.end.timeIntervalSince(slot.start)); editing = copy
                            }
                            Button("Supprimer le créneau", role: .destructive) {
                                var next = model.snapshot; next.plan.slots.removeAll { $0.id == slot.id }
                                Task { await model.save(next) }
                            }
                        }
                    }
                }
                Section("Contrôle de la grille") {
                    let problems = Scheduler.problems(model.snapshot.plan, media: model.snapshot.media)
                    if problems.isEmpty { Text("Aucun conflit structurel détecté.").foregroundStyle(.green) }
                    ForEach(Array(problems.enumerated()), id: \.offset) { _, problem in Text(problem).foregroundStyle(.orange) }
                }
            }.navigationTitle("Programmation")
                .toolbar {
                    Button("Ajouter un créneau", systemImage: "plus") {
                        let start = model.snapshot.plan.slots.map(\.end).max() ?? Date().addingTimeInterval(300)
                        editing = Slot(start: start, end: start.addingTimeInterval(1800))
                    }.disabled(model.busy || !model.loaded)
                }
                .sheet(item: $editing) { slot in SlotEditor(model: model, slot: slot) }
                .disabled(model.busy)
        }
    }
}

struct SlotEditor: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State var slot: Slot
    @State private var startText = ""
    @State private var endText = ""
    @State private var repeatedLast = false
    @State private var error = ""
    private var zone: TimeZone { TimeZone(identifier: model.snapshot.plan.timeZoneID) ?? .current }
    private var formatter: DateFormatter {
        let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = zone; f.dateFormat = "yyyy-MM-dd HH:mm"; return f
    }
    private func parse(_ text: String) -> Date? {
        // Parse numbers separately so DateFormatter cannot silently normalize a DST gap.
        let pieces = text.split(whereSeparator: { "- :".contains($0) }).compactMap { Int($0) }
        guard pieces.count == 5 else { return nil }
        return Scheduler.resolve(DateComponents(year: pieces[0], month: pieces[1], day: pieces[2], hour: pieces[3], minute: pieces[4], second: 0), zone: zone, repeated: repeatedLast ? .last : .first)
    }
    var body: some View {
        NavigationStack {
            Form {
                Picker("Programme", selection: $slot.mediaID) {
                    Text("Écran noir / silence").tag(nil as UUID?)
                    ForEach(model.snapshot.media) { Text($0.title).tag(Optional($0.id)) }
                }
                Section("Horaires · \(zone.identifier)") {
                    TextField("Début : AAAA-MM-JJ HH:mm", text: $startText).autocorrectionDisabled()
                    TextField("Fin : AAAA-MM-JJ HH:mm", text: $endText).autocorrectionDisabled()
                    Toggle("Heure répétée : deuxième occurrence (heure d’hiver)", isOn: $repeatedLast)
                    Text("Une heure inexistante au passage à l’heure d’été est refusée. La première occurrence est choisie par défaut lorsqu’une heure se répète.").font(.caption)
                    if let item = model.snapshot.media.first(where: { $0.id == slot.mediaID }) {
                        Button("Utiliser la durée du film (\(Int(item.duration / 60)) min)") {
                            if let start = parse(startText) { endText = formatter.string(from: start.addingTimeInterval(item.duration)) }
                        }
                        Text("Film trop court : noir jusqu’à la fin. Film trop long : coupure à l’heure de fin.").font(.caption)
                    }
                }
                if slot.mediaID != nil { Slider(value: $slot.volume, in: 0...1) { Text("Volume") }; Text("Volume : \(Int(slot.volume * 100)) %") }
                if !error.isEmpty { Text(error).foregroundStyle(.orange) }
            }.navigationTitle("Créneau")
                .onAppear { startText = formatter.string(from: slot.start); endText = formatter.string(from: slot.end) }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Enregistrer") {
                            guard let start = parse(startText), let end = parse(endText), end > start else { error = "Horaires invalides ou heure locale inexistante."; return }
                            slot.start = start; slot.end = end
                            if slot.mediaID == nil { slot.volume = 0 }
                            var next = model.snapshot; next.plan.slots.removeAll { $0.id == slot.id }; next.plan.slots.append(slot)
                            let problems = Scheduler.problems(next.plan, media: next.media)
                            guard problems.isEmpty else { error = problems.joined(separator: "\n"); return }
                            Task { await model.save(next); if model.snapshot == next { dismiss() } }
                        }
                    }
                }
        }
    }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var plan = Schedule()
    var body: some View {
        NavigationStack {
            Form {
                Section("Programmation") {
                    TextField("Nom du programme", text: $plan.title)
                    Picker("Fuseau", selection: $plan.timeZoneID) {
                        ForEach(TimeZone.knownTimeZoneIdentifiers, id: \.self) { Text($0).tag($0) }
                    }
                    Text("Changer le fuseau change l’affichage et les heures de volume nocturne. Les instants déjà programmés restent fixes.").font(.caption)
                }
                Section("Audio") {
                    Text("Plafond logiciel : \(Int(plan.volumeLimit * 100)) %"); Slider(value: $plan.volumeLimit, in: 0...1)
                    Text("Plafond nocturne : \(Int(plan.nightVolume * 100)) %"); Slider(value: $plan.nightVolume, in: 0...1)
                    Stepper("Nuit à partir de \(plan.nightStart) h", value: $plan.nightStart, in: 0...23)
                    Stepper("Fin de nuit à \(plan.nightEnd) h", value: $plan.nightEnd, in: 0...23)
                    Text("Ce plafond est un gain AVPlayer, pas un limiteur de crêtes ni une normalisation LUFS. Préparer les fichiers à −16 LUFS en amont.").font(.caption)
                }
                Section("Cloud") { Text("Version locale sans compte. Synchronisation Cloud prévue dans une phase ultérieure.") }
                Section {
                    Button("Enregistrer les paramètres") { var next = model.snapshot; next.plan = plan; Task { await model.save(next) } }
                        .disabled(model.busy || !model.loaded)
                    ShareLink("Exporter le programme (texte JSON)", item: exportText)
                }
            }.navigationTitle("Paramètres").onAppear { plan = model.snapshot.plan }
        }
    }
    private var exportText: String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; encoder.dateEncodingStrategy = .iso8601
        return (try? encoder.encode(model.snapshot.plan)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }
}
struct DiagnosticsView: View {
    @ObservedObject var log: EventLog
    var body: some View {
        NavigationStack {
            List {
                if let error = log.diskError { Text("Journal disque : \(error)").foregroundStyle(.orange) }
                ForEach(log.events.reversed()) { event in
                    VStack(alignment: .leading) {
                        Text("\(event.time.formatted(date: .omitted, time: .standard)) · \(event.kind)").font(.caption).foregroundStyle(.cyan)
                        Text(event.detail).font(.callout).textSelection(.enabled)
                    }
                }
            }.navigationTitle("Diagnostics").toolbar { ShareLink("Exporter le journal", item: log.file) }
        }
    }
}
