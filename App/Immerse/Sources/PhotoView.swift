import FilmDomain
import ImageIO
import RenderCore
import SwiftUI

/// The height of the Darkroom's controls, which the print preview leaves room for.
private struct ControlsHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// The Darkroom's print and its controls: the print above them in portrait, and beside them in landscape.
///
/// In portrait the print takes the height the controls leave at their full size, and below the navigation bar: the
/// sheet's safe area starts under the bar, and the content scrolls only when even the smallest print does not fit. The
/// scroll area stops above the floating Reset to Original bar, so no control rests under it, where its taps would reach
/// the bar, and the last row scrolls fully clear of it. Rendering shows over the print, outside the measured controls, so
/// it does not resize the print on every render or rescale a Dodge/Burn stroke. An error shows between the print and the
/// controls and is measured with them: the print gives up the error's height, so the selected tool rests on screen
/// under the error and does not wait below the fold. In portrait, a tool whose controls must all show at once, the
/// Crop's three sliders, has the print go below its smallest ordinary size, down to a smaller floor, to rest every
/// control on screen; past that floor the screen scrolls the rest.
///
/// In landscape (a compact vertical size class) the screen is too short for a print over its controls (the captain,
/// 2026-10-14: "landscape - side by side"). The print takes the leading side, as large as it fits there, then come the
/// tool buttons in a column with Reset to Original at its foot, then the selected tool's controls. Read in that order,
/// the screen is the portrait one turned on its side: the print first, then the tools, then the controls that change it.
/// No bottom bar takes the screen's height, and the controls scroll on their own when they cannot all show, as at the
/// largest text sizes, while the print, the tools and Reset stay where they are.
struct DarkroomLayout<Preview: View, Tools: View, Controls: View, Reset: View>: View {
    let rendering: Bool
    let error: String?
    /// Whether the print gives up height below `minimumPrintHeight`, down to `smallestFittedPrintHeight`, to rest every
    /// control on screen in portrait. Where even that print leaves controls below the fold, the print stays at that size
    /// and the screen scrolls only the rest, so a larger text size never has a larger print. In landscape the print is
    /// beside the controls, whose height never reaches it.
    var fitsEveryControl = false
    @ViewBuilder let preview: Preview
    /// One button per tool: a row above the controls in portrait, a column beside them in landscape.
    @ViewBuilder let tools: Tools
    @ViewBuilder let controls: Controls
    /// Reset to Original: the floating bottom bar in portrait, the foot of the tool column in landscape.
    @ViewBuilder let reset: Reset
    /// The height of everything under the print, measured at the current text size.
    @State private var controlsHeight: CGFloat = 260
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    /// The smallest height the print preview is scaled down to before the screen scrolls. Under an error it is half
    /// that: the longest explanation then leaves the Exposure tool on an iPhone SE's screen, with the print still shown.
    private var minimumPrintHeight: CGFloat { error == nil ? 160 : 80 }

    /// The smallest the print is shown in a tool whose controls must all show, two fifths of its ordinary smallest size,
    /// with or without an error. With a crop smaller than the whole print, the Crop tool's controls leave an iPhone SE's
    /// print 80 pt at the default text size, a fraction of a point short of the 80 pt an error allows, so the fitted
    /// print is allowed less.
    private static var smallestFittedPrintHeight: CGFloat { 64 }

    /// The controls' bottom margin, over which controls that run past the scroll area fade out rather than end in a
    /// sliver. The last row, scrolled fully into view, ends above it.
    private static var bottomMargin: CGFloat { 12 }

    /// The space between the scroll area and the floating Reset to Original bar. The bar itself is the bottom safe area,
    /// which takes every tap across the screen's width; kept off it, the scroll view ends above the bar instead of
    /// drawing controls under it.
    private static var bottomBarSpacing: CGFloat { 4 }

    /// The width of a tool button in the landscape column, the least a button takes a tap in.
    private static var toolColumnWidth: CGFloat { 44 }

    /// The space between the print, the tool column and the controls in landscape, and between the controls there:
    /// less than portrait's 18 pt, so the longest tool, Dodge / Burn, rests whole on an iPhone SE at the default text
    /// size.
    private static var sideBySideSpacing: CGFloat { 12 }

    /// The share of the landscape width the controls take from the print. It leaves the Dodge / Burn sliders, beside
    /// their captions, a usable length on an iPhone SE, and the print the rest.
    private static var controlsShare: CGFloat { 0.55 }

    private func printHeight(in available: CGFloat) -> CGFloat {
        max(fitsEveryControl && verticalSizeClass == .regular ? Self.smallestFittedPrintHeight : minimumPrintHeight,
            available - controlsHeight - 18 - 16 - Self.bottomMargin - Self.bottomBarSpacing)
    }

    var body: some View {
        if verticalSizeClass == .compact { sideBySide } else { stacked }
    }

