import FilmDomain
import ImageIO
import RenderCore
import SwiftUI

struct RevealedPhoto: View {
    @Environment(JournalModel.self) private var model
    let filmID: UUID
    let sequence: Int
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        ZStack {
            Rectangle().fill(Color(uiColor: .secondarySystemBackground))
            if !model.hiddenFilms.contains(filmID), let image {
                Image(uiImage: image).resizable().scaledToFit()
            } else if failed { Image(systemName: "exclamationmark.triangle") }
            else { ProgressView() }
        }
        .task(id: model.mediaRevision) {
            image = nil
            failed = false
            guard !model.hiddenFilms.contains(filmID) else { return }
            do {
                let data = try await model.processor.photo(filmID: filmID, sequence: sequence)
                guard !Task.isCancelled, !model.hiddenFilms.contains(filmID) else { return }
                image = DisplayPhoto.image(data, maximumPixels: 600)
                failed = image == nil
            } catch { failed = true }
        }
        .onDisappear { image = nil }
        .accessibilityLabel("Developed photo \(sequence)")
    }
}

enum DisplayPhoto {
    static func image(_ data: Data, maximumPixels: Int = 1600) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: maximumPixels
              ] as CFDictionary) else { return nil }
        return UIImage(cgImage: image)
    }
}

struct PhotoView: View {
    @Environment(JournalModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let filmID: UUID
    let sequence: Int
    @State private var editing = false
    @State private var discarding = false

    var body: some View {
        NavigationStack {
            Group {
                if model.hiddenFilms.contains(filmID) { ProgressView("Removing photo") }
                else { RevealedPhoto(filmID: filmID, sequence: sequence) }
            }
            .navigationTitle("Photo \(sequence)").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("Darkroom", systemImage: "slider.horizontal.3") { editing = true }
                    Spacer()
                    Button("Discard", systemImage: "trash", role: .destructive) { discarding = true }
                }
            }
            .sheet(isPresented: $editing) { DarkroomView(filmID: filmID, sequence: sequence) }
            .confirmationDialog("Discard photo \(sequence)?", isPresented: $discarding, titleVisibility: .visible) {
                Button("Discard", role: .destructive) {
                    model.perform { try await model.remove(filmID, sequence: sequence); dismiss() }
                }.accessibilityIdentifier("confirm-discard-photo")
            } message: { Text(PrivacyCopy.discard) }
        }
    }
}

