import FilmDomain
import ImageIO
import RenderCore
import SwiftUI

/// The height of the Darkroom's controls, which the print preview leaves room for.
private struct ControlsHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// The Darkroom's print above its controls. The print takes the height the controls leave at their full size, and
/// below the navigation bar: the sheet's safe area starts under the bar, and the content scrolls only when even the
/// smallest print does not fit. The scroll area stops above the floating Reset to Original bar, so no control rests
/// under it, where its taps would reach the bar, and the last row scrolls fully clear of it. Rendering shows over the
/// print and an error between the print and the controls, both outside the measured controls, so neither resizes the
/// print on every render or rescales a Dodge/Burn stroke.
struct DarkroomLayout<Preview: View, Controls: View>: View {
    let rendering: Bool
    let error: String?
    @ViewBuilder let preview: Preview
    @ViewBuilder let controls: Controls
    /// The height of everything under the print, measured at the current text size.
    @State private var controlsHeight: CGFloat = 260

    /// The smallest height the print preview is scaled down to before the screen scrolls.
    private static var minimumPrintHeight: CGFloat { 160 }

    /// The controls' bottom margin, over which controls that run past the scroll area fade out rather than end in a
    /// sliver. The last row, scrolled fully into view, ends above it.
    private static var bottomMargin: CGFloat { 12 }

    /// The space between the scroll area and the floating Reset to Original bar. The bar itself is the bottom safe area,
    /// which takes every tap across the screen's width; kept off it, the scroll view ends above the bar instead of
    /// drawing controls under it.
    private static var bottomBarSpacing: CGFloat { 4 }

    private func printHeight(in available: CGFloat) -> CGFloat {
        max(Self.minimumPrintHeight, available - controlsHeight - 18 - 16 - Self.bottomMargin - Self.bottomBarSpacing)
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 18) {
                    preview.frame(maxWidth: .infinity).frame(height: printHeight(in: geometry.size.height))
                        .overlay(alignment: .topTrailing) {
                            if rendering { ProgressView().accessibilityLabel("Rendering print") }
                        }
                    if let error { Text(error).foregroundStyle(.red) }
                    VStack(spacing: 18) { controls }
                        .background(GeometryReader { Color.clear.preference(key: ControlsHeightKey.self, value: $0.size.height) })
                }.padding([.horizontal, .top]).padding(.bottom, Self.bottomMargin)
            }
            .onPreferenceChange(ControlsHeightKey.self) { controlsHeight = $0 }
            .mask {
                VStack(spacing: 0) {
                    Color.black
                    LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom).frame(height: Self.bottomMargin)
                }.ignoresSafeArea(edges: .top)
            }
            .padding(.bottom, Self.bottomBarSpacing)
        }
    }
}

/// Sets an Instant print's white card apart from a white screen: a hairline edge everywhere, and in the large views
/// also a margin and a soft shadow, so the card reads as a print in light and dark appearance. The margin is padding,
/// so the print fits inside whatever size the view is given.
private struct PrintCardEdge: ViewModifier {
    let isInstant: Bool
    var large = false

    func body(content: Content) -> some View {
        if isInstant {
            let edged = content.overlay(Rectangle().strokeBorder(Color.primary.opacity(0.22), lineWidth: 0.5))
            if large { edged.shadow(color: .primary.opacity(0.28), radius: 5, y: 1).padding(16) } else { edged }
        } else {
            content
        }
    }
}