    private var stacked: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 18) {
                    preview.frame(maxWidth: .infinity).frame(height: printHeight(in: geometry.size.height))
                        .overlay(alignment: .topTrailing) { progress }
                    VStack(spacing: 18) {
                        if let error { Text(error).foregroundStyle(.red) }
                        HStack { tools }
                        controls
                    }.background(GeometryReader { Color.clear.preference(key: ControlsHeightKey.self, value: $0.size.height) })
                }.padding([.horizontal, .top]).padding(.bottom, Self.bottomMargin)
            }
            .onPreferenceChange(ControlsHeightKey.self) { controlsHeight = $0 }
            .mask { fade }
            .padding(.bottom, Self.bottomBarSpacing)
        }
        .toolbar { ToolbarItem(placement: .bottomBar) { reset } }
    }

    private var sideBySide: some View {
        GeometryReader { geometry in
            let spacing = Self.sideBySideSpacing
            // The leading and trailing margins and the two gaps around the tool column are 16, 12, 12 and 16 pt.
            let shared = geometry.size.width - 16 - spacing - Self.toolColumnWidth - spacing - 16
            HStack(spacing: spacing) {
                preview.frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(alignment: .topTrailing) { progress }
                    .padding(.leading).padding(.vertical)
                // Five 44 pt tool buttons, Reset's 50 pt and 8 pt margins: 290 pt, inside the 297 pt an iPhone SE has
                // under the navigation bar. A button's icon sits 12 pt inside its frame, so the first icon is level
                // with the heading beside it. Where the column cannot hold them, the tools scroll and Reset stays.
                VStack(spacing: 4) {
                    ScrollView { VStack(spacing: 0) { tools } }.scrollBounceBehavior(.basedOnSize)
                    // The glass circle the bottom bar gave it, large enough to take a tap across more than 44 pt, its symbol
                    // the size the bar draws. Like the bar's, it keeps its size as the text grows, so it never crowds the
                    // tools out of the column.
                    reset.labelStyle(.iconOnly).imageScale(.large).buttonStyle(.glass).buttonBorderShape(.circle)
                        .controlSize(.large).dynamicTypeSize(.large)
                }
                .frame(width: Self.toolColumnWidth).padding(.vertical, 8)
                ScrollView {
                    VStack(spacing: spacing) {
                        if let error { Text(error).foregroundStyle(.red) }
                        controls
                    }.padding([.trailing, .top]).padding(.bottom, Self.bottomMargin)
                }
                .mask { fade }
                .frame(width: (shared * Self.controlsShare).rounded() + 16)
            }
        }
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
    @State private var brushStops = DarkroomLimits.defaultStrokeStops
    @State private var brushPoints: [MaskPoint] = []
    @State private var brushX = 0.5
    @State private var brushY = 0.5
    @State private var rendering = false
    @State private var renderTask: Task<Void, Never>?
    @State private var renderID = UUID()
    @State private var error: String?
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// In landscape, where `DarkroomLayout` puts the controls in a short column beside the print, a caption sits beside
    /// its slider on one row, and a tool's sliders line up after the longest caption, so Dodge / Burn rests whole on an
    /// iPhone SE. Past the extra large text size its caption would leave the slider too short to use, so there, as in
    /// portrait, the caption is above it and the column scrolls.
    private var captionsBeside: Bool { verticalSizeClass == .compact && dynamicTypeSize <= .xLarge }

    private var isInstant: Bool { model.film(filmID)?.camera.id == .instant1970s }

    /// The strengths a Dodge/Burn stroke can be given: from the smallest step to the limit.
    private static let strokeStops = DarkroomLimits.exposureStep...DarkroomLimits.localExposureStops

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
            DarkroomLayout(rendering: rendering, error: error, fitsEveryControl: tool == .crop) {
                printPreview
            } tools: {
                tools
            } controls: {
                Text(tool.rawValue).font(.headline); controls
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
            .task {
                do {
                    process = try model.repository.photoPrintProcess(filmID: filmID)
                    recipe = try model.repository.darkroomRecipe(filmID: filmID, sequence: sequence)
                    render()
                }
                catch { self.error = FailureCopy.message(for: error) }
            }
            .onDisappear { renderTask?.cancel(); image = nil }
            // Turning the iPhone rebuilds the print and the controls in the other layout, which ends a gesture without
            // its end: a stroke being drawn never becomes a stroke of its own nor joins the next one, and the current
            // recipe is rendered again so a slider's edit, which renders only at the end of its drag, still reaches
            // the print.
            .onChange(of: verticalSizeClass) { brushPoints = []; render() }
        }
    }

    /// The print scaled to fit its region, with an Instant card's margin and shadow inside it.
    @ViewBuilder private var printPreview: some View {
        if let image, !model.hiddenFilms.contains(filmID) {
            Image(uiImage: image).resizable().scaledToFit()
                .overlay { brushSurface }
                .accessibilityLabel("Photo \(sequence), print preview")
                .modifier(PrintCardEdge(isInstant: isInstant, large: true))
        } else if error != nil, !rendering {
            // A print that cannot be made, such as one whose saved recipe is outside the limits, has no preview to wait for.
            Image(systemName: "exclamationmark.triangle").font(.largeTitle).foregroundStyle(.secondary)
                .accessibilityLabel("Print unavailable")
        } else { ProgressView() }
    }

    /// One button per tool, across the width in portrait and down a column in landscape. The icons stop growing with the
    /// text size at the largest ordinary size, so five of them always fit inside the side margins, and down the column.
    private var tools: some View {
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
        }.dynamicTypeSize(...DynamicTypeSize.xxxLarge)
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
                captionedSliders {
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
        case .brush:
            Picker("Local exposure", selection: $brushKind) {
                Text("Dodge").tag(LocalMask.Kind.dodge)
                Text("Burn").tag(LocalMask.Kind.burn)
            }.pickerStyle(.segmented)
            Group {
                if captionsBeside {
                    Grid(alignment: .leading, horizontalSpacing: Self.captionSpacing) {
                        GridRow { steady(strengthCaption, widest: Self.strongestCaption); strengthSlider }
                        GridRow { steady(horizontalCaption, widest: "Horizontal: 100%"); horizontalSlider }
                        GridRow { steady(verticalCaption, widest: "Vertical: 100%"); verticalSlider }
                        pointButton
                    }
                } else {
                    VStack(alignment: .leading) {
                        strengthCaption
                        strengthSlider
                        horizontalCaption
                        horizontalSlider
                        verticalCaption
                        verticalSlider
                        pointButton
                    }
                }
            }.disabled(recipe.crop != nil)
            Button("Undo last stroke", systemImage: "arrow.uturn.backward") {
                _ = recipe.dodgeBurnMasks.popLast(); render()
            }.disabled(recipe.dodgeBurnMasks.isEmpty)
        }
    }

    /// The space between a caption and the slider beside it.
    private static let captionSpacing: CGFloat = 12

    /// The Strength caption at the strongest stroke, the widest it reads.
    private static var strongestCaption: String { "Strength: \(StopsText.shown(strokeStops.upperBound))" }

    /// How far each stroke lightens or darkens the print. Strokes add up where they overlap, to the limit.
    private var strengthCaption: Text { Text("Strength: \(StopsText.shown(brushStops))").monospacedDigit() }

    private var strengthSlider: some View {
        Slider(value: Binding(get: { brushStops }, set: { brushStops = StopsText.tenths($0, in: Self.strokeStops) }),
               in: Self.strokeStops, step: DarkroomLimits.exposureStep)
            .accessibilityLabel("Local exposure strength")
            .accessibilityValue(StopsText.spoken(brushStops, signed: false))
    }

    private var horizontalCaption: Text { Text("Horizontal: \(Int(brushX * 100))%").monospacedDigit() }

    private var horizontalSlider: some View {
        Slider(value: $brushX, in: 0...1, step: 0.05)
            .accessibilityLabel("Local exposure horizontal position")
            .accessibilityValue("\(Int(brushX * 100)) percent from left")
    }

    private var verticalCaption: Text { Text("Vertical: \(Int(brushY * 100))%").monospacedDigit() }

    private var verticalSlider: some View {
        Slider(value: $brushY, in: 0...1, step: 0.05)
            .accessibilityLabel("Local exposure vertical position")
            .accessibilityValue("\(Int(brushY * 100)) percent from top")
    }

    private var pointButton: some View {
        Button(brushKind == .dodge ? "Dodge point" : "Burn point", systemImage: "plus.circle") {
            recipe.dodgeBurnMasks.append(LocalMask(kind: brushKind,
                points: [MaskPoint(x: brushX, y: brushY)], exposureStops: brushStops))
            render()
        }
    }

    /// A caption whose value changes as its slider moves, held at the width of its widest value, so the sliders beside
    /// the captions keep their length while one of them is dragged.
    private func steady(_ caption: Text, widest: String) -> some View {
        ZStack(alignment: .leading) {
            Text(widest).monospacedDigit().hidden().accessibilityHidden(true)
            caption
        }
    }

    /// A tool's captioned sliders: in landscape the rows of a grid, so the sliders beside their captions line up; in
    /// portrait the content as it is, each caption above its slider.
    @ViewBuilder private func captionedSliders(@ViewBuilder _ content: () -> some View) -> some View {
        if captionsBeside {
            Grid(alignment: .leading, horizontalSpacing: Self.captionSpacing) { content() }
        } else {
            content()
        }
    }

    /// A caption and its slider: one grid row in landscape, the caption above the slider in portrait.
    @ViewBuilder private func captioned(_ caption: some View, _ slider: some View) -> some View {
        if captionsBeside {
            GridRow { caption; slider }
        } else {
            VStack(alignment: .leading) { caption; slider }
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
                        recipe.dodgeBurnMasks.append(LocalMask(kind: brushKind, points: brushPoints, exposureStops: brushStops))
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
