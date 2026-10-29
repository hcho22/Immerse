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

    /// The band's height: what the tallest tool needs at the default text size, Filtration with its three sliders beside
    /// their captions under its heading (249 points with the 16 pt top margin, the 44 pt tool row, the gaps between them
    /// and the bottom margin), held whole on an iPhone SE by `PopulatedWorkflowTests`. Adjust, with the straighten dial
    /// and the crop box's shapes, needs 243. It was 330 while Adjust had five rows of crop and straightening sliders.
    private static var controlBandHeight: CGFloat { 250 }
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

/// Sets an Instant print's white card apart from a white screen with a hairline edge, in the thumbnails. The large views
/// draw the same edge with a margin and a soft shadow in `PrintZoom`.
private struct PrintCardEdge: ViewModifier {
    let isInstant: Bool

    func body(content: Content) -> some View {
        if isInstant {
            content.overlay(Rectangle().strokeBorder(Color.primary.opacity(0.22), lineWidth: 0.5))
        } else {
            content
        }
    }
}

/// A developed print as the Film screen's grid and the Journal show it: a thumbnail on the grid's gray.
struct RevealedPhoto: View {
    @Environment(JournalModel.self) private var model
    let filmID: UUID
    let sequence: Int
    /// Whether the decoded picture stays while the view is out of sight: only the Film screen's grid, which the photo
    /// view covers and which then reloads it in place. Every other print lets its picture go as it leaves the screen.
    var keepsPictureOutOfSight = false
    @State private var image: UIImage?
    @State private var failed = false

    /// The longest side the print is decoded to, in pixels.
    private static let maximumPixels = 600

    /// What the shown picture depends on: a new print or an edit saved to it reloads it.
    private struct Load: Hashable {
        let revision: UUID
        let sequence: Int
    }

    var body: some View {
        ZStack {
            Rectangle().fill(Color(uiColor: .secondarySystemBackground))
            if !model.hiddenFilms.contains(filmID), !failed, let image {
                Image(uiImage: image).resizable().scaledToFit()
                    .modifier(PrintCardEdge(isInstant: model.film(filmID)?.camera.id == .instant1970s))
            } else if failed { Image(systemName: "exclamationmark.triangle") }
            else { ProgressView() }
        }
        .task(id: Load(revision: model.mediaRevision, sequence: sequence)) {
            failed = false
            guard !model.hiddenFilms.contains(filmID) else { image = nil; return }
            do {
                let data = try await model.processor.photo(filmID: filmID, sequence: sequence)
                guard !Task.isCancelled, !model.hiddenFilms.contains(filmID) else { return }
                let pixels = Self.maximumPixels
                let decoded = await Task.detached(priority: .userInitiated) {
                    DisplayPhoto.image(data, maximumPixels: pixels)
                }.value
                guard !Task.isCancelled else { return }
                image = decoded
                failed = decoded == nil
            } catch { failed = true }
        }
        .onDisappear { if !keepsPictureOutOfSight { image = nil } }
        .accessibilityLabel("Developed photo \(sequence)")
    }
}

/// The photo view's print, on black, with Print Zoom. It is decoded to the screen's size and, once zoomed in past that,
/// to the print's own (`ZoomedPicture`). Another print, or an edit saved to this one, shows whole.
private struct ZoomablePrint: View {
    @Environment(JournalModel.self) private var model
    let filmID: UUID
    let sequence: Int
    let swipe: ((Int) -> Void)?
    @Binding var reading: PrintZoomReading
    @State private var picture = ZoomedPicture()
    @State private var failed = false

    private struct Load: Hashable {
        let revision: UUID
        let sequence: Int
    }

    var body: some View {
        let load = Load(revision: model.mediaRevision, sequence: sequence)
        ZStack {
            Color.black
            if !model.hiddenFilms.contains(filmID), !failed, let image = picture.shown {
                PrintZoom(image: image, printSize: picture.printSize,
                          cardEdge: model.film(filmID)?.camera.id == .instant1970s, whole: load, swipe: swipe, zoomed: {
                    reading = $0
                    picture.follow($0)
                })
            } else if failed { Image(systemName: "exclamationmark.triangle") }
            else { ProgressView() }
        }
        .task(id: load) {
            // The picture shown stays until the next one is decoded, so a swipe to another print does not flash a spinner.
            failed = false
            guard !model.hiddenFilms.contains(filmID) else { picture.clear(); return }
            do {
                let data = try await model.processor.photo(filmID: filmID, sequence: sequence)
                guard !Task.isCancelled, !model.hiddenFilms.contains(filmID) else { return }
                let pixels = DisplayPhoto.fullScreenPixels
                // A screen-sized decode is too slow for the main actor, which it would hold up on every swipe.
                let decoded = await Task.detached(priority: .userInitiated) {
                    (DisplayPhoto.image(data, maximumPixels: pixels), DisplayPhoto.pixelSize(data))
                }.value
                guard !Task.isCancelled else { return }
                guard let image = decoded.0, let size = decoded.1 else { failed = true; return }
                picture.show(data, image: image, printSize: size, reading: PrintZoomReading())
            } catch { failed = true }
        }
        .onDisappear { picture.clear() }
    }
}