struct DarkroomView: View {
    @Environment(JournalModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let filmID: UUID
    let sequence: Int
    @State private var recipe = DarkroomRecipe.original
    @State private var process = PhotoPrintProcess.color
    @State private var image: UIImage?
    @State private var tool = PrintTool.exposure
    @State private var brushKind = LocalMask.Kind.dodge
    @State private var brushPoints: [MaskPoint] = []
    @State private var brushX = 0.5
    @State private var brushY = 0.5
    @State private var rendering = false
    @State private var renderTask: Task<Void, Never>?
    @State private var renderID = UUID()
    @State private var error: String?

    enum PrintTool: String, CaseIterable, Identifiable {
        case exposure = "Exposure", contrast = "Contrast", filtration = "Filtration", crop = "Crop", brush = "Dodge / Burn", toning = "Chemical toning"
        var id: Self { self }
        var symbol: String {
            switch self {
            case .exposure: "sun.max"
            case .contrast: "circle.lefthalf.filled"
            case .filtration: "camera.filters"
            case .crop: "crop"
            case .brush: "paintbrush.pointed"
            case .toning: "drop"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    if let image, !model.hiddenFilms.contains(filmID) {
                        Image(uiImage: image).resizable().scaledToFit()
                            .overlay { brushSurface }
                            .accessibilityLabel("Photo \(sequence), print preview")
                    } else { ProgressView().frame(height: 240) }
                    HStack {
                        ForEach(PrintTool.allCases.filter { choice in
                            choice != .toning || process.supportsChemicalToning
                        }.filter { choice in choice != .filtration || process == .color }) { choice in
                            Button { tool = choice } label: {
                                Image(systemName: choice.symbol).frame(maxWidth: .infinity, minHeight: 44)
                                    .background(tool == choice ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                            }.accessibilityLabel(choice.rawValue).help(choice.rawValue)
                                .accessibilityAddTraits(tool == choice ? .isSelected : [])
                        }
                    }
                    Text(tool.rawValue).font(.headline)
                    controls
                    if rendering { ProgressView("Rendering print") }
                    if let error { Text(error).foregroundStyle(.red) }
                }.padding()
            }
            .navigationTitle("Darkroom").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { renderTask?.cancel(); dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        model.perform {
                            _ = try await model.processor.saveRecipe(filmID: filmID, sequence: sequence, recipe: recipe)
                            model.mediaRevision = UUID()
                            dismiss()
                        }
                    }.disabled(rendering || model.hiddenFilms.contains(filmID))
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("Reset to Original", systemImage: "arrow.counterclockwise") { recipe.resetToOriginal(); render() }
                }
            }
            .task {
                do {
                    process = try model.repository.photoPrintProcess(filmID: filmID)
                    recipe = try model.repository.darkroomRecipe(filmID: filmID, sequence: sequence)
                    render()
                }
                catch { self.error = FailureCopy.message(for: error) }
            }
            .onDisappear { renderTask?.cancel(); image = nil }
        }
    }

    @ViewBuilder private var controls: some View {
        switch tool {
        case .exposure:
            Text("\(recipe.printExposureStops, specifier: "%.1f") stops").monospacedDigit()
            Slider(value: $recipe.printExposureStops, in: -2...2, step: 0.1, onEditingChanged: { if !$0 { render() } })
                .accessibilityLabel("Print exposure")
        case .contrast:
            Picker("Contrast grade", selection: Binding(get: { recipe.contrastGrade ?? -1 }, set: { recipe.contrastGrade = $0 < 0 ? nil : $0; render() })) {
                Text("Original").tag(-1)
                ForEach(0...5, id: \.self) { Text("Grade \($0)").tag($0) }
            }.pickerStyle(.menu)
        case .filtration:
            filtrationSlider("Cyan", path: \.cyan)
            filtrationSlider("Magenta", path: \.magenta)
            filtrationSlider("Yellow", path: \.yellow)
        case .toning:
            Picker("Chemical toning", selection: Binding(get: { recipe.chemicalToning?.chemistry }, set: {
                recipe.chemicalToning = $0.map { ChemicalToning(chemistry: $0, amount: 0.5) }; render()
            })) {
                Text("None").tag(Optional<ChemicalToning.Chemistry>.none)
                ForEach(ChemicalToning.Chemistry.allCases, id: \.self) { chemistry in
                    Text(chemistry.rawValue.capitalized).tag(Optional(chemistry))
                }
            }.pickerStyle(.menu)
            if recipe.chemicalToning != nil {
                Slider(value: Binding(get: { recipe.chemicalToning?.amount ?? 0 }, set: {
                    recipe.chemicalToning?.amount = $0
                }), in: 0...1, onEditingChanged: { if !$0 { render() } }).accessibilityLabel("Toning amount")
            }
        case .crop:
            Toggle("Crop", isOn: Binding(get: { recipe.crop != nil }, set: {
                recipe.crop = $0 ? Crop(x: 0, y: 0, width: 1, height: 1) : nil; render()
            }))
            if let crop = recipe.crop {
                Text("Size").font(.caption)
                Slider(value: Binding(get: { crop.width }, set: {
                    let size = $0
                    recipe.crop = Crop(x: min(crop.x, 1 - size), y: min(crop.y, 1 - size), width: size, height: size)
                }), in: 0.2...1, onEditingChanged: { if !$0 { render() } }).accessibilityLabel("Crop size")
                if crop.width < 1 {
                    cropPosition("Horizontal", x: true)
                    cropPosition("Vertical", x: false)
                }
            }
        case .brush:
            Picker("Local exposure", selection: $brushKind) {
                Text("Dodge").tag(LocalMask.Kind.dodge)
                Text("Burn").tag(LocalMask.Kind.burn)
            }.pickerStyle(.segmented)
            VStack(alignment: .leading) {
                Text("Horizontal: \(Int(brushX * 100))%").monospacedDigit()
                Slider(value: $brushX, in: 0...1, step: 0.05)
                    .accessibilityLabel("Local exposure horizontal position")
                    .accessibilityValue("\(Int(brushX * 100)) percent from left")
                Text("Vertical: \(Int(brushY * 100))%").monospacedDigit()
                Slider(value: $brushY, in: 0...1, step: 0.05)
                    .accessibilityLabel("Local exposure vertical position")
                    .accessibilityValue("\(Int(brushY * 100)) percent from top")
                Button(brushKind == .dodge ? "Dodge point" : "Burn point", systemImage: "plus.circle") {
                    recipe.dodgeBurnMasks.append(LocalMask(kind: brushKind,
                        points: [MaskPoint(x: brushX, y: brushY)], exposureStops: 0.4))
                    render()
                }
            }.disabled(recipe.crop != nil)
            Button("Undo last stroke", systemImage: "arrow.uturn.backward") {
                _ = recipe.dodgeBurnMasks.popLast(); render()
            }.disabled(recipe.dodgeBurnMasks.isEmpty)
        }
    }

    private func filtrationSlider(_ name: String, path: WritableKeyPath<ColorFiltration, Double>) -> some View {
        VStack(alignment: .leading) {
            Text(name).font(.caption)
            Slider(value: Binding(get: { (recipe.colorFiltration ?? ColorFiltration())[keyPath: path] }, set: {
                var filtration = recipe.colorFiltration ?? ColorFiltration()
                filtration[keyPath: path] = $0
                recipe.colorFiltration = filtration
            }), in: -30...30, step: 1, onEditingChanged: { if !$0 { render() } }).accessibilityLabel(name)
        }
    }

    private func cropPosition(_ name: String, x: Bool) -> some View {
        VStack(alignment: .leading) {
            Text(name).font(.caption)
            Slider(value: Binding(get: { x ? recipe.crop!.x : recipe.crop!.y }, set: {
                if x { recipe.crop?.x = $0 } else { recipe.crop?.y = $0 }
            }), in: 0...max(0.001, 1 - (recipe.crop?.width ?? 1)), onEditingChanged: { if !$0 { render() } })
                .accessibilityLabel("Crop \(name)")
        }
    }

    @ViewBuilder private var brushSurface: some View {
        if tool == .brush && recipe.crop == nil {
            GeometryReader { geometry in
                Color.clear.contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                        let point = MaskPoint(x: min(1, max(0, value.location.x / geometry.size.width)),
                                              y: min(1, max(0, value.location.y / geometry.size.height)))
                        if brushPoints.count < 500 { brushPoints.append(point) }
                    }.onEnded { _ in
                        recipe.dodgeBurnMasks.append(LocalMask(kind: brushKind, points: brushPoints, exposureStops: 0.4))
                        brushPoints = []; render()
                    })
            }
        }
    }

    private func render() {
        renderTask?.cancel()
        let id = UUID()
        renderID = id
        let selected = recipe
        rendering = true
        renderTask = Task {
            do {
                let data = try await model.processor.photo(filmID: filmID, sequence: sequence, recipe: selected)
                guard !Task.isCancelled, renderID == id, !model.hiddenFilms.contains(filmID) else { return }
                image = DisplayPhoto.image(data)
                error = nil
            } catch { if !Task.isCancelled { self.error = FailureCopy.message(for: error) } }
            if renderID == id { rendering = false }
        }
    }
}