struct RevealedPhoto: View {
    @Environment(JournalModel.self) private var model
    let filmID: UUID
    let sequence: Int
    /// Whether to set an Instant print's card apart from the screen, for the large views rather than thumbnails.
    var showsCardEdge = false
    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        ZStack {
            Rectangle().fill(Color(uiColor: .secondarySystemBackground))
            if !model.hiddenFilms.contains(filmID), let image {
                Image(uiImage: image).resizable().scaledToFit()
                    .modifier(PrintCardEdge(isInstant: model.film(filmID)?.camera.id == .instant1970s, large: showsCardEdge))
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
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack {
                if model.hiddenFilms.contains(filmID) { ProgressView("Removing photo") }
                else { RevealedPhoto(filmID: filmID, sequence: sequence, showsCardEdge: true) }
                if let error { Text(error).foregroundStyle(.red).padding() }
            }
            .navigationTitle("Photo \(sequence)").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItemGroup(placement: .bottomBar) {
                    Button("Darkroom", systemImage: "slider.horizontal.3") { editing = true }
                        .disabled(model.hiddenFilms.contains(filmID))
                    Spacer()
                    Button("Discard", systemImage: "trash", role: .destructive) { discarding = true }
                        .disabled(model.hiddenFilms.contains(filmID))
                }
            }
            .sheet(isPresented: $editing) { DarkroomView(filmID: filmID, sequence: sequence) }
            .confirmationDialog("Discard photo \(sequence)?", isPresented: $discarding, titleVisibility: .visible) {
                Button("Discard", role: .destructive) {
                    error = nil
                    model.perform {
                        try await model.remove(filmID, sequence: sequence)
                        dismiss()
                    } failure: { error = $0 }
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

    private var isInstant: Bool { model.film(filmID)?.camera.id == .instant1970s }

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
            DarkroomLayout(rendering: rendering, error: error) {
                printPreview
            } controls: {
                toolRow; Text(tool.rawValue).font(.headline); controls
            }
            .navigationTitle("Darkroom").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { renderTask?.cancel(); dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        error = nil
                        model.perform {
                            _ = try await model.processor.saveRecipe(filmID: filmID, sequence: sequence, recipe: recipe)
                            model.mediaRevision = UUID()
                            dismiss()
                        } failure: { error = $0 }
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

    /// The print scaled to fit its region, with an Instant card's margin and shadow inside it.
    @ViewBuilder private var printPreview: some View {
        if let image, !model.hiddenFilms.contains(filmID) {
            Image(uiImage: image).resizable().scaledToFit()
                .overlay { brushSurface }
                .accessibilityLabel("Photo \(sequence), print preview")
                .modifier(PrintCardEdge(isInstant: isInstant, large: true))
        } else { ProgressView() }
    }

    /// One tool per button across the width. The icons stop growing with the text size at the largest ordinary size,
    /// so five of them always fit inside the side margins.
    private var toolRow: some View {
        HStack {
            ForEach(PrintTool.allCases.filter { choice in
                choice != .toning || process.supportsChemicalToning
            }.filter { choice in choice != .filtration || process == .color }
                // An Instant print keeps its square picture and white card whole, so it has no crop.
                .filter { choice in choice != .crop || !isInstant }) { choice in
                Button { tool = choice } label: {
                    Image(systemName: choice.symbol).frame(maxWidth: .infinity, minHeight: 44)
                        .background(tool == choice ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                }.accessibilityLabel(choice.rawValue).help(choice.rawValue)
                    .accessibilityAddTraits(tool == choice ? .isSelected : [])
            }
        }.dynamicTypeSize(...DynamicTypeSize.xxxLarge)
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

    /// Dodge/Burn strokes. On an Instant print they are fractions of the picture and the card takes none, so the
    /// surface covers the picture only.
    @ViewBuilder private var brushSurface: some View {
        if tool == .brush && recipe.crop == nil {
            GeometryReader { geometry in
                let fractions = isInstant ? InstantPrintCard.pictureFractions : CGRect(x: 0, y: 0, width: 1, height: 1)
                let area = CGRect(x: fractions.minX * geometry.size.width, y: fractions.minY * geometry.size.height,
                                  width: fractions.width * geometry.size.width, height: fractions.height * geometry.size.height)
                Color.clear.frame(width: area.width, height: area.height).contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                        let point = MaskPoint(x: min(1, max(0, value.location.x / area.width)),
                                              y: min(1, max(0, value.location.y / area.height)))
                        if brushPoints.count < 500 { brushPoints.append(point) }
                    }.onEnded { _ in
                        recipe.dodgeBurnMasks.append(LocalMask(kind: brushKind, points: brushPoints, exposureStops: 0.4))
                        brushPoints = []; render()
                    })
                    .position(x: area.midX, y: area.midY)
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