enum DisplayPhoto {
    /// The longest side of this iPhone's screen in pixels, which a full-screen print is decoded to, so it is sharp
    /// whichever way the iPhone is held.
    @MainActor static var fullScreenPixels: Int {
        let screen = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.screen }.first
        guard let screen else { return 2_048 }
        return Int((max(screen.bounds.width, screen.bounds.height) * screen.scale).rounded(.up))
    }

    nonisolated static func image(_ data: Data, maximumPixels: Int = 1600) -> UIImage? {
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
    @State private var zoom = PrintZoomReading()

    init(filmID: UUID, sequence: Int, isInstantReveal: Bool = false) {
        self.filmID = filmID
        self.sequence = sequence
        self.isInstantReveal = isInstantReveal
        _shownSequence = State(initialValue: sequence)
    }

    /// Where the view is among the Film's developed prints. The Instant's reveal at the camera shows its one new print
    /// and moves nowhere, but counts it among the pack's prints as the Film screen does.
    private var navigation: PhotoNavigation {
        PhotoNavigation(developed: PhotoNavigation.developed(in: model.film(filmID)), shown: shownSequence)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if model.hiddenFilms.contains(filmID) { ProgressView("Removing photo") }
                else {
                    // Print Zoom (FR-22 with the 2026-10-29 amendment): swiping to the previous or next print only at the
                    // whole print, as in the Photos app, and never at the camera's reveal.
                    ZoomablePrint(filmID: filmID, sequence: shownSequence, swipe: isInstantReveal ? nil : { move(by: $0) },
                                  reading: $zoom)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(navigation.label)
                        .accessibilityValue(zoom.isZoomed ? "Zoomed in" : "")
                        .accessibilityAddTraits(.isImage)
                        .accessibilityIdentifier("photo-view-image")
                        .accessibilityActions {
                            // Only the moves there are: none at the ends, and none at the camera's reveal.
                            if !isInstantReveal, navigation.previous != nil {
                                Button("Previous photo") { move(by: -1) }
                            }
                            if !isInstantReveal, navigation.next != nil {
                                Button("Next photo") { move(by: 1) }
                            }
                        }
                }
                if let error { Text(error).foregroundStyle(.red).padding() }
            }
            .background(Color.black.ignoresSafeArea())
            // The photo view is black as the Photos app is, in light and dark: its progress and errors draw for that.
            .environment(\.colorScheme, .dark)
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
                        let remaining = PhotoNavigation.developed(in: model.film(filmID))
                        if !isInstantReveal,
                           let nearest = PhotoNavigation.afterDiscarding(discardedSequence, remaining: remaining) {
                            shownSequence = nearest
                        } else { dismiss() }
                    } failure: { error = $0 }
                }.accessibilityIdentifier("confirm-discard-photo")
            } message: { Text(PrivacyCopy.discard) }
        }
    }

    private func move(by offset: Int) {
        guard !isInstantReveal, let target = offset < 0 ? navigation.previous : navigation.next else { return }
        error = nil
        shownSequence = target
        // VoiceOver reads the print it moved to, as it would after a swipe.
        AccessibilityNotification.LayoutChanged().post()
    }
}

/// A Film's developed prints as the photo view moves through them (FR-22): capture order, sealed and discarded frames
/// left out.
struct PhotoNavigation: Equatable {
    /// The developed prints' sequence numbers, in capture order.
    let developed: [Int]
    let shown: Int

    static func developed(in film: Film?) -> [Int] {
        film?.captures.filter { $0.revealState == .revealed && !$0.isDiscarded }.map(\.sequenceNumber).sorted() ?? []
    }

    private var index: Int? { developed.firstIndex(of: shown) }

    /// What VoiceOver reads: the print's frame number, then its place among the developed prints, "Photo 12, 11 of 11".
    var label: String { "Photo \(shown), \((index ?? 0) + 1) of \(developed.count)" }

