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
    /// The screen's ground, under the top bar and the shutter bar alike, which hides a column scrolled beneath the bar.
    private static let ground = Color(uiColor: .secondarySystemBackground)
    /// How long the one-line header reads when the iPhone is on its side. It reserves the same space in every hold, so
    /// the Viewfinder area below it never moves.
    private let headerLineLength: CGFloat = 300
    /// How long the notices over the viewfinder read when the iPhone is on its side, at most.
    @ScaledMetric(relativeTo: .callout) private var noticeLength: CGFloat = 220
    /// How long a slider's caption reads when the iPhone is on its side, which is as tall as the row it sits in.
    @ScaledMetric(relativeTo: .caption) private var captionLength: CGFloat = 64
    let filmID: UUID
    @State private var error: String?
    @State private var cameraDenied = false
    @State private var instantPrint: CaptureRecord?
    @State private var lastRevealedSequence: Int?
    /// The Instant prints revealed while this camera is open that are still to be shown, in capture order. The first is
    /// the one on screen; the Originals question comes once, after the last print of the full pack closes.
    @State private var revealedPrints: [CaptureRecord] = []
    @State private var originalAsk: OriginalAsk?
    /// Whether the "Saved" notice is still showing. It lasts a moment over the picture; every other notice stays until
    /// its cause is gone.
    @State private var savedShowing = false
    /// The height of the controls over the Viewfinder area's bottom, which the notices above them leave free.
    @State private var floatingControlsHeight: CGFloat = 0
    /// How thick the header's line is, which held sideways runs down the Viewfinder area's side, so the notices keep
    /// clear of it.
    @State private var headerThickness: CGFloat = 44
    /// Whether this screen has started its shooting session. A full-screen print or question over it makes it disappear
    /// and appear again, which must not start the session, or open the camera, a second time.
    @State private var started = false
    #if DEBUG
    /// Hosted tests that show a running camera's screen leave the camera closed, so no failure to open it shows.
    var opensCamera = true
    #endif

    var body: some View {
        @Bindable var capture = model.capture
        let held = HeldTurn(capture.held)
        GeometryReader { screen in
            ScrollView {
                // The safe-area reader ends at the shutter bar; the full-width area keeps its own height within it.
                let room = screen.size.height
                CaptureColumn {
                    header(capture, room: room).padding(.horizontal, 16).captureColumnRole(.header)
                        .zIndex(1)
                    if let film = model.film(filmID) {
                        let behavior = CaptureBehavior.for(film.camera.id, focusSetting: film.effectiveFocusSetting)
                        viewfinder(film, behavior: behavior, held: held)
                            .captureColumnRole(.viewfinder(aspect: CGFloat(behavior.viewfinder.aspectRatio)))
                    }
                }
            }
            // The full-width 4:3 area keeps its dimensions; the content scrolls when the screen cannot show all of it.
            .scrollBounceBehavior(.basedOnSize)
        }
        // The shutter stays on screen on small iPhones, at large text sizes and below messages.
        .safeAreaInset(edge: .bottom) { shutterBar(capture) }
        // One ground around the black Viewfinder area, from the top bar to the shutter bar, however much room a taller
        // iPhone leaves between them.
        .background(Self.ground)
        .environment(\.heldTurn, held)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: held)
        .onAppear {
            // Once per presentation: a print or question closing brings this screen back without a second start. After a
            // print the camera starts again only from `showNextPrint`.
            guard !started else { return }
            started = true
            capture.beginShootingSession()
            lastRevealedSequence = model.film(filmID)?.captures.last(where: { $0.revealState == .revealed })?.sequenceNumber
            #if DEBUG
            if !opensCamera { return }
            #endif
            if let film = model.film(filmID) { open(film) }
        }
        .onDisappear {
            // A full-screen Instant print or pack-end Originals question covers this screen without ending its camera
            // session or portrait lock. The covers dismiss back here; leaving the shooting flow ends it, here or, if a
            // print was still to show as the screen left, in the Film screen's dismissal of it.
            guard instantPrint == nil, originalAsk == nil else { return }
            capture.endShootingSession()
        }
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
        // The Instant shows each newly developed print by itself and upright; only the last print in a full pack is
        // followed by the one question covering every revealed print whose original is still undecided (DEV-12).
        .fullScreenCover(item: $instantPrint, onDismiss: showNextPrint) { print in
            PhotoView(filmID: filmID, sequence: print.sequenceNumber, isInstantReveal: true)
        }
        .fullScreenCover(item: $originalAsk, onDismiss: { finishOriginalQuestion(capture) }) { ask in
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

    /// Done, Develop at once when enabled, and the Camera name and count share one line above the Viewfinder area. With
    /// the iPhone on its side the whole line turns and reserves the same length in either hold.
    private func header(_ capture: CaptureController, room: CGFloat) -> some View {
        let sideways = HeldTurn(capture.held).isSideways
        return TurnedBlock(length: headerLineLength + developAtOnceLength, reservesLength: true, maximumLength: room) {
            HStack(spacing: 8) {
                // The action and Debug notice use a compact control size so the Camera name and count keep room at
                // accessibility text sizes. The row can accept the space the header gives it instead of demanding
                // its unbounded text width.
                doneRow(capture).dynamicTypeSize(...DynamicTypeSize.large)
                Spacer(minLength: 0)
                if let film = model.film(filmID) {
                    TimelineView(.periodic(from: .now, by: 0.1)) { context in
                        let elapsed = capture.recordingStarted.map { context.date.timeIntervalSince($0) } ?? 0
                        let status = CaptureHeaderStatus.make(for: film,
                                                              finishingSave: model.hasPendingSave(filmID),
                                                              recordedFor: elapsed)
                        CaptureHeaderLabel(film: film, status: status,
                                           recording: capture.recordingStarted != nil)
                    }
                    .layoutPriority(1)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { headerThickness = $0 }
            // Upright the line sits in the top bar; turned, it runs down the Viewfinder area's side, where a material
            // keeps it legible over the picture without hiding it.
            .padding(.horizontal, sideways ? 8 : 0)
            .background {
                if sideways { RoundedRectangle(cornerRadius: 14).fill(.regularMaterial) }
            }
        }
        // The reserved top bar stays 44 points tall. Turned text and icons continue along the physical top edge while
        // held sideways, over the Viewfinder area as Camera controls do, without changing that area's position.
        .frame(height: 44, alignment: .topLeading)
        .zIndex(1)
    }

    /// The leading part of the one-line header, which in a Debug build includes Develop at once when it is on.
    /// The turned header's extra length for a Debug build's Develop at once notice, which then stays on the line beside
    /// Done instead of dropping under it, so the turned header stays one line thick and clear of the notices.
    private var developAtOnceLength: CGFloat {
        #if DEBUG
        if let film = model.film(filmID), model.developedPreviews.applies(to: film) { return 80 }
        #endif
        return 0
    }

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
        let behavior = CaptureBehavior.for(film.camera.id, focusSetting: film.effectiveFocusSetting)
        let secondary: Color = onDark ? .white.opacity(0.85) : .secondary
        if let error { Text(error).foregroundStyle(.red).font(.callout).multilineTextAlignment(.center) }
        if let message = capture.message, message != "Saved" || savedShowing {
            Text(message).font(.callout).foregroundStyle(secondary).multilineTextAlignment(.center)
        }
        if capture.microphoneUnavailable {
            Text("Microphone access is off. Movie clips will be silent.")
                .font(.callout).foregroundStyle(secondary).multilineTextAlignment(.center)
                .accessibilityIdentifier("microphone-permission-note")
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
        let behavior = CaptureBehavior.for(film.camera.id, focusSetting: film.effectiveFocusSetting)
        return error != nil || cameraDenied || (capture.message.map { $0 != "Saved" || savedShowing } ?? false)
            || capture.microphoneUnavailable
            || capture.offersResume(for: film, showingError: error != nil)
            || (film.completionState == .open && !lensNotes(behavior: behavior, controller: capture).isEmpty)
    }

    /// A full-width 4:3 area with the Camera's portrait picture centered inside it. Only that picture frame receives the
    /// live preview; black bars fill the rest. Notices and camera controls float over the area without changing its size.
    private func viewfinder(_ film: Film, behavior: CaptureBehavior, held: HeldTurn) -> some View {
        let capture = model.capture
        let showsLowLightCue = behavior.showsLowLightCue && capture.showsLowLightCue
        let showsStatus = hasStatus(film, controller: capture)
        return GeometryReader { area in
            CameraShapeArea(aspectRatio: CGFloat(behavior.viewfinder.aspectRatio)) {
                    if let preview = capture.preview {
                        CameraPreview(source: preview, position: capture.position, behavior: behavior) { point in
                            guard film.effectiveFocusSetting == .auto else { return false }
                            do { return try await capture.focus(at: point, for: film) == .allowed }
                            catch { self.error = FailureCopy.message(for: error); return false }
                        }
                    } else if !showsStatus && !showsDevelopedPreview {
                        // Without a picture the Camera icon is inside the Camera's shape, never in its bars.
                        Image(systemName: "camera").font(.largeTitle).foregroundStyle(.white).turnedWithTheHold()
                    }
            }
            .overlay(alignment: .top) {
                // The notices take the area above the controls at its bottom, so a long notice, as at the largest text
                // sizes held sideways, never runs over the focus switch.
                // Held sideways they also keep clear of the header running down the side that is then the top: its
                // thickness, its 16-point margin and 8 more.
                let room = max(area.size.height - (floatingControlsHeight > 0 ? floatingControlsHeight + 8 : 0), 80)
                let headerSide: Edge.Set = held == .clockwise ? .trailing : held == .counterClockwise ? .leading : []
                notices(film, controller: capture, showsLowLightCue: showsLowLightCue, showsStatus: showsStatus,
                        showsPreview: showsDevelopedPreview, boxHeight: room)
                    .padding(headerSide, headerThickness + 24)
                    .frame(width: area.size.width, height: room, alignment: held.isSideways ? .center : held.topEdge)
            }
            // The focus switch and the 6×6's sliders stay across the area's bottom in every hold, as the screen's layout
            // does; only their captions turn. The zoom steps sit over its bottom edge as the iPhone is held, as in the
            // iPhone's Camera app: under the switch upright, and turned with the hold at the side that is then the bottom.
            .overlay(alignment: .bottom) {
                VStack(spacing: 4) {
                    if film.completionState == .open {
                        if !held.isSideways { zoomSteps(behavior: behavior, capture: capture) }
                        if hasCaptureControls(behavior, film: film, capture: capture) {
                            controls(film: film, behavior: behavior, controller: capture)
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
                .environment(\.colorScheme, .dark)
                .tint(.white)
                .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { floatingControlsHeight = $0 }
            }
            .overlay(alignment: .top) {
                // Held sideways, the zoom steps stand at the side that is then the bottom, in the room above the controls
                // at the area's bottom, so they never cover the focus switch.
                if film.completionState == .open && held.isSideways {
                    let room = max(area.size.height - (floatingControlsHeight > 0 ? floatingControlsHeight + 8 : 0), 80)
                    zoomSteps(behavior: behavior, capture: capture)
                        .frame(width: area.size.width, height: room, alignment: held.bottomEdge)
                }
            }
        }
        .aspectRatio(CaptureAreaGeometry.aspectRatio, contentMode: .fit)
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

    /// Whether the Camera shows its focus switch or a focus or exposure row over the area's bottom.
    private func hasCaptureControls(_ behavior: CaptureBehavior, film: Film, capture: CaptureController) -> Bool {
        if film.camera.focusSettings.count > 1 { return true }
        return capture.lensIsLive && (behavior.offersManualFocus || behavior.offersExposureBias)
    }

    /// The low-light cue, the status lines and, in a Debug build, the preview of the latest capture, turned as one block.
    /// It sits at the viewfinder's top when upright and in its middle when held sideways, clear of the rotated header.
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

    /// The 6×6, Super 8 and 16mm zoom steps, the iPhone's own lenses labeled as its Camera app labels them, in a pill
    /// over the viewfinder's bottom edge as that app has them. There is no pill where the Camera has none, on the front
    /// camera and on an iPhone with one rear lens. A step can be taken only between photo exposures or Recorded Clips.
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
    private func controls(film: Film, behavior: CaptureBehavior, controller: CaptureController) -> some View {
        @Bindable var capture = controller
        let bias: ClosedRange<Double>? = {
            guard let minimum = capture.controls.minimumExposureBias, let maximum = capture.controls.maximumExposureBias,
                  minimum < maximum else { return nil }
            return Double(minimum)...Double(maximum)
        }()
        return VStack(spacing: 8) {
            if film.camera.focusSettings.count > 1 {
                FocusModeSwitch(settings: film.camera.focusSettings, selected: film.effectiveFocusSetting) { setting in
                    guard setting != film.effectiveFocusSetting else { return }
                    model.perform({
                        let updated = try model.setFocusSetting(setting, filmID: filmID)
                        try await capture.updateFocusSetting(for: updated)
                    }, failure: { error = $0 })
                }
                .disabled(capture.busy || capture.phase == .savingPhoto || capture.phase == .savingMovieClip)
            }
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
        if behavior.focus == .deviceDefault && !capture.controls.supportsFocusPoint {
            notes.append("Tap to focus unavailable on this lens")
        } else if behavior.focus == .fixed && !capture.controls.fixedFocus {
            notes.append("Fixed focus unavailable on this lens")
        }
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
                    model.perform { try await capture.switchLens(film: film) } failure: { error = $0 }
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
                if CaptureBehavior.for(film.camera.id, focusSetting: film.effectiveFocusSetting).offersFlash && capture.controls.flash {
                    Toggle(isOn: $capture.flash) { Label("Flash", systemImage: capture.flash ? "bolt.fill" : "bolt.slash") }
                        .toggleStyle(.button).labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                        .turnedWithTheHold().disabled(capture.phase != .idle)
                } else if film.camera.medium == .photo {
                    Image(systemName: "bolt.slash").foregroundStyle(.secondary).frame(width: 44).turnedWithTheHold()
                } else {
                    Color.clear.frame(width: 44, height: 44).accessibilityHidden(true)
                }
            }
            .padding(.vertical, 8).frame(maxWidth: .infinity).background(Self.ground)
        }
    }

    private func showNextPrint() {
        revealedPrints = Array(revealedPrints.dropFirst())
        instantPrint = revealedPrints.first
        guard revealedPrints.isEmpty, let film = model.film(filmID) else { return }
        let prints = model.packEndOriginalQuestion(filmID)
        if !prints.isEmpty { originalAsk = OriginalAsk(prints: prints); return }
        // The camera starts again only after its print views close, while the pack is still open and no save needs retry.
        if model.capture.printsClosed(allowingRestart: film.completionState == .open && error == nil && !model.hasPendingSave(filmID)) {
            open(film)
        }
    }

    private func finishOriginalQuestion(_ capture: CaptureController) {
        // Cancelled or missed, the question does not return by itself. Originals on the Film screen remains available.
        _ = capture.printsClosed(allowingRestart: false)
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

/// The leading part of the one-line header: Done and, in a Debug build, the notice that Develop at once is on for this
/// Camera. `CaptureView` places the Camera name and count beside this row.
/// The focus switch, "Auto / Fixed" or "Auto / Manual" (FR-25): one segment per setting across the area's bottom, whose
/// words turn with the hold as the screen's other words do, so held sideways they read upright. VoiceOver reads it as
/// one control, "Focus, Auto", changed with a double tap or the adjustable action.
struct FocusModeSwitch: View {
    let settings: [FilmFocusSetting]
    let selected: FilmFocusSetting
    let select: (FilmFocusSetting) -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack(spacing: 0) {
            ForEach(settings, id: \.self) { setting in
                Button { select(setting) } label: {
                    TurnedBlock { Text(setting.title).font(.subheadline.weight(.semibold)).lineLimit(1) }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background { if setting == selected { Capsule().fill(Color.white.opacity(0.24)).padding(3) } }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(isEnabled ? 1 : 0.45))
            }
        }
        .background(Color.white.opacity(0.1), in: Capsule())
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Focus")
        .accessibilityValue(selected.title)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { step(by: 1) }
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: step(by: 1)
            case .decrement: step(by: -1)
            @unknown default: break
            }
        }
        .accessibilityIdentifier("capture-focus-mode")
    }

    /// The setting `offset` places along the switch, wrapping round, as a double tap moves to the other side.
    private func step(by offset: Int) {
        guard isEnabled, let index = settings.firstIndex(of: selected), !settings.isEmpty else { return }
        select(settings[(index + offset + settings.count) % settings.count])
    }
}

/// The Viewfinder area, black, with a Camera's picture shape centered in it (FR-23 item 2). Only the shape shows its
/// content: the content is clipped to the shape before it is placed, so a preview drawn past its bounds, as an
/// aspect-fill camera preview is, never reaches the bars around it.
struct CameraShapeArea<Content: View>: View {
    let aspectRatio: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        GeometryReader { area in
            let shape = CaptureAreaGeometry.cameraFrame(aspectRatio: aspectRatio, in: area.size)
            ZStack {
                Color.black
                content
            }
            .frame(width: shape.width, height: shape.height)
            .clipped()
            .position(x: shape.midX, y: shape.midY)
        }
        .background(Color.black)
    }
}

struct CaptureDoneRow: View {
    let done: @MainActor () -> Void
    #if DEBUG
    /// Whether Develop at once is on for the Camera (`DevelopedPreviews.applies(to:)`).
    var developsAtOnce = false
    #endif

    var body: some View {
        // The glass adds 7 points above and below its label, so the button is the 44-point top bar's height and stays
        // inside it.
        let button = Button(action: done) { Text("Done").frame(minHeight: 30) }.buttonStyle(.glass)
            .accessibilityShowsLargeContentViewer()
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

/// The Camera's short name and compact count in the one-line shooting header. The visible words stay short at every text
/// size; the full Camera name and count remain available to VoiceOver and the Large Content Viewer.
private struct CaptureHeaderLabel: View {
    let film: Film
    let status: CaptureHeaderStatus
    let recording: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text(SpokenText.shown(film.camera.shortName))
                .font(.system(.title3, design: .serif))
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(status.visible)
                .font(.body.monospaced())
                .foregroundStyle(recording ? .red : .primary)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        // Like the iOS Camera bar, the visible header stays at a standard control size at every text size; the full
        // label remains available to VoiceOver and the Large Content Viewer.
        .dynamicTypeSize(...DynamicTypeSize.large)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(status.spoken)
        .accessibilityShowsLargeContentViewer()
        .accessibilityIdentifier("capture-header-status")
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
    /// Focuses at a point of the capture device's picture and answers whether the lens focused there.
    let onFocusPoint: @MainActor (CGPoint) async -> Bool
    func makeUIView(context: Context) -> PreviewSurface {
        let surface = PreviewSurface()
        surface.source = source
        surface.onFocusPoint = onFocusPoint
        surface.preview = source.makeLayer()
        surface.addGestureRecognizer(UITapGestureRecognizer(target: surface, action: #selector(PreviewSurface.focusTapped(_:))))
        return surface
    }
    func updateUIView(_ uiView: PreviewSurface, context: Context) {
        uiView.onFocusPoint = onFocusPoint
        uiView.preview?.videoGravity = behavior.viewfinder.cropsCapture ? .resizeAspectFill : .resizeAspect
        uiView.mirrored = behavior.isViewfinderMirrored(position: position)
        uiView.setNeedsLayout()
    }
}

/// The picture is upright in the portrait window the shooting screen holds, whichever way the iPhone is held, as in the
/// iPhone's Camera app: the screen and the camera turn together, so the scene reads upright in every hold. Only a saved
/// photo or clip follows the hold.
final class PreviewSurface: UIView {
    var source: CapturePreviewSource?
    var onFocusPoint: (@MainActor (CGPoint) async -> Bool)?
    var mirrored = false
    /// The square that shows where a tap focused, as in the iPhone's Camera app.
    let focusMark = FocusMark()

    override init(frame: CGRect) {
        super.init(frame: frame)
        // A second guard behind `CameraShapeArea`'s clip: the aspect-fill preview layer never draws past the shape.
        clipsToBounds = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }
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

    /// A tap focuses there, and the mark shows only once the lens has: a lens that cannot focus on a point shows none.
    @objc func focusTapped(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended else { return }
        focus(at: recognizer.location(in: self))
    }

    /// Focuses where the view was touched, then shows the mark there if the lens focused.
    @discardableResult func focus(at location: CGPoint) -> Task<Void, Never>? {
        guard let preview, let onFocusPoint else { return nil }
        let point = preview.captureDevicePointConverted(fromLayerPoint: location)
        return Task { [weak self] in
            guard await onFocusPoint(point), let self else { return }
            if focusMark.superview == nil { addSubview(focusMark) }
            focusMark.show(at: location)
        }
    }
}

/// A yellow square at the point a tap focused, which settles and then fades, as in the iPhone's Camera app. It draws on
/// the picture only and takes no touches; VoiceOver users focus with continuous autofocus, which a tap only adds to.
final class FocusMark: UIView {
    private static let side: CGFloat = 72

    init() {
        super.init(frame: CGRect(x: 0, y: 0, width: Self.side, height: Self.side))
        layer.borderColor = UIColor.systemYellow.cgColor
        layer.borderWidth = 1.5
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        alpha = 0
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func show(at location: CGPoint) {
        layer.removeAllAnimations()
        center = location
        alpha = 1
        let moves = !UIAccessibility.isReduceMotionEnabled
        transform = moves ? CGAffineTransform(scaleX: 1.4, y: 1.4) : .identity
        UIView.animate(withDuration: moves ? 0.2 : 0, delay: 0, options: [.beginFromCurrentState]) {
            self.transform = .identity
        } completion: { finished in
            // A newer tap's mark replaces this one and fades on its own.
            guard finished else { return }
            UIView.animate(withDuration: 0.3, delay: 1.2, options: [.beginFromCurrentState, .allowUserInteraction]) {
                self.alpha = 0
            }
        }
    }
}

private extension View {
    /// A button in a notice: white on the dark ground it sits on over the viewfinder, the app's own tint elsewhere.
    @ViewBuilder func noticeButtonStyle(onDark: Bool) -> some View {
        if onDark { buttonStyle(.bordered).tint(.white).foregroundStyle(.white) } else { self }
    }
}
