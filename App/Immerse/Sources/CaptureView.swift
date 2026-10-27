import AVFoundation
import FilmDomain
import NativeAdapters
import SwiftUI

/// The shooting screen. It keeps the portrait layout whichever way the iPhone is held, as the iPhone's own Camera app
/// does (the captain, 2026-10-16): the viewfinder stays the same size in the same place, and with the iPhone on its side
/// only the words and icons turn to read upright (`HeldTurn`). The live picture fills the viewfinder in every hold, as in
/// that app, and a photo taken on its side still saves on its side, as before.
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
        let held = HeldTurn(capture.held)
        GeometryReader { screen in
            ScrollView {
                // The reader's size is the screen's safe area less the shutter bar: the room the column has.
                let room = screen.size.height - 2 * Self.verticalPadding
                CaptureColumn(available: room) {
                    header(capture, room: room).captureColumnRole(.header)
                    if let film = model.film(filmID) {
                        let behavior = CaptureBehavior.for(film.camera.id)
                        viewfinder(film, behavior: behavior, held: held)
                            .captureColumnRole(.viewfinder(aspect: CGFloat(behavior.viewfinder.aspectRatio)))
                        if film.completionState == .open { controls(behavior: behavior, controller: capture).captureColumnRole(.controls) }
                    }
                }
                .padding(.horizontal).padding(.vertical, Self.verticalPadding)
            }
            // The column is as tall as the screen has room for, so it scrolls only where it cannot be (large text).
            .scrollBounceBehavior(.basedOnSize)
        }
        // The shutter stays on screen on small iPhones, at large text sizes and below messages.
        .safeAreaInset(edge: .bottom) { shutterBar(capture) }
        .environment(\.heldTurn, held)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: held)
        // Held for as long as the screen is up, the print and the question that follow an Instant exposure included, so
        // the camera is never seen turned beneath them as they come and go.
        .holdsInterfaceOrientation(.portrait) { InterfaceOrientationLock.mask(held: capture.held) }
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
        #if DEBUG
        .sheet(item: Binding(get: { model.developedPreviews.inspected }, set: { model.developedPreviews.inspected = $0 })) {
            DevelopedPreviewSheet(preview: $0)
        }
        #endif
    }

    /// How long the notices read when the iPhone is on its side, at most: longer while a Debug build's preview shows.
    private func noticeBlockLength(showsPreview: Bool) -> CGFloat {
        #if DEBUG
        if showsPreview { return max(noticeLength, DevelopedPreviewCard.sidewaysLength) }
        #endif
        return noticeLength
    }

    /// Whether a Debug build shows the card of this Film's previews; never in Release.
    private var showsDevelopedPreview: Bool {
        #if DEBUG
        developedPreview != nil || pendingPreview != nil
        #else
        false
        #endif
    }

    #if DEBUG
    /// The Debug preview of this Film's latest developed capture, while there is one (`DevelopedPreviews`).
    private var developedPreview: DevelopedPreviews.Preview? {
        guard let preview = model.developedPreviews.current, preview.filmID == filmID else { return nil }
        return preview
    }

    /// This Film's newest capture still to develop for a Debug preview.
    private var pendingPreview: DevelopedPreviews.Pending? { model.developedPreviews.pending(for: filmID) }
    #endif

    /// Done, the Camera's name and what is left above the viewfinder, in view at rest without scrolling. With the iPhone on
    /// its side the whole block turns, as the portrait header it is, taking at least `headerLength` of the screen's height in
    /// either hold. At the largest text sizes the notices that sit over the viewfinder come here, where they scroll; held on
    /// its side its lines then run no longer than the `room` the screen shows above the shutter bar, so each starts in view.
    private func header(_ capture: CaptureController, room: CGFloat) -> some View {
        TurnedBlock(length: headerLength, reservesLength: true, maximumLength: room) {
            VStack(spacing: 12) {
                doneRow(capture)
                if let film = model.film(filmID) {
                    film.camera.shortNameText.font(.system(.title3, design: .serif)).multilineTextAlignment(.center)
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

    /// The header's first line, which in a Debug build says whether Develop at once is on for this Film's Camera.
    private func doneRow(_ capture: CaptureController) -> CaptureDoneRow {
        let done: @MainActor () -> Void = { capture.suspend(); dismiss() }
        #if DEBUG
        return CaptureDoneRow(done: done,
                              developsAtOnce: model.film(filmID).map { model.developedPreviews.applies(to: $0) } ?? false)
        #else
        return CaptureDoneRow(done: done)
        #endif
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
    /// above the shutter bar leaves (`CaptureColumn`). The live picture fills it in every hold: held on its side, the box is
    /// the landscape shape the photo saves, as in the iPhone's Camera app. The notices sit over it, so a message coming or
    /// going never moves it.
    private func viewfinder(_ film: Film, behavior: CaptureBehavior, held: HeldTurn) -> some View {
        let capture = model.capture
        let showsLowLightCue = behavior.showsLowLightCue && capture.showsLowLightCue
        let showsStatus = !dynamicTypeSize.isAccessibilitySize && hasStatus(film, controller: capture)
        return ZStack {
            Color.black
            if let preview = capture.preview {
                CameraPreview(source: preview, position: capture.position, behavior: behavior)
            } else if !showsStatus && !showsDevelopedPreview {
                // Without a picture the frame shows a camera, unless a notice says what is wrong in its place.
                Image(systemName: "camera").font(.largeTitle).foregroundStyle(.white).turnedWithTheHold()
            }
        }
        .overlay {
            GeometryReader { box in
                notices(film, controller: capture, showsLowLightCue: showsLowLightCue, showsStatus: showsStatus,
                        showsPreview: showsDevelopedPreview, boxHeight: box.size.height)
                    .frame(width: box.size.width, height: box.size.height, alignment: held.topEdge)
            }
        }
        .overlay(alignment: held.bottomEdge) {
            if film.completionState == .open { zoomSteps(behavior: behavior, capture: capture) }
        }
        .aspectRatio(behavior.viewfinder.aspectRatio, contentMode: .fit)
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

    /// The low-light cue, the status lines and, in a Debug build, the preview of the latest capture, against the edge of
    /// the viewfinder that is its top as the iPhone is held, turned as one block. The block is as long as the box lets it
    /// be, so it is never cut off.
    @ViewBuilder private func notices(
        _ film: Film, controller capture: CaptureController, showsLowLightCue: Bool, showsStatus: Bool, showsPreview: Bool,
        boxHeight: CGFloat
    ) -> some View {
        if showsLowLightCue || showsStatus || showsPreview {
            TurnedBlock(length: min(noticeBlockLength(showsPreview: showsPreview), max(boxHeight - 16, 80))) {
                VStack(spacing: 6) {
                    if showsLowLightCue { LowLightCueView() }
                    if showsStatus {
                        VStack(spacing: 6) { statusLines(film, controller: capture, onDark: true) }
                            .padding(10).frame(maxWidth: .infinity)
                            .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 12))
                    }
                    #if DEBUG
                    if showsPreview {
                        DevelopedPreviewCard(preview: developedPreview, pending: pendingPreview,
                                             open: { model.developedPreviews.inspected = developedPreview },
                                             close: { model.developedPreviews.dismiss() })
                    }
                    #endif
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

    /// Focus and exposure, in rows the Camera always has (`CaptureBehavior`), whatever the active lens reports, so the
    /// viewfinder never moves when the camera opens, switches or takes a zoom step: where the lens cannot do one, its row
    /// says so in the slider's place. A caption turns beside its slider, which stays across the screen.
    private func controls(behavior: CaptureBehavior, controller: CaptureController) -> some View {
        @Bindable var capture = controller
        let bias: ClosedRange<Double>? = {
            guard let minimum = capture.controls.minimumExposureBias, let maximum = capture.controls.maximumExposureBias,
                  minimum < maximum else { return nil }
            return Double(minimum)...Double(maximum)
        }()
        return VStack(spacing: 8) {
            if behavior.offersManualFocus {
                CaptionedSlider(
                    captionLength: captionLength, caption: Text("Focus").font(.caption),
                    unavailable: "Manual focus unavailable on this lens", lensIsLive: capture.lensIsLive,
                    slider: capture.controls.manualFocus
                        ? Slider(value: $capture.focus, in: 0...1, onEditingChanged: { editing in
                            if !editing { model.perform { try await capture.setFocus() } failure: { error = $0 } }
                        }).accessibilityLabel("Focus")
                        : nil
                )
            }
            if behavior.offersExposureBias {
                CaptionedSlider(
                    captionLength: captionLength,
                    caption: (bias == nil ? Text("Exposure") : Text("Exposure \(capture.exposure, specifier: "%.1f") EV"))
                        .font(.caption.monospaced()),
                    unavailable: "Exposure unavailable on this lens", lensIsLive: capture.lensIsLive,
                    slider: bias.map { range in
                        Slider(value: $capture.exposure, in: range, onEditingChanged: { editing in
                            if !editing { model.perform { try await capture.setExposure() } failure: { error = $0 } }
                        }).accessibilityLabel("Exposure")
                    }
                )
            }
        }
    }

    /// What the running lens cannot do that this Camera asks of it, apart from the controls whose rows say so. Nothing is
    /// said while no lens is running, since then there is none to say it of.
    private func lensNotes(behavior: CaptureBehavior, controller capture: CaptureController) -> [String] {
        guard capture.lensIsLive else { return [] }
        var notes: [String] = []
        if behavior.offersFlash && !capture.controls.flash { notes.append("Flash unavailable on this lens") }
        if behavior.exposure == .fixed && !capture.controls.fixedExposure { notes.append("Fixed exposure unavailable on this lens") }
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

/// The header's first line: Done, against the leading edge, and in a Debug build the notice that Develop at once is on
/// for the Camera, which sits there with it, never over the viewfinder (`DoneRowLayout`).
struct CaptureDoneRow: View {
    let done: @MainActor () -> Void
    #if DEBUG
    /// Whether Develop at once is on for the Camera (`DevelopedPreviews.applies(to:)`).
    var developsAtOnce = false
    #endif

    var body: some View {
        let button = Button(action: done) { Text("Done").frame(minHeight: 44) }.buttonStyle(.glass)
        #if DEBUG
        DoneRowLayout {
            button
            if developsAtOnce { DevelopAtOnceNotice() }
        }
        #else
        HStack {
            button
            Spacer(minLength: 0)
        }
        #endif
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
/// One layout holds both in every hold, so the slider is the same view as the iPhone turns and a drag is not cut off.
/// Where the running lens cannot do the control, `slider` is nil and the row says `unavailable` in its place; the
/// slider's place and the note are laid out either way, one of them hidden, so the row is as tall whichever shows. While
/// no lens is running the row is kept, empty.
struct CaptionedSlider<Control: View>: View {
    @Environment(\.heldTurn) private var turn
    let captionLength: CGFloat
    let caption: Text
    let unavailable: String
    let lensIsLive: Bool
    let slider: Control?

    var body: some View {
        let layout = turn.isSideways ? AnyLayout(HStackLayout(spacing: 12)) : AnyLayout(VStackLayout(alignment: .leading))
        layout {
            TurnedBlock(length: captionLength) { lines(caption) }
            ZStack {
                if let slider { slider } else { Slider(value: .constant(0)).hidden().accessibilityHidden(true) }
                TurnedBlock(length: captionLength) { lines(Text(unavailable).font(.caption).foregroundStyle(.secondary)) }
                .opacity(slider == nil ? 1 : 0).accessibilityHidden(slider != nil)
            }
        }
        .opacity(lensIsLive ? 1 : 0).accessibilityHidden(!lensIsLive).allowsHitTesting(lensIsLive)
        // As tall as the turned caption makes it, in every hold, so the room under the viewfinder never depends on the hold.
        .frame(minHeight: captionLength)
    }

    /// Text across the width it is given, against the leading edge upright and centred turned, as the header's is.
    private func lines(_ text: Text) -> some View {
        text.multilineTextAlignment(turn.isSideways ? .center : .leading).minimumScaleFactor(0.9)
            .frame(maxWidth: .infinity, alignment: turn.isSideways ? .center : .leading)
    }
}

private struct CameraPreview: UIViewRepresentable {
    let source: CapturePreviewSource
    let position: CapturePosition
    let behavior: CaptureBehavior
    func makeUIView(context: Context) -> PreviewSurface {
        let surface = PreviewSurface()
        surface.source = source
        surface.preview = source.makeLayer()
        return surface
    }
    func updateUIView(_ uiView: PreviewSurface, context: Context) {
        uiView.preview?.videoGravity = behavior.viewfinder.cropsCapture ? .resizeAspectFill : .resizeAspect
        uiView.mirrored = behavior.isViewfinderMirrored(position: position)
        uiView.setNeedsLayout()
    }
}

/// The picture is upright in the portrait window the shooting screen holds, whichever way the iPhone is held, as in the
/// iPhone's Camera app: the screen and the camera turn together, so the scene reads upright in every hold. Only a saved
/// photo or clip follows the hold.
private final class PreviewSurface: UIView {
    var source: CapturePreviewSource?
    var mirrored = false
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
        try? source.update(preview, mirrored: mirrored, orientation: .portrait)
    }
}

private extension View {
    /// A button in a notice: white on the dark ground it sits on over the viewfinder, the app's own tint elsewhere.
    @ViewBuilder func noticeButtonStyle(onDark: Bool) -> some View {
        if onDark { buttonStyle(.bordered).tint(.white).foregroundStyle(.white) } else { self }
    }
}
