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
        .environment(\.heldTurn, held)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: held)
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
            InterfaceOrientationLock.hold(.portrait)
            lastRevealedSequence = model.film(filmID)?.captures.last(where: { $0.revealState == .revealed })?.sequenceNumber
        }
        .onDisappear {
            // A full-screen Instant print or pack-end Originals question covers this screen without ending its camera
            // session or portrait lock. The covers dismiss back here; only leaving the shooting flow stops it.
            guard instantPrint == nil, originalAsk == nil else { return }
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
            capture.presented = false
            capture.suspend()
            InterfaceOrientationLock.release(turningTo: InterfaceOrientationLock.mask(held: capture.held))
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
        TurnedBlock(length: headerLineLength, reservesLength: true, maximumLength: room) {
            HStack(spacing: 8) {
                doneRow(capture).fixedSize(horizontal: true, vertical: true)
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
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(.background)
        }
        // The reserved top bar stays 44 points tall. Turned text and icons continue along the physical top edge while
        // held sideways, over the Viewfinder area as Camera controls do, without changing that area's position.
        .frame(height: 44, alignment: .topLeading)
        .zIndex(1)
    }

    /// The leading part of the one-line header, which in a Debug build includes Develop at once when it is on.
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
            let cameraFrame = CaptureAreaGeometry.cameraFrame(
                aspectRatio: CGFloat(behavior.viewfinder.aspectRatio), in: area.size
            )
            ZStack {
                Color.black
                ZStack {
                    Color.black
                    if let preview = capture.preview {
                        CameraPreview(source: preview, position: capture.position, behavior: behavior) { point in
                            guard film.effectiveFocusSetting == .auto else { return }
                            Task {
                                do { _ = try await capture.focus(at: point, for: film) }
                                catch { self.error = FailureCopy.message(for: error) }
                            }
                        }
                    } else if !showsStatus && !showsDevelopedPreview {
                        // Without a picture the Camera icon is inside the Camera's shape, never in its bars.
                        Image(systemName: "camera").font(.largeTitle).foregroundStyle(.white).turnedWithTheHold()
                    }
                }
                .frame(width: cameraFrame.width, height: cameraFrame.height)
                .position(x: cameraFrame.midX, y: cameraFrame.midY)
                .clipped()
            }
            .overlay {
                notices(film, controller: capture, showsLowLightCue: showsLowLightCue, showsStatus: showsStatus,
                        showsPreview: showsDevelopedPreview, boxHeight: area.size.height)
                    .frame(width: area.size.width, height: area.size.height,
                           alignment: held.isSideways ? .center : held.topEdge)
            }
            .overlay(alignment: held.bottomEdge) {
                if film.completionState == .open && hasFloatingControls(behavior, film: film, capture: capture) {
                    VStack(spacing: 4) {
                        controls(film: film, behavior: behavior, controller: capture).padding(.horizontal, 12)
                        zoomSteps(behavior: behavior, capture: capture)
                    }
                    .padding(.bottom, 8)
                    .background(.black.opacity(0.58), in: RoundedRectangle(cornerRadius: 14))
                    .environment(\.colorScheme, .dark)
                    .tint(.white)
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

    private func hasFloatingControls(_ behavior: CaptureBehavior, film: Film, capture: CaptureController) -> Bool {
        if film.camera.focusSettings.count > 1 { return true }
        guard capture.lensIsLive else { return false }
        return behavior.offersManualFocus || behavior.offersExposureBias
            || (behavior.offersZoomSteps && capture.position == .rear && capture.controls.zoomSteps.count > 1)
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
                Picker("Focus", selection: Binding(
                    get: { film.effectiveFocusSetting },
                    set: { setting in
                        guard setting != film.effectiveFocusSetting else { return }
                        model.perform({
                            let updated = try model.setFocusSetting(setting, filmID: filmID)
                            try await capture.updateFocusSetting(for: updated)
                        }, failure: { error = $0 })
                    }
                )) {
                    ForEach(film.camera.focusSettings, id: \.self) { setting in
                        Text(setting.title).tag(setting)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Focus mode")
                .accessibilityValue(film.effectiveFocusSetting.title)
                .accessibilityIdentifier("capture-focus-mode")
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
            .padding(.vertical, 8).frame(maxWidth: .infinity).background(.bar)
        }
    }

    private func showNextPrint() {
        revealedPrints = Array(revealedPrints.dropFirst())
        instantPrint = revealedPrints.first
        guard revealedPrints.isEmpty, let film = model.film(filmID) else { return }
        if film.camera.id == .instant1970s, film.remainingExposures == 0 {
            let prints = model.printsAwaitingOriginalChoice(filmID, among: model.revealedInstantPrints(filmID))
            if !prints.isEmpty { originalAsk = OriginalAsk(prints: prints); return }
        }
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
    let onFocusPoint: (CGPoint) -> Void
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
private final class PreviewSurface: UIView {
    var source: CapturePreviewSource?
    var onFocusPoint: ((CGPoint) -> Void)?
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

    @objc func focusTapped(_ recognizer: UITapGestureRecognizer) {
        guard recognizer.state == .ended, let preview else { return }
        onFocusPoint?(preview.captureDevicePointConverted(fromLayerPoint: recognizer.location(in: self)))
    }
}

private extension View {
    /// A button in a notice: white on the dark ground it sits on over the viewfinder, the app's own tint elsewhere.
    @ViewBuilder func noticeButtonStyle(onDark: Bool) -> some View {
        if onDark { buttonStyle(.bordered).tint(.white).foregroundStyle(.white) } else { self }
    }
}
