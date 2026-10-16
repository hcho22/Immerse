import AVFoundation
import FilmDomain
import NativeAdapters
import SwiftUI

/// The shooting screen. It keeps the portrait layout whichever way the iPhone is held, as the iPhone's own Camera app
/// does (the captain, 2026-10-16): the viewfinder stays the same size in the same place, and with the iPhone on its side
/// only the words and icons turn to read upright (`HeldTurn`). The picture inside the viewfinder follows how the iPhone is
/// held, so a photo taken on its side saves on its side, as before.
struct CaptureView: View {
    @Environment(JournalModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// How long a line of the header reads when the iPhone is on its side, before it turns, at least. The header takes
    /// this much of the screen's height in every hold, so the viewfinder below it never moves. Wide enough for
    /// "12 exposures left" and a Camera's name in two or three lines; where the screen has room to spare, the column
    /// gives the header more (`CaptureColumn`).
    @ScaledMetric(relativeTo: .body) private var headerLength: CGFloat = 128
    /// How long the notices over the viewfinder read when the iPhone is on its side, at most.
    @ScaledMetric(relativeTo: .callout) private var noticeLength: CGFloat = 220
    /// How long a slider's caption reads when the iPhone is on its side, which is as tall as the row it sits in.
    @ScaledMetric(relativeTo: .caption) private var captionLength: CGFloat = 64
    /// The room above the column and below it, which the screen's top and the shutter bar keep clear.
    private static let verticalPadding: CGFloat = 12
    let filmID: UUID
    @State private var error: String?
    @State private var cameraDenied = false
    @State private var instantPrint: CaptureRecord?
    @State private var lastRevealedSequence: Int?
    /// The Instant prints revealed while this camera is open that are still to be shown and asked about, in the order
    /// they were taken. The first is the one on screen.
    @State private var revealedPrints: [CaptureRecord] = []
    @State private var originalAsk: OriginalAsk?
    /// Whether the "Saved" notice is still showing. It lasts a moment over the picture; every other notice stays until
    /// its cause is gone.
    @State private var savedShowing = false
    #if DEBUG
    /// Hosted tests that show a running camera's screen leave the camera closed, so no failure to open it shows.
    var opensCamera = true
    #endif

    var body: some View {
        @Bindable var capture = model.capture
        let held = HeldTurn(capture.orientation)
        GeometryReader { screen in
            ScrollView {
                // The reader's size is the screen's safe area less the shutter bar: the room the column has.
                CaptureColumn(available: screen.size.height - 2 * Self.verticalPadding) {
                    header(capture).captureColumnRole(.header)
                    if let film = model.film(filmID) {
                        let behavior = CaptureBehavior.for(film.camera.id)
                        viewfinder(film, behavior: behavior, held: held)
                            .captureColumnRole(.viewfinder(aspect: CGFloat(behavior.viewfinder.aspectRatio(landscape: false))))
                        if film.completionState == .open { controls(behavior: behavior, controller: capture).captureColumnRole(.controls) }
                    }
                }
                .padding(.horizontal).padding(.vertical, Self.verticalPadding)
            }
            // The column is as tall as the screen has room for, so it scrolls only where it cannot be (large text).
            .scrollBounceBehavior(.basedOnSize)
        }
        .environment(\.heldTurn, held)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: held)
        // The shutter stays on screen on small iPhones, at large text sizes and below messages.
        .safeAreaInset(edge: .bottom) { shutterBar(capture) }
        // The screen holds the portrait layout; the print and the question about its original that follow an Instant
        // exposure turn with the iPhone, like every other screen.
        .holdsInterfaceOrientation(.portrait, while: instantPrint == nil && originalAsk == nil) {
            InterfaceOrientationLock.mask(held: capture.orientation)
        }
        .task {
            #if DEBUG
            if !opensCamera { return }
            #endif
            if let film = model.film(filmID) { open(film) }
        }
        .onAppear {
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            capture.updateOrientation()
            capture.presented = true
            lastRevealedSequence = model.film(filmID)?.captures.last(where: { $0.revealState == .revealed })?.sequenceNumber
        }
        .onDisappear { UIDevice.current.endGeneratingDeviceOrientationNotifications(); capture.presented = false; capture.suspend() }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in capture.updateOrientation() }
        .onChange(of: model.film(filmID)?.captures) { _, captures in
            guard model.film(filmID)?.camera.revealRule == .instantPerExposure,
                  let revealed = captures?.filter({ $0.revealState == .revealed && $0.sequenceNumber > lastRevealedSequence ?? 0 }),
                  let newest = revealed.last else { return }
            lastRevealedSequence = newest.sequenceNumber
            capture.pauseForReveal()
            let showsNow = revealedPrints.isEmpty
            revealedPrints += revealed
            if showsNow { instantPrint = revealedPrints.first }
        }
        // Each print is shown first; closing it brings the question about its original, and then the next print (DEC-11).
        .sheet(item: $instantPrint, onDismiss: {
            let prints = model.printsAwaitingOriginalChoice(filmID, among: Set(revealedPrints.prefix(1).map(\.sequenceNumber)))
            if prints.isEmpty { showNextPrint() } else { originalAsk = OriginalAsk(prints: prints) }
        }) { print in PhotoView(filmID: filmID, sequence: print.sequenceNumber) }
        .sheet(item: $originalAsk, onDismiss: showNextPrint) { ask in
            OriginalChoiceView(filmID: filmID, startsDevelopment: false, prints: ask.prints)
        }
    }

    /// Done, the Camera's name and what is left above the viewfinder, in view at rest without scrolling. With the iPhone on
    /// its side the whole block turns, as the portrait header it is, taking at least `headerLength` of the screen's height in
    /// either hold. At the largest text sizes the notices that sit over the viewfinder come here, where they scroll.
    private func header(_ capture: CaptureController) -> some View {
        TurnedBlock(length: headerLength, reservesLength: true) {
            VStack(spacing: 12) {
                HStack {
                    Button { capture.suspend(); dismiss() } label: { Text("Done").frame(minHeight: 44) }.buttonStyle(.glass)
                    Spacer(minLength: 0)
                }
                if let film = model.film(filmID) {
                    film.camera.displayNameText.font(.system(.title3, design: .serif)).multilineTextAlignment(.center)
                    TimelineView(.periodic(from: .now, by: 0.1)) { context in
                        if let start = capture.recordingStarted {
                            film.remainingText(recordedFor: context.date.timeIntervalSince(start))
                                .font(.body.monospaced()).foregroundStyle(.red)
                        } else { (model.hasPendingSave(filmID) ? Text("Finishing save") : film.remainingText).font(.body.monospaced()) }
                    }.multilineTextAlignment(.center)
                    if film.completionState != .open {
                        Text(film.camera.revealRule == .instantPerExposure ? "Pack complete" : "Film complete").font(.headline)
                    }
                    if dynamicTypeSize.isAccessibilitySize, let film = model.film(filmID) {
                        statusLines(film, controller: capture, onDark: false)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// What is wrong or worth knowing: the error, the message, the way to iPhone Settings and to Resume Camera, and what
    /// the active lens cannot do that this Camera asks of it. Over the viewfinder, where they never move it, they sit on
    /// a dark ground; at the largest text sizes they are part of the header, on the screen's own.
    @ViewBuilder private func statusLines(_ film: Film, controller capture: CaptureController, onDark: Bool) -> some View {
        let behavior = CaptureBehavior.for(film.camera.id)
        let secondary: Color = onDark ? .white.opacity(0.85) : .secondary
        if let error { Text(error).foregroundStyle(.red).font(.callout).multilineTextAlignment(.center) }
        if let message = capture.message, message != "Saved" || savedShowing {
            Text(message).font(.callout).foregroundStyle(secondary).multilineTextAlignment(.center)
        }
        if cameraDenied {
            Button("Open iPhone Settings", systemImage: "gearshape") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }.noticeButtonStyle(onDark: onDark)
        }
        if capture.offersResume(for: film, showingError: error != nil) {
            Button("Resume Camera", systemImage: "arrow.clockwise") { open(film) }.disabled(capture.busy)
                .noticeButtonStyle(onDark: onDark)
        }
        if film.completionState == .open {
            ForEach(lensNotes(behavior: behavior, controller: capture), id: \.self) {
                Text($0).font(.caption).foregroundStyle(secondary).multilineTextAlignment(.center)
            }
        }
    }

    /// Whether there is anything for `statusLines` to show.
    private func hasStatus(_ film: Film, controller capture: CaptureController) -> Bool {
        let behavior = CaptureBehavior.for(film.camera.id)
        return error != nil || cameraDenied || (capture.message.map { $0 != "Saved" || savedShowing } ?? false)
            || capture.offersResume(for: film, showingError: error != nil)
            || (film.completionState == .open && !lensNotes(behavior: behavior, controller: capture).isEmpty)
    }

    /// The viewfinder: a box of the Camera's portrait shape, the same size and place in every hold, as large as the room
    /// above the shutter bar leaves (`CaptureColumn`). The live picture inside it is the shape the Camera develops to as the
    /// iPhone is held, so held on its side it frames a landscape scene, centred in the box. The notices sit over it, so a
    /// message coming or going never moves it.
    private func viewfinder(_ film: Film, behavior: CaptureBehavior, held: HeldTurn) -> some View {
        let capture = model.capture
        let showsLowLightCue = behavior.showsLowLightCue && capture.showsLowLightCue
        let showsStatus = !dynamicTypeSize.isAccessibilitySize && hasStatus(film, controller: capture)
        return ZStack {
            Color.black
            if let preview = capture.preview {
                CameraPreview(source: preview, position: capture.position, behavior: behavior, orientation: capture.orientation)
                    .aspectRatio(behavior.viewfinder.aspectRatio(landscape: held.isSideways), contentMode: .fit)
            } else if !showsStatus {
                // Without a picture the frame shows a camera, unless a notice says what is wrong in its place.
                Image(systemName: "camera").font(.largeTitle).foregroundStyle(.white).turnedWithTheHold()
            }
        }
        .overlay {
            GeometryReader { box in
                notices(film, controller: capture, showsLowLightCue: showsLowLightCue, showsStatus: showsStatus,
                        boxHeight: box.size.height)
                    .frame(width: box.size.width, height: box.size.height, alignment: held.topEdge)
            }
        }
        .overlay(alignment: held.bottomEdge) {
            if film.completionState == .open { zoomSteps(behavior: behavior, capture: capture) }
        }
        .aspectRatio(behavior.viewfinder.aspectRatio(landscape: false), contentMode: .fit)
        .clipped()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(viewfinderLabel(position: capture.position))
        .accessibilityIdentifier("viewfinder")
        .onChange(of: showsLowLightCue) { _, showing in
            if showing { AccessibilityNotification.Announcement(LowLightCueView.spokenText).post() }
        }
        .task(id: capture.savedCount) {
            guard capture.savedCount > 0 else { return }
            savedShowing = true
            try? await Task.sleep(for: .seconds(2.5))
            savedShowing = false
        }
    }

    /// The low-light cue and the status lines, against the edge of the viewfinder that is its top as the iPhone is held,
    /// turned as one block. The block is as long as the box lets it be, so it is never cut off.
    @ViewBuilder private func notices(
        _ film: Film, controller capture: CaptureController, showsLowLightCue: Bool, showsStatus: Bool, boxHeight: CGFloat
    ) -> some View {
        if showsLowLightCue || showsStatus {
            TurnedBlock(length: min(noticeLength, max(boxHeight - 16, 80))) {
                VStack(spacing: 6) {
                    if showsLowLightCue { LowLightCueView() }
                    if showsStatus {
                        VStack(spacing: 6) { statusLines(film, controller: capture, onDark: true) }
                            .padding(10).frame(maxWidth: .infinity)
                            .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(8)
        }
    }

    /// The 6×6's zoom steps, the iPhone's own lenses labeled as its Camera app labels them, in a pill over the viewfinder's
    /// bottom edge as that app has them. There is no pill where the Camera has none, on the front camera and on an iPhone
    /// with one rear lens. A step can be taken only between exposures, like a lens switch.
    @ViewBuilder private func zoomSteps(behavior: CaptureBehavior, capture: CaptureController) -> some View {
        let steps = capture.controls.zoomSteps
        if behavior.offersZoomSteps, capture.position == .rear, steps.count > 1 {
            TurnedBlock {
                HStack(spacing: 4) {
                    ForEach(steps) { step in
                        let selected = step == capture.controls.zoomStep
                        Button {
                            model.perform { try await capture.selectZoomStep(step) } failure: { error = $0 }
                        } label: {
                            Text(step.label).font(.footnote.weight(.semibold).monospacedDigit())
                                .foregroundStyle(selected ? Color.black : Color.white)
                                .frame(minWidth: 44, minHeight: 44)
                                .background(selected ? Color.white : Color.clear, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .disabled(capture.phase != .idle || capture.busy)
                        .accessibilityLabel("Zoom \(step.spokenLabel)")
                        .accessibilityAddTraits(selected ? .isSelected : [])
                        .accessibilityIdentifier("zoom-\(step.label)")
                    }
                }
                .padding(4).background(.black.opacity(0.6), in: Capsule())
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            }.padding(10)
        }
    }

    /// Focus and exposure. A caption turns beside its slider, which stays across the screen.
    private func controls(behavior: CaptureBehavior, controller: CaptureController) -> some View {
        @Bindable var capture = controller
        return VStack(spacing: 8) {
            if behavior.offersManualFocus, capture.controls.manualFocus {
                CaptionedSlider(captionLength: captionLength) {
                    Text("Focus").font(.caption)
                } slider: {
                    Slider(value: $capture.focus, in: 0...1, onEditingChanged: { editing in
                        if !editing { model.perform { try await capture.setFocus() } failure: { error = $0 } }
                    }).accessibilityLabel("Focus")
                }
            }
            if behavior.offersExposureBias,
               let minimum = capture.controls.minimumExposureBias, let maximum = capture.controls.maximumExposureBias, minimum < maximum {
                CaptionedSlider(captionLength: captionLength) {
                    Text("Exposure \(capture.exposure, specifier: "%.1f") EV").font(.caption.monospaced())
                } slider: {
                    Slider(value: $capture.exposure, in: Double(minimum)...Double(maximum), onEditingChanged: { editing in
                        if !editing { model.perform { try await capture.setExposure() } failure: { error = $0 } }
                    }).accessibilityLabel("Exposure")
                }
            }
        }
    }

    /// What the active lens cannot do that this Camera asks of it.
    private func lensNotes(behavior: CaptureBehavior, controller capture: CaptureController) -> [String] {
        var notes: [String] = []
        if behavior.offersManualFocus && !capture.controls.manualFocus { notes.append("Manual focus unavailable on this lens") }
        if behavior.offersFlash && !capture.controls.flash { notes.append("Flash unavailable on this lens") }
        if behavior.exposure == .fixed && capture.preview != nil && !capture.controls.fixedExposure {
            notes.append("Fixed exposure unavailable on this lens")
        }
        return notes
    }

    /// Switch Camera, the shutter and flash. The icons turn in place; the shutter is a circle and stays as it is.
    @ViewBuilder private func shutterBar(_ controller: CaptureController) -> some View {
        @Bindable var capture = controller
        if let film = model.film(filmID), film.completionState == .open {
            HStack(spacing: 32) {
                Button("Switch Camera", systemImage: "arrow.triangle.2.circlepath.camera") {
                    model.perform { try await capture.switchLens(camera: film.camera) } failure: { error = $0 }
                }.labelStyle(.iconOnly).font(.title2)
                    .frame(minWidth: 44, minHeight: 44).turnedWithTheHold()
                    .disabled(capture.phase != .idle || capture.busy)
                Button {
                    Task {
                        do { try await capture.shutter(film: film) }
                        catch { self.error = FailureCopy.message(for: error) }
                    }
                } label: {
                    ZStack {
                        Circle().stroke(.primary, lineWidth: 3).frame(width: 74, height: 74)
                        if capture.phase == .recordingMovie { RoundedRectangle(cornerRadius: 4).fill(.red).frame(width: 32, height: 32) }
                        else { Circle().fill(film.camera.medium == .movie ? Color.red : Color.primary).frame(width: 62, height: 62) }
                    }.frame(width: 88, height: 88)
                }
                .disabled(capture.busy || (capture.phase != .idle && capture.phase != .recordingMovie) || model.busyFilms.contains(filmID))
                .accessibilityLabel(capture.phase == .recordingMovie ? "Stop recording" : film.camera.medium == .movie ? "Record clip" : "Take photo")
                .accessibilityIdentifier("capture-shutter")
                if CaptureBehavior.for(film.camera.id).offersFlash && capture.controls.flash {
                    Toggle(isOn: $capture.flash) { Label("Flash", systemImage: capture.flash ? "bolt.fill" : "bolt.slash") }
                        .toggleStyle(.button).labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                        .turnedWithTheHold().disabled(capture.phase != .idle)
                } else {
                    Image(systemName: film.camera.medium == .movie ? "mic.slash" : "bolt.slash").foregroundStyle(.secondary)
                        .frame(width: 44).turnedWithTheHold()
                }
            }
            .padding(.vertical, 8).frame(maxWidth: .infinity).background(.bar)
        }
    }

    private func showNextPrint() {
        revealedPrints = Array(revealedPrints.dropFirst())
        instantPrint = revealedPrints.first
        // The last print and its question are closed: the camera comes back on its own, unless the Film is complete,
        // the screen is gone or something else stopped it.
        if revealedPrints.isEmpty, let film = model.film(filmID),
           model.capture.printsClosed(allowingRestart: film.completionState == .open && error == nil && !model.hasPendingSave(filmID)) {
            open(film)
        }
    }

    private func viewfinderLabel(position: CapturePosition) -> String {
        position == .front ? "Mirrored front viewfinder" : "Rear viewfinder"
    }

    private func open(_ film: Film) {
        Task {
            cameraDenied = false
            do { try await model.capture.open(film: film, model: model); error = nil }
            catch JournalError.cameraDenied {
                self.error = FailureCopy.message(for: JournalError.cameraDenied)
                cameraDenied = true
            }
            catch { self.error = ["Camera unavailable.", FailureCopy.systemDetail(for: error)].compactMap { $0 }.joined(separator: " ") }
        }
    }
}

/// The Disposable's low-light cue: exposure guidance only. It never changes the picture behind it, so the
/// viewfinder does not preview how the exposure will develop. It sits at the viewfinder's top edge, which stays
/// above the shutter bar when a tall viewfinder scrolls. The capsule is its own dark ground, so the
/// white text keeps its contrast over any scene and in both appearances, and the text wraps at large sizes.
private struct LowLightCueView: View {
    static let spokenText = "Low light. Turn the flash on."
    var body: some View {
        Label("Low light - use flash", systemImage: "bolt.fill")
            .font(.callout.weight(.semibold))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Self.spokenText)
    }
}

/// A slider and its caption. The slider stays across the screen in every hold; with the iPhone on its side the caption
/// turns to read upright and moves beside it, since a turned caption above it would need as much height as it is long.
private struct CaptionedSlider<Caption: View, Control: View>: View {
    @Environment(\.heldTurn) private var turn
    let captionLength: CGFloat
    @ViewBuilder let caption: Caption
    @ViewBuilder let slider: Control

    var body: some View {
        Group {
            if turn.isSideways {
                HStack(spacing: 12) {
                    TurnedBlock(length: captionLength) { caption.multilineTextAlignment(.center) }
                    slider
                }
            } else {
                VStack(alignment: .leading) { caption; slider }
            }
        }
        // As tall as the turned caption makes it, in every hold, so the room under the viewfinder never depends on the hold.
        .frame(minHeight: captionLength)
    }
}

private struct CameraPreview: UIViewRepresentable {
    let source: CapturePreviewSource
    let position: CapturePosition
    let behavior: CaptureBehavior
    let orientation: CaptureFrameOrientation
    func makeUIView(context: Context) -> PreviewSurface {
        let surface = PreviewSurface()
        surface.source = source
        surface.preview = source.makeLayer()
        return surface
    }
    func updateUIView(_ uiView: PreviewSurface, context: Context) {
        uiView.preview?.videoGravity = behavior.viewfinder.cropsCapture ? .resizeAspectFill : .resizeAspect
        uiView.mirrored = behavior.isViewfinderMirrored(position: position)
        uiView.orientation = orientation
        uiView.setNeedsLayout()
    }
}

/// The picture follows how the iPhone is held, not the interface, which the shooting screen holds upright: the same
/// orientation a photo is saved in, and the one a clip keeps while it records.
private final class PreviewSurface: UIView {
    var source: CapturePreviewSource?
    var mirrored = false
    var orientation = CaptureFrameOrientation.portrait
    var preview: AVCaptureVideoPreviewLayer? {
        didSet { oldValue?.removeFromSuperlayer(); if let preview { layer.addSublayer(preview) }; setNeedsLayout() }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        preview?.frame = bounds
        rotatePreview()
    }
    private func rotatePreview() {
        guard let preview, let source else { return }
        try? source.update(preview, mirrored: mirrored, orientation: orientation)
    }
}

private extension View {
    /// A button in a notice: white on the dark ground it sits on over the viewfinder, the app's own tint elsewhere.
    @ViewBuilder func noticeButtonStyle(onDark: Bool) -> some View {
        if onDark { buttonStyle(.bordered).tint(.white).foregroundStyle(.white) } else { self }
    }
}
