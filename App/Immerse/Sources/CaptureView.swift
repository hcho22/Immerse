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
    /// How long a line of the header reads when the iPhone is on its side, before it turns. The header takes this much of
    /// the screen's height in every hold, so the viewfinder below it never moves. Wide enough for "12 exposures left"
    /// and a Camera's name in two or three lines.
    @ScaledMetric(relativeTo: .body) private var headerLength: CGFloat = 128
    /// The same for the notes under the viewfinder and for a control's caption.
    @ScaledMetric(relativeTo: .caption) private var noteLength: CGFloat = 160
    @ScaledMetric(relativeTo: .caption) private var captionLength: CGFloat = 72
    let filmID: UUID
    @State private var error: String?
    @State private var cameraDenied = false
    @State private var instantPrint: CaptureRecord?
    @State private var lastRevealedSequence: Int?
    /// The Instant prints revealed while this camera is open that are still to be shown and asked about, in the order
    /// they were taken. The first is the one on screen.
    @State private var revealedPrints: [CaptureRecord] = []
    @State private var originalAsk: OriginalAsk?

    var body: some View {
        @Bindable var capture = model.capture
        let held = HeldTurn(capture.orientation)
        ScrollView {
            VStack(spacing: 20) {
                header(capture)
                if let film = model.film(filmID) {
                    let behavior = CaptureBehavior.for(film.camera.id)
                    viewfinder(film, behavior: behavior, held: held)
                    if film.completionState == .open { controls(behavior: behavior, controller: capture) }
                }
            }.padding()
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
        .task { if let film = model.film(filmID) { open(film) } }
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
            capture.suspend()
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

    /// Done, the Camera's name, what is left and the status above the viewfinder, in view at rest without scrolling.
    /// With the iPhone on its side the whole block turns, as the portrait header it is, taking `headerLength` of the
    /// screen's height in either hold.
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
                    // Status sits above the viewfinder so guidance is visible without scrolling.
                    if film.completionState != .open {
                        Text(film.camera.revealRule == .instantPerExposure ? "Pack complete" : "Film complete").font(.headline)
                    }
                    if let error { Text(error).foregroundStyle(.red).font(.callout).multilineTextAlignment(.center) }
                    if let message = capture.message {
                        Text(message).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    if cameraDenied {
                        Button("Open iPhone Settings", systemImage: "gearshape") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                        }
                    }
                    if capture.phase == .interrupted || error != nil || capture.message?.contains("Retry") == true {
                        Button("Resume Camera", systemImage: "arrow.clockwise") { open(film) }.disabled(capture.busy)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// The viewfinder: a box of the Camera's portrait shape, the same size and place in every hold. The live picture
    /// inside it is the shape the Camera develops to as the iPhone is held, so held on its side it frames a landscape
    /// scene, centred in the box.
    private func viewfinder(_ film: Film, behavior: CaptureBehavior, held: HeldTurn) -> some View {
        let capture = model.capture
        let showsLowLightCue = behavior.showsLowLightCue && capture.showsLowLightCue
        return ZStack {
            Color.black
            if let preview = capture.preview {
                CameraPreview(source: preview, position: capture.position, behavior: behavior, orientation: capture.orientation)
                    .aspectRatio(behavior.viewfinder.aspectRatio(landscape: held.isSideways), contentMode: .fit)
            } else { Image(systemName: "camera").font(.largeTitle).foregroundStyle(.white).turnedWithTheHold() }
        }
        .overlay(alignment: held.topEdge) {
            if showsLowLightCue { TurnedBlock(length: noteLength) { LowLightCueView() }.padding(8) }
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

    /// Focus, exposure and what this lens cannot do. A caption turns beside its slider, which stays across the screen,
    /// and the notes turn as one block.
    @ViewBuilder private func controls(behavior: CaptureBehavior, controller: CaptureController) -> some View {
        @Bindable var capture = controller
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
        let notes = lensNotes(behavior: behavior, controller: controller)
        if !notes.isEmpty {
            TurnedBlock(length: noteLength) {
                VStack(spacing: 4) {
                    ForEach(notes, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center) }
                }.frame(maxWidth: .infinity)
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
        if turn.isSideways {
            HStack(spacing: 12) {
                TurnedBlock(length: captionLength) { caption.multilineTextAlignment(.center) }
                slider
            }
        } else {
            VStack(alignment: .leading) { caption; slider }
        }
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
