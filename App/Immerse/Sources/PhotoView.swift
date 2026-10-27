import FilmDomain
import ImageIO
import RenderCore
import SwiftUI

/// The Darkroom's print and its controls, in one arrangement in every hold: `DarkroomView` holds the window upright (the
/// captain, 2026-10-26: "No darkroom on landscape across all cameras").
///
/// The print takes what the screen leaves above one band of fixed height, so its frame is the same whatever tool is
/// selected (the captain, 2026-10-26: "Darkroom - keep the screen size consistent."); it differs between iPhones, never
/// between tools. The band holds the tool buttons and the selected tool's controls and is as tall as the tallest tool
/// needs at the default text size (`controlBandHeight`). At larger text sizes, and under an error or the note about saved
/// Dodge/Burn strokes, the band scrolls inside itself and shows that it does (`BandScrollView`); the print never
/// shrinks. Rendering shows over the print. Reset to Original stays in the bottom bar.
struct DarkroomLayout<Preview: View, Tools: View, Controls: View, Reset: View>: View {
    let rendering: Bool
    let error: String?
    @ViewBuilder let preview: Preview
    /// One button per tool, in a row across the band.
    @ViewBuilder let tools: Tools
    @ViewBuilder let controls: Controls
    @ViewBuilder let reset: Reset

    /// The band's height: what Adjust needs at the default text size with a crop smaller than the print, the tallest
    /// any tool gets. That is the 16 pt top margin, the 44 pt tool row, the Adjust heading's row with its turn buttons,
    /// five rows of a caption beside its control (Straighten, Crop and the crop's Size, Horizontal and Vertical), the
    /// gaps between them and the bottom margin, held whole on an iPhone SE by `PopulatedWorkflowTests`.
    private static var controlBandHeight: CGFloat { 330 }
    /// The space between the band's rows.
    private static var spacing: CGFloat { 12 }
    private static var bottomMargin: CGFloat { 12 }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                preview.frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(alignment: .topTrailing) { progress }
                    .accessibilityIdentifier("darkroom-print-area")
                BandScrollView {
                    VStack(alignment: .leading, spacing: Self.spacing) {
                        if let error { Text(error).foregroundStyle(.red) }
                        HStack { tools }
                        controls
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding([.horizontal, .top])
                    .padding(.bottom, Self.bottomMargin)
                }
                .accessibilityIdentifier("darkroom-control-band")
                .frame(height: min(Self.controlBandHeight, geometry.size.height))
                .mask { fade }
            }
        }
        .toolbar { ToolbarItem(placement: .bottomBar) { reset } }
    }

    @ViewBuilder private var progress: some View {
        if rendering { ProgressView().accessibilityLabel("Rendering print") }
    }

    /// The scroll area, with its last `bottomMargin` fading out.
    private var fade: some View {
        VStack(spacing: 0) {
            Color.black
            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom).frame(height: Self.bottomMargin)
        }.ignoresSafeArea(edges: .top)
    }
}

/// The Darkroom band's scroll area. Where its content runs more than a point past what it shows, it flashes its scroll
/// indicator, so a band that cannot show everything shows that it scrolls: 0.6 s after its content comes to run past
/// it, as the Darkroom opens and whenever a tool's controls, an explanation or a larger text size come to run past it.
/// The wait is longer than the sheet takes to rise, since a flash at the band's first layout, as the sheet rises, is not
/// drawn, nor is one asked for in the same update as the content grows, before the scroll view has its new height. It
/// flashes only as its content comes to run past it, never as it comes to fit, and a band that holds everything never
/// flashes.
private struct BandScrollView<Content: View>: View {
    @ViewBuilder let content: Content
    @State private var overflows = false
    @State private var flashes = 0