    var previous: Int? { index.flatMap { $0 > 0 ? developed[$0 - 1] : nil } }
    var next: Int? { index.flatMap { $0 + 1 < developed.count ? developed[$0 + 1] : nil } }

    /// The print to show once `discarded` is gone, as the Photos app does: the next later print, else the nearest earlier
    /// one, else none, and the view closes.
    static func afterDiscarding(_ discarded: Int, remaining: [Int]) -> Int? {
        remaining.first { $0 > discarded } ?? remaining.last { $0 < discarded }
    }
}

struct DarkroomView: View {
    @Environment(JournalModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let filmID: UUID
    let sequence: Int
    @State private var recipe = DarkroomRecipe.original
    @State private var process = PhotoPrintProcess.color
    /// The print as the recipe makes it, with Print Zoom's sharper picture once zoomed in.
    @State private var picture = ZoomedPicture()
    @State private var zoom = PrintZoomReading()
    @State private var tool = PrintTool.exposure
    @State private var rendering = false
    @State private var renderTask: Task<Void, Never>?
    @State private var renderID = UUID()
    @State private var error: String?
    /// The print the crop box sits over, made once for the recipe's other edits.
    @State private var uncropped: UncroppedPrint?
    /// The crop box's shape. It is the Darkroom's choice while it is open, read back from the crop when the print is.
    @State private var shape = CropShape.freeform
    @State private var upright = false
    @State private var shapeRead = false
    /// Whether the straighten dial is moving, which shows the crop box's grid.
    @State private var dialing = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var camera: CameraID? { model.film(filmID)?.camera.id }
    private var isInstant: Bool { camera == .instant1970s }
    /// The 6×6 crops square only (DEC-11, the captain, 2026-10-29, "8A").
    private var isSquareOnly: Bool { camera == .mediumFormat6x6 }

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
                Button("Reset to Original", systemImage: "arrow.counterclockwise") {
                    recipe.resetToOriginal()
                    shapeRead = false
                    readShape()
                    render()
                }
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
            .task(id: tool == .adjust && !isInstant ? UncroppedPrint.recipe(for: recipe) : nil) { await makeUncropped() }
            .onDisappear { renderTask?.cancel(); picture.clear(); uncropped = nil }
        }
    }

    /// The print in its one region: in Adjust the crop box over the print (an Instant only turns, so it shows its print),
    /// and on every other tool the print with Print Zoom, which looks closer without changing it and shows the whole
    /// print again on another tool (the captain, 2026-10-29, "3A").
    @ViewBuilder private var printPreview: some View {
        if model.hiddenFilms.contains(filmID) {
            ProgressView()
        } else if tool == .adjust, !isInstant, let uncropped, uncropped.matches(recipe) {
            CropEditor(print: uncropped, quarterTurns: recipe.rotationQuarterTurns ?? 0, crop: recipe.crop,
                       degrees: recipe.straighteningDegrees ?? 0, ratio: cropRatio, square: isSquareOnly,
                       dialing: dialing) { crop in
                recipe.crop = crop
                render()
            }
        } else if let image = picture.shown {
            // An Instant print only turns in Adjust, so it shows there unzoomed, in the same place.
            PrintZoom(image: image, printSize: picture.printSize, cardEdge: isInstant, whole: tool, zooms: tool != .adjust,
                      zoomed: {
                zoom = $0
                picture.follow($0)
            })
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Photo \(sequence), print preview")
            .accessibilityValue(zoom.isZoomed ? "Zoomed in" : "")
            .accessibilityAddTraits(.isImage)
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
                Button { turn(left: true) } label: { turnLabel("Rotate left", systemImage: "rotate.left") }
                    .accessibilityIdentifier("darkroom-rotate-left")
                Button { turn(left: false) } label: { turnLabel("Rotate right", systemImage: "rotate.right") }
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
            // The turn buttons are beside the heading. The straighten dial comes first, nearest the print as in the Photos
            // app; the shapes follow, except on the 6×6, whose crop stays square.
            if !isInstant {
                StraightenDial(degrees: Binding(get: { recipe.straighteningDegrees ?? 0 }, set: {
                    recipe.straighteningDegrees = $0 == 0 ? nil : $0
                })) { editing in
                    dialing = editing
                    if !editing { render() }
                }
                if !isSquareOnly { shapes }
            }
        }
    }

    /// The crop box's shapes, and whether a shape with a ratio stands sideways or upright.
    private var shapes: some View {
        HStack(spacing: 4) {
            ScrollView(.horizontal) {
                HStack(spacing: 5) {
                    ForEach(CropShape.allCases, id: \.self) { choice in
                        Button { choose(choice) } label: {
                            Text(choice.rawValue).font(.footnote).lineLimit(1)
                                .padding(.horizontal, 8).frame(minHeight: 32)
                                .background(shape == choice ? Color.accentColor.opacity(0.18) : Color(uiColor: .tertiarySystemFill),
                                            in: Capsule())
                                .frame(minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(shape == choice ? Color.accentColor : Color.primary)
                        .accessibilityLabel(Self.spoken(choice))
                        .accessibilityAddTraits(shape == choice ? .isSelected : [])
                        .accessibilityIdentifier("darkroom-crop-shape-\(choice.rawValue)")
                    }
                }
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
            Button {
                upright.toggle()
                reshape()
            } label: {
                Label("Crop orientation", systemImage: upright ? "rectangle.portrait" : "rectangle")
                    .labelStyle(.iconOnly).frame(width: 30, height: 30)
            }
            .buttonStyle(.bordered).buttonBorderShape(.circle)
            .disabled(!shape.turns)
            .accessibilityValue(upright ? "Upright" : "Sideways")
            .accessibilityIdentifier("darkroom-crop-orientation")
        }
    }

    /// "4 by 3" for "4:3", as VoiceOver should read a shape.
    private static func spoken(_ shape: CropShape) -> String {
        shape.rawValue.replacingOccurrences(of: ":", with: " by ")
    }

    /// Width over height for the crop box, in the turned print's pixels; nil for Freeform.
    private var cropRatio: Double? {
        guard let size = turnedPrintSize else { return nil }
        return isSquareOnly ? 1 : shape.ratio(printSize: size, upright: upright)
    }

    /// The print's size as it is turned, once the print the crop box sits over is made.
    private var turnedPrintSize: CGSize? {
        guard let size = uncropped?.pixelSize else { return nil }
        return (recipe.rotationQuarterTurns ?? 0) % 2 == 0 ? size : CGSize(width: size.height, height: size.width)
    }

    private func choose(_ choice: CropShape) {
        shape = choice
        reshape()
    }

    /// Gives the crop the chosen shape, about as big as it was and where it was (`CropGeometry.reshaped`).
    private func reshape() {
        guard let size = turnedPrintSize, let ratio = cropRatio else { return }
        let rect = CropGeometry.reshaped(CropGeometry.rect(recipe.crop, printSize: size), ratio: ratio, printSize: size)
        recipe.crop = CropGeometry.crop(rect, printSize: size, square: isSquareOnly)
        render()
    }

    /// Turns the print a quarter, its crop with it; a shape with a ratio turns too, so it still fits the crop.
    private func turn(left: Bool) {
        if left { recipe.rotateLeft() } else { recipe.rotateRight() }
        upright.toggle()
        render()
    }

    /// Reads the shape back from the saved crop, once the print's size is known.
    private func readShape() {
        guard !shapeRead, let size = turnedPrintSize else { return }
        (shape, upright) = CropGeometry.shape(of: recipe.crop, printSize: size)
        shapeRead = true
    }

    /// Makes the print the crop box sits over, for the recipe's other edits as they are.
    private func makeUncropped() async {
        guard tool == .adjust, !isInstant, uncropped?.matches(recipe) != true else { readShape(); return }
        let flat = UncroppedPrint.recipe(for: recipe)
        do {
            let data = try await model.processor.photo(filmID: filmID, sequence: sequence, recipe: flat)
            let pixels = DisplayPhoto.fullScreenPixels
            let decoded = await Task.detached(priority: .userInitiated) {
                (DisplayPhoto.image(data, maximumPixels: pixels), DisplayPhoto.pixelSize(data))
            }.value
            guard !Task.isCancelled, let image = decoded.0, let size = decoded.1 else { return }
            uncropped = UncroppedPrint(recipe: flat, image: image, pixelSize: size)
            readShape()
        } catch { if !Task.isCancelled { self.error = FailureCopy.message(for: error) } }
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
                if let image = DisplayPhoto.image(data), let size = DisplayPhoto.pixelSize(data) {
                    picture.show(data, image: image, printSize: size, reading: zoom)
                }
                error = nil
            } catch { if !Task.isCancelled { self.error = FailureCopy.message(for: error) } }
            if renderID == id { rendering = false }
        }
    }
}
