import FilmDomain
import SwiftUI

struct CameraCatalogView: View {
    @Environment(\.dismiss) private var dismiss
    var loaded: (Film) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach([CameraMedium.photo, .movie], id: \.rawValue) { medium in
                    Section(medium == .photo ? "Photo" : "Movie") {
                        ForEach(CameraCatalog.all.filter { $0.medium == medium }) { camera in
                            NavigationLink {
                                LoadFilmView(camera: camera, loaded: loaded)
                            } label: {
                                HStack(spacing: 16) {
                                    Image(systemName: camera.symbol).font(.system(size: 24)).frame(width: 36)
                                        .accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(camera.shortName).font(.system(.title3, design: .serif))
                                        Text(camera.capacityLabel).font(.caption).foregroundStyle(.secondary)
                                    }.padding(.vertical, 8)
                                }
                            }.accessibilityIdentifier("camera-\(camera.id.rawValue)")
                        }
                    }
                }
            }
            .navigationTitle("Choose a Camera")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }.labelStyle(.iconOnly)
                }
            }
        }
    }
}

private struct LoadFilmView: View {
    @Environment(JournalModel.self) private var model
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let camera: CameraPackage
    var loaded: (Film) -> Void
    @State private var title = ""
    @State private var orientation = MovieOrientation.portrait
    @State private var loading = false
    @State private var error: String?
    @State private var samples = false

    var body: some View {
        Form {
            if let catalog = model.mediaCatalog, !catalog.assets(for: camera.id, purpose: .cameraSample).isEmpty {
                Section {
                    Button("Camera samples", systemImage: "photo.on.rectangle") { samples = true }
                }
            }
            Section {
                LabeledContent("Capacity", value: camera.capacityLabel)
                Text(camera.revealLabel)
                Text(camera.controlsLabel).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                if camera.medium == .movie {
                    HStack {
                        Image(systemName: "mic.slash").font(.system(size: 20)).accessibilityHidden(true)
                        Text("Silent capture").fixedSize(horizontal: false, vertical: true)
                    }.accessibilityElement(children: .combine)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Movie Orientation").fixedSize(horizontal: false, vertical: true)
                        if dynamicTypeSize.isAccessibilitySize { orientationPicker.pickerStyle(.menu).labelsHidden() }
                        else { orientationPicker.pickerStyle(.segmented).labelsHidden() }
                    }
                }
            }
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Film title").font(.headline).foregroundStyle(Color.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("film-title-heading")
                        .accessibilityAddTraits(.isHeader)
                    TextField("Title", text: $title, axis: .vertical)
                        .accessibilityLabel("Film title").accessibilityIdentifier("film-title")
                }
            }
            Section {
                Label(entitlementLabel, systemImage: "ticket")
                Text("The first saved capture uses the Trial. Your Camera and Movie Orientation cannot change after loading.")
                    .font(.footnote).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
            }
            Section { NavigationLink("Subscription") { SubscriptionView() } }
            if let error { Section { Text(error).foregroundStyle(.red) } }
            Section {
                Button {
                    loading = true
                    Task {
                        defer { loading = false }
                        do {
                            let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
                            let film = try await model.load(camera: camera, title: name.isEmpty ? suggestedTitle : name,
                                                            orientation: orientation)
                            loaded(film)
                        } catch {
                            switch error {
                            case JournalError.cameraDenied: self.error = "Camera access is off. No Film was loaded. Allow Camera in iPhone Settings."
                            case JournalError.trialInProgress: self.error = "A Trial Film is already waiting in your Journal. Open it or delete that empty Film first."
                            case JournalError.subscriptionUnavailable: self.error = "This iPhone's Trial is used. Subscriptions are not available in this build. Existing Films remain usable."
                            case JournalError.subscriptionRequired: self.error = "This iPhone's Trial is used. Subscribe or restore a current subscription to load another Film. Existing Films remain usable."
                            default: self.error = error.localizedDescription
                            }
                        }
                    }
                } label: {
                    HStack { Text("Load Film"); Spacer(); if loading { ProgressView() } else { Image(systemName: "camera") } }
                }.disabled(loading).accessibilityIdentifier("load-film")
            }
        }
        .navigationTitle(camera.shortName)
        .sheet(isPresented: $samples) { CameraSamplesView(camera: camera) }
        .task { if title.isEmpty { title = suggestedTitle } }
        .interactiveDismissDisabled(loading)
    }

    private var suggestedTitle: String {
        "\(camera.shortName) - Roll #\(String(format: "%02d", model.films.filter { $0.camera.id == camera.id }.count + 1))"
    }

    private var orientationPicker: some View {
        Picker("Movie Orientation", selection: $orientation) {
            Text("Portrait").tag(MovieOrientation.portrait)
            Text("Landscape").tag(MovieOrientation.landscape)
        }
    }

    private var entitlementLabel: String {
        if model.billing.access == .active { return "Subscription active" }
        switch model.trialState {
        case .unused: return "One Trial Film on this iPhone"
        case .emptyFilmInProgress: return "Trial Film already loaded"
        case .consumed: return "This iPhone's Trial is used"
        case nil: return model.trialError == nil ? "Checking Trial status" : "Trial status unavailable"
        }
    }
}