    var body: some View {
        ScrollView { content }
            .scrollBounceBehavior(.basedOnSize)
            .onScrollGeometryChange(for: Bool.self) { $0.contentSize.height > $0.containerSize.height + 1 } action: {
                overflows = $1
            }
            .scrollIndicatorsFlash(trigger: flashes)
            .task(id: overflows) {
                guard overflows else { return }
                try? await Task.sleep(for: .seconds(0.6))
                if !Task.isCancelled { flashes += 1 }
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
    let isInstantReveal: Bool
    @State private var shownSequence: Int
    @State private var editing = false
    @State private var discarding = false
    @State private var error: String?

    init(filmID: UUID, sequence: Int, isInstantReveal: Bool = false) {
        self.filmID = filmID
        self.sequence = sequence
        self.isInstantReveal = isInstantReveal
        _shownSequence = State(initialValue: sequence)
    }

    private var developedSequences: [Int] {
        guard !isInstantReveal else { return [shownSequence] }
        return model.film(filmID)?.captures
            .filter { $0.revealState == .revealed && !$0.isDiscarded }
            .map(\.sequenceNumber).sorted() ?? []
    }

    private var position: Int? { developedSequences.firstIndex(of: shownSequence).map { $0 + 1 } }
    private var count: Int { developedSequences.count }
    private var photoLabel: String { "Photo \(shownSequence), \(position ?? 1) of \(count)" }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if model.hiddenFilms.contains(filmID) { ProgressView("Removing photo") }
                else {
                    RevealedPhoto(filmID: filmID, sequence: shownSequence, showsCardEdge: true)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(photoLabel)
                        .accessibilityIdentifier("photo-view-image")
                        .accessibilityAction(named: Text("Previous photo")) { move(by: -1) }
                        .accessibilityAction(named: Text("Next photo")) { move(by: 1) }
                        .gesture(DragGesture(minimumDistance: 32).onEnded { value in
                            guard !isInstantReveal, abs(value.translation.width) > abs(value.translation.height),
                                  abs(value.translation.width) >= 48 else { return }
                            move(by: value.translation.width < 0 ? 1 : -1)
                        }, including: isInstantReveal ? .none : .all)
                }
                if let error { Text(error).foregroundStyle(.red).padding() }
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Photo \(shownSequence)").navigationBarTitleDisplayMode(.inline)
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
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.black, for: .bottomBar)
            .sheet(isPresented: $editing) { DarkroomView(filmID: filmID, sequence: shownSequence) }
            .confirmationDialog("Discard photo \(shownSequence)?", isPresented: $discarding, titleVisibility: .visible) {
                Button("Discard", role: .destructive) {
                    error = nil
                    let discardedSequence = shownSequence
                    model.perform {
                        try await model.remove(filmID, sequence: discardedSequence)
                        if !isInstantReveal,
                           let next = model.film(filmID)?.captures
                            .filter({ $0.revealState == .revealed && !$0.isDiscarded && $0.sequenceNumber > discardedSequence })
                            .map(\.sequenceNumber).min() {
                            shownSequence = next
                        } else { dismiss() }
                    } failure: { error = $0 }
                }.accessibilityIdentifier("confirm-discard-photo")
            } message: { Text(PrivacyCopy.discard) }
        }
    }

    private func move(by offset: Int) {
        guard !isInstantReveal, let current = developedSequences.firstIndex(of: shownSequence) else { return }
        let target = current + offset
        guard developedSequences.indices.contains(target) else { return }
        error = nil
        shownSequence = developedSequences[target]
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
    @State private var rendering = false
    @State private var renderTask: Task<Void, Never>?
    @State private var renderID = UUID()
    @State private var error: String?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var isInstant: Bool { model.film(filmID)?.camera.id == .instant1970s }

    /// Captions sit beside their sliders through the extra large text size, which keeps the tallest tool inside the
    /// band at the default size; at larger sizes they sit above their sliders and the band scrolls.
    private var captionsBeside: Bool { dynamicTypeSize <= .xLarge }

    enum PrintTool: String, CaseIterable, Identifiable {
        case exposure = "Exposure", contrast = "Contrast", filtration = "Filtration", adjust = "Adjust"
        case saturation = "Saturation", vignette = "Vignette", toning = "Chemical toning"
        var id: Self { self }
        var symbol: String {
            switch self {
            case .exposure: "sun.max"
            case .contrast: "circle.lefthalf.filled"
            case .filtration: "camera.filters"
            case .adjust: "crop.rotate"
            case .saturation: "slider.horizontal.3"
            case .vignette: "circle.dashed"
            case .toning: "drop"
            }
        }
    }

    var body: some View {
        NavigationStack {
            DarkroomLayout(rendering: rendering, error: error) {
                printPreview
            } tools: {
                tools
            } controls: {
                if !recipe.dodgeBurnMasks.isEmpty {
                    Text("This print keeps its earlier Dodge/Burn strokes until Reset to Original.")
                        .font(.footnote)
                        .accessibilityIdentifier("darkroom-legacy-strokes-note")
                }
                heading
                controls
            } reset: {
                Button("Reset to Original", systemImage: "arrow.counterclockwise") { recipe.resetToOriginal(); render() }
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
            }
            .holdsPortraitOrientationPreservingCurrent()
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
                .accessibilityLabel("Photo \(sequence), print preview")
                .modifier(PrintCardEdge(isInstant: isInstant, large: true))
        } else if error != nil, !rendering {
            // A print that cannot be made, such as one whose saved recipe is outside the limits, has no preview to wait for.
            Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundStyle(.secondary)
                .accessibilityLabel("Print unavailable")
        } else { ProgressView() }
    }

    /// One button per tool in the fixed controls band. The icons stop growing with the text size at the largest ordinary
    /// size so every tool remains reachable across the row.
    private var tools: some View {
        ForEach(PrintTool.allCases.filter { choice in
            choice != .toning || process.supportsChemicalToning
        }.filter { choice in choice != .filtration || process == .color }
            .filter { choice in choice != .saturation || process == .color }) { choice in
            Button { tool = choice } label: {
                Image(systemName: choice.symbol).frame(maxWidth: .infinity, minHeight: 44)
                    .background(tool == choice ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
            }.accessibilityLabel(choice.rawValue).help(choice.rawValue)
                .accessibilityAddTraits(tool == choice ? .isSelected : [])
        }.dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    /// The selected tool's name, and on Adjust its two quarter-turn buttons beside it, which every print offers, the
    /// Instant's included.
    private var heading: some View {
        HStack {
            Text(tool.rawValue).font(.headline)
            if tool == .adjust {
                Spacer()
                Button { recipe.rotateLeft(); render() } label: { turnLabel("Rotate left", systemImage: "rotate.left") }
                    .accessibilityIdentifier("darkroom-rotate-left")
                Button { recipe.rotateRight(); render() } label: { turnLabel("Rotate right", systemImage: "rotate.right") }
                    .accessibilityIdentifier("darkroom-rotate-right")
            }
        }
        .buttonStyle(.bordered).buttonBorderShape(.circle)
        .frame(minHeight: 44)
    }

    /// A quarter-turn button's icon, with the circle the bordered style draws around it 44 points across, a whole tap
    /// target.
    private func turnLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage).labelStyle(.iconOnly).frame(width: 30, height: 30)
    }

    @ViewBuilder private var controls: some View {
        switch tool {
        case .exposure:
            Text(StopsText.shown(recipe.printExposureStops)).monospacedDigit()
            Slider(value: Binding(get: { recipe.printExposureStops }, set: {
                recipe.printExposureStops = StopsText.tenths($0, in: DarkroomLimits.printExposureStops)
            }), in: DarkroomLimits.printExposureStops, step: DarkroomLimits.exposureStep, onEditingChanged: { if !$0 { render() } })
                .accessibilityLabel("Print exposure")
                .accessibilityValue(StopsText.spoken(recipe.printExposureStops))
        case .contrast:
            Picker("Contrast grade", selection: Binding(get: { recipe.contrastGrade ?? -1 }, set: { recipe.contrastGrade = $0 < 0 ? nil : $0; render() })) {
                Text("Original").tag(-1)
                ForEach(DarkroomLimits.contrastGrades, id: \.self) { Text("Grade \($0)").tag($0) }
            }.pickerStyle(.menu)
        case .filtration:
            captionedSliders {
                filtrationSlider("Cyan", path: \.cyan)
                filtrationSlider("Magenta", path: \.magenta)
                filtrationSlider("Yellow", path: \.yellow)
            }
        case .saturation:
            Text("\(recipe.saturation ?? 0)").monospacedDigit()
            Slider(value: Binding(get: { Double(recipe.saturation ?? 0) }, set: {
                let value = Int($0.rounded())
                recipe.saturation = value == 0 ? nil : value
            }), in: Double(DarkroomLimits.saturation.lowerBound)...Double(DarkroomLimits.saturation.upperBound),
                step: Double(DarkroomLimits.saturationStep),
                onEditingChanged: { if !$0 { render() } })
                .accessibilityLabel("Saturation")
                .accessibilityValue("\(recipe.saturation ?? 0)")
        case .vignette:
            Text(StopsText.shown(recipe.vignetteStops ?? 0)).monospacedDigit()
            Slider(value: Binding(get: { recipe.vignetteStops ?? 0 }, set: {
                let value = StopsText.tenths($0, in: DarkroomLimits.vignetteStops)
                recipe.vignetteStops = value == 0 ? nil : value
            }), in: DarkroomLimits.vignetteStops, step: DarkroomLimits.vignetteStep,
                onEditingChanged: { if !$0 { render() } })
                .accessibilityLabel("Vignette")
                .accessibilityValue(StopsText.spoken(recipe.vignetteStops ?? 0))
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
        case .adjust:
            // The turn buttons are beside the heading. Straightening comes first, so it stays where it is as the crop's
            // own rows come and go below it.
            if !isInstant {
                let straightening = StopsText.tenths(recipe.straighteningDegrees ?? 0, in: DarkroomLimits.straighteningDegrees)
                captionedSliders {
                    captioned(Text("Straighten \(String(format: "%.1f", straightening))°").font(.caption).monospacedDigit(),
                              Slider(value: Binding(get: { recipe.straighteningDegrees ?? 0 }, set: {
                                  let value = StopsText.tenths($0, in: DarkroomLimits.straighteningDegrees)
                                  recipe.straighteningDegrees = value == 0 ? nil : value
                              }), in: DarkroomLimits.straighteningDegrees, step: DarkroomLimits.straighteningStep,
                                     onEditingChanged: { if !$0 { render() } })
                                  .accessibilityLabel("Straighten")
                                  .accessibilityValue("\(String(format: "%.1f", straightening)) degrees"))
                    captioned(Text("Crop").font(.caption), Toggle("Crop", isOn: Binding(get: { recipe.crop != nil }, set: {
                        recipe.crop = $0 ? Crop(x: 0, y: 0, width: 1, height: 1) : nil; render()
                    })).labelsHidden().frame(maxWidth: .infinity, alignment: .trailing))
                    if let crop = recipe.crop {
                        captioned(Text("Size").font(.caption), Slider(value: Binding(get: { crop.width }, set: {
                            let size = $0
                            recipe.crop = Crop(x: min(crop.x, 1 - size), y: min(crop.y, 1 - size), width: size, height: size)
                        }), in: 0.2...1, onEditingChanged: { if !$0 { render() } }).accessibilityLabel("Crop size"))
                        if crop.width < 1 {
                            cropPosition("Horizontal", x: true)
                            cropPosition("Vertical", x: false)
                        }
                    }
                }
            }
        }
    }

    /// The space between a caption and the control beside it.
    private static let captionSpacing: CGFloat = 12

    /// A tool's captioned controls: the rows of a grid through the extra large text size, so the controls beside their
    /// captions line up; at larger sizes the content as it is, each caption above its control.
    @ViewBuilder private func captionedSliders(@ViewBuilder _ content: () -> some View) -> some View {
        if captionsBeside {
            Grid(alignment: .leading, horizontalSpacing: Self.captionSpacing) { content() }
        } else {
            content()
        }
    }

    /// A caption and its control: one grid row through the extra large text size, the caption above it beyond.
    @ViewBuilder private func captioned(_ caption: some View, _ control: some View) -> some View {
        if captionsBeside {
            GridRow { caption; control }
        } else {
            VStack(alignment: .leading) { caption; control }
        }
    }

    private func filtrationSlider(_ name: String, path: WritableKeyPath<ColorFiltration, Double>) -> some View {
        captioned(Text(name).font(.caption), Slider(value: Binding(get: { (recipe.colorFiltration ?? ColorFiltration())[keyPath: path] }, set: {
            var filtration = recipe.colorFiltration ?? ColorFiltration()
            filtration[keyPath: path] = $0
            recipe.colorFiltration = filtration
        }), in: DarkroomLimits.colorFiltration, step: 1, onEditingChanged: { if !$0 { render() } }).accessibilityLabel(name))
    }

    private func cropPosition(_ name: String, x: Bool) -> some View {
        captioned(Text(name).font(.caption), Slider(value: Binding(get: { x ? recipe.crop!.x : recipe.crop!.y }, set: {
            if x { recipe.crop?.x = $0 } else { recipe.crop?.y = $0 }
        }), in: 0...max(0.001, 1 - (recipe.crop?.width ?? 1)), onEditingChanged: { if !$0 { render() } })
            .accessibilityLabel("Crop \(name)"))
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
