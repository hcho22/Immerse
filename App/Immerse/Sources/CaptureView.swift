import AVFoundation
import FilmDomain
import NativeAdapters
import SwiftUI

/// The shooting screen. It keeps the portrait layout whichever way the iPhone is held, as the iPhone's own Camera app
/// does (the captain, 2026-10-16): the viewfinder stays the same size in the same place, and with the iPhone on its side
/// only the words and icons turn to read upright (`HeldTurn`). The live picture fills the viewfinder in every hold, as in
/// that app, and a photo taken on its side still saves on its side, as before. The Camera's controls share one strip
/// under the viewfinder (the captain, 2026-10-29, "4A"), and the top bar stays above it in every hold ("5A").
struct CaptureView: View {
    @Environment(JournalModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The screen's ground, under the top bar and the shutter bar alike, which hides a column scrolled beneath the bar.
    private static let ground = Color(uiColor: .secondarySystemBackground)
    /// How long the notices over the viewfinder read when the iPhone is on its side, at most.
    @ScaledMetric(relativeTo: .callout) private var noticeLength: CGFloat = 220
    /// The person's text size, from which the notices step down only where they do not fit their room (`notices`).
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
    /// The Viewfinder area's and the control strip's frames, from which the notices over the area learn how much of its
    /// bottom the strip covers, where the screen has no room for the strip under it.
    @State private var viewfinderFrame = CGRect.zero
    @State private var stripFrame: CGRect?
    /// The 6×6's slider open in the strip in place of the Zoom Steps, if any.
    @State private var openSlider: StripSlider?
    /// The screen's own bottom inset, the home indicator's, which the iPhone SE does not have.
    @State private var bottomInset: CGFloat = 0
    /// Whether this screen has started its shooting session. A full-screen print or question over it makes it disappear
    /// and appear again, which must not start the session, or open the camera, a second time.
    @State private var started = false
    #if DEBUG
    /// Hosted tests that show a running camera's screen leave the camera closed, so no failure to open it shows.
    var opensCamera = true
    /// Hosted tests that show the 6×6 with a slider open in its strip.
    var initialSlider: StripSlider?
    /// Where hosted tests, which cannot read the accessibility tree, learn where the screen put its parts.
    var probe: CaptureLayoutProbe?
    #endif

    var body: some View {
        @Bindable var capture = model.capture
        let held = HeldTurn(capture.held)
        GeometryReader { screen in
            ScrollView {
                // The safe-area reader ends at the shutter bar; the full-width area keeps its own height within it.
                CaptureColumn(room: screen.size.height) {
                    header(capture).padding(.horizontal, 16).captureColumnRole(.header)
                        .zIndex(1)
                    if let film = model.film(filmID) {
                        let behavior = CaptureBehavior.for(film.camera.id, focusSetting: film.effectiveFocusSetting)
                        // Each role is the outermost modifier, which `CaptureColumn` reads from its subviews.
                        viewfinder(film, behavior: behavior, held: held)
                            .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }) { viewfinderFrame = $0 }
                            .captureColumnRole(.viewfinder(aspect: CGFloat(behavior.viewfinder.aspectRatio)))
                        if showsStrip(film, behavior: behavior, controller: capture) {
                            controlStrip(film, behavior: behavior, controller: capture)
                                .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }) { stripFrame = $0 }
                                .onDisappear { stripFrame = nil }
                                .captureColumnRole(.strip)
                        }
                    }
                }
            }
            // The full-width 4:3 area keeps its dimensions; the content scrolls when the screen cannot show all of it.
            .scrollBounceBehavior(.basedOnSize)
            #if DEBUG
            .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }) { probe?.room = $0 }
            #endif
        }
        // The shutter stays on screen on small iPhones, at large text sizes and below messages.
        .safeAreaInset(edge: .bottom) { shutterBar(capture) }
        .onGeometryChange(for: CGFloat.self, of: { $0.safeAreaInsets.bottom }) { bottomInset = $0 }
        // One ground around the black Viewfinder area, from the top bar to the shutter bar, however much room a taller
        // iPhone leaves between them.
        .background(Self.ground)
        .environment(\.heldTurn, held)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: held)
        #if DEBUG
        .onChange(of: viewfinderFrame, initial: true) { probe?.viewfinder = viewfinderFrame }
        .onChange(of: stripFrame, initial: true) { probe?.strip = stripFrame }
        #endif
        .onAppear {
            // Once per presentation: a print or question closing brings this screen back without a second start. After a
            // print the camera starts again only from `showNextPrint`.
            guard !started else { return }
            started = true
            #if DEBUG
            openSlider = initialSlider
            #endif
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

    /// Done, Develop at once when enabled, and the Camera name and count share the 44-point top bar above the Viewfinder
    /// area. With the iPhone on its side the bar stays where it is and only its pieces turn in place to read upright, as in
    /// the iPhone Camera app (the captain, 2026-10-29, "5A"): Done in its corner and the count in the other, without the
    /// Camera's name, which VoiceOver still reads with the whole count. Nothing in the bar runs over the Viewfinder area.
    private func header(_ capture: CaptureController) -> some View {
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
        .frame(maxWidth: .infinity, alignment: .leading)
        // Done is 38 points tall at the top of the 44-point bar, the count and the notice centred on it, which leaves 6
        // points between Done and the Viewfinder area (the captain, 2026-10-29); its tap area stays 44 points.
        .frame(height: CaptureDoneRow.height)
        .frame(height: 44, alignment: .top)
        .zIndex(1)
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
        if let error { WholeWords(error).foregroundStyle(.red).font(.callout).multilineTextAlignment(.center) }
        if let message = capture.message, message != "Saved" || savedShowing {
            WholeWords(message).font(.callout).foregroundStyle(secondary).multilineTextAlignment(.center)
        }
        if capture.microphoneUnavailable {
            WholeWords("Microphone access is off. Movie clips will be silent.")
                .font(.callout).foregroundStyle(secondary).multilineTextAlignment(.center)
                .accessibilityIdentifier("microphone-permission-note")
        }
        if cameraDenied {
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            } label: {
                Label { WholeWords("Open iPhone Settings") } icon: { Image(systemName: "gearshape") }
            }
            .accessibilityLabel("Open iPhone Settings")
            .noticeButtonStyle(onDark: onDark)
        }
        if capture.offersResume(for: film, showingError: error != nil) {
            Button { open(film) } label: {
                Label { WholeWords("Resume Camera") } icon: { Image(systemName: "arrow.clockwise") }
            }
            .accessibilityLabel("Resume Camera")
            .disabled(capture.busy)
            .noticeButtonStyle(onDark: onDark)
        }
        if film.completionState == .open {
            ForEach(lensNotes(behavior: behavior, controller: capture), id: \.self) {
                WholeWords($0).font(.caption).foregroundStyle(secondary).multilineTextAlignment(.center)
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
    /// live preview; black bars fill the rest. Notices float over the area without changing its size, clear of the
    /// control strip where it sits over the area's bottom edge.
    private func viewfinder(_ film: Film, behavior: CaptureBehavior, held: HeldTurn) -> some View {
        let capture = model.capture
        let showsLowLightCue = behavior.showsLowLightCue && capture.showsLowLightCue
        let showsStatus = hasStatus(film, controller: capture)
        // How much of the area's bottom the strip covers: none where it is under the area.
        let stripOverlap = stripFrame.map { max(0, viewfinderFrame.maxY - $0.minY) } ?? 0
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
                // The notices take the area above the strip where it covers the area's bottom, so a long notice, as at
                // the largest text sizes, never runs over the focus switch.
                let room = max(area.size.height - (stripOverlap > 0 ? stripOverlap + 8 : 0), 80)
                notices(film, controller: capture, showsLowLightCue: showsLowLightCue, showsStatus: showsStatus,
                        showsPreview: showsDevelopedPreview, boxHeight: room)
                    .frame(width: area.size.width, height: room, alignment: held.isSideways ? .center : held.topEdge)
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

    /// The Zoom Steps the strip offers: on the 6×6, Super 8 and 16mm rear cameras of an iPhone that reports more than one.
    private func zoomSteps(_ behavior: CaptureBehavior, controller capture: CaptureController) -> [ZoomStep] {
        let steps = capture.controls.zoomSteps
        return behavior.offersZoomSteps && capture.position == .rear && steps.count > 1 ? steps : []
    }

    /// Whether the open Film's Camera has anything for the strip. The Instant has nothing, and the 16mm, whose only
    /// control is its Zoom Steps, has nothing where they are not offered, so no empty strip shows.
    private func showsStrip(_ film: Film, behavior: CaptureBehavior, controller capture: CaptureController) -> Bool {
        film.completionState == .open
            && (film.camera.focusSettings.count > 1 || offersSliders(behavior)
                || !zoomSteps(behavior, controller: capture).isEmpty)
    }

    /// Whether the Camera opens sliders in its strip: the 6×6, whose Exposure is always offered and Focus in Manual.
    private func offersSliders(_ behavior: CaptureBehavior) -> Bool { behavior.offersManualFocus || behavior.offersExposureBias }

    /// The low-light cue, the status lines and, in a Debug build, the preview of the latest capture, turned as one block.
    /// It sits at the viewfinder's top when upright and in its middle when held sideways.
    @ViewBuilder private func notices(
        _ film: Film, controller capture: CaptureController, showsLowLightCue: Bool, showsStatus: Bool, showsPreview: Bool,
        boxHeight: CGFloat
    ) -> some View {
        if showsLowLightCue || showsStatus || showsPreview {
            let block = TurnedBlock(length: min(noticeBlockLength(showsPreview: showsPreview), max(boxHeight - 16, 80))) {
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
                                             opens: film.camera.medium == .photo
                                                 || (!capture.busy && [.idle, .interrupted].contains(capture.phase)),
                                             open: { model.developedPreviews.inspected = developedPreview },
                                             close: { model.developedPreviews.dismiss() })
                    }
                    #endif
                }
            }
            .padding(8)
            // The block reads at the person's text size where it fits the room above the controls whole. Where it does
            // not, as over the 6×6's rows or with the microphone note at the largest sizes, it reads at the largest
            // smaller size, no smaller than the default, at which it fits with every word on one line (`WholeWords`):
            // turned, that is along its lines and across them. Only a block too long even then scrolls in its room
            // rather than running over the controls. It holds no state a swap of identity could lose.
            let smaller = DynamicTypeSize.allCases.filter { $0 >= .large && $0 < dynamicTypeSize }.reversed()
            ViewThatFits(in: HeldTurn(capture.held).isSideways ? [.horizontal, .vertical] : .vertical) {
                block
                ForEach(smaller, id: \.self) { block.dynamicTypeSize($0) }
                ScrollView(.vertical, showsIndicators: false) { block.dynamicTypeSize(min(dynamicTypeSize, .large)) }
            }
        }
    }

    /// The control strip under the Viewfinder area (the captain, 2026-10-29, "4A"), where the iPhone Camera app has its
    /// PHOTO / VIDEO row: the Zoom Steps, the focus switch and, on the 6×6, its Focus and Exposure buttons. Its lines are
    /// kept short (44 points, and the 6×6's switch as tall as "Manual" is long), so the 6×6's two lines fit under the area
    /// on an iPhone 17 Pro and every larger one. A 6×6 slider opens in the strip in the Zoom Steps' place, as the iPhone Camera app swaps its zoom buttons
    /// for its exposure dial, and takes the whole strip, since its caption, turned with the iPhone on its side, is longer
    /// than one line is tall; its close button brings the steps back. Each control has its own dark ground, so the strip
    /// reads alike under the area and over the picture, and takes the same room in every hold, its words and icons
    /// turning inside it. Like the focus switch before it, every part grows with the text size no further than the first
    /// accessibility size.
    private func controlStrip(_ film: Film, behavior: CaptureBehavior, controller capture: CaptureController) -> some View {
        let steps = zoomSteps(behavior, controller: capture)
        let sliders = offersSliders(behavior)
        let open = openSlider.flatMap { $0 == .focus && !behavior.offersManualFocus ? nil : $0 }
        return ZStack {
            ControlStripLayout(keepsStepsLine: sliders) {
                if !steps.isEmpty {
                    zoomStepsPill(steps, controller: capture).controlStripLine(.steps)
                } else if sliders {
                    // The 6×6's steps' line, kept where it has no steps, as on its front camera.
                    Color.clear.frame(width: 0, height: 44).accessibilityHidden(true).controlStripLine(.steps)
                }
                if film.camera.focusSettings.count > 1 {
                    FocusModeSwitch(settings: film.camera.focusSettings, selected: film.effectiveFocusSetting) { setting in
                        guard setting != film.effectiveFocusSetting else { return }
                        model.perform({
                            let updated = try model.setFocusSetting(setting, filmID: filmID)
                            try await capture.updateFocusSetting(for: updated)
                        }, failure: { error = $0 })
                    }
                    .disabled(capture.busy || capture.phase == .savingPhoto || capture.phase == .savingMovieClip)
                    #if DEBUG
                    .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }) { probe?.focusSwitch = $0 }
                    #endif
                    .controlStripLine(.settings)
                }
                if behavior.offersManualFocus { sliderButton(.focus, controller: capture) }
                if behavior.offersExposureBias { sliderButton(.exposure, controller: capture) }
            }
            .opacity(open == nil ? 1 : 0).allowsHitTesting(open == nil).accessibilityHidden(open != nil)
            if sliders {
                // Laid out whether open or not, so the strip keeps the taller one's height whichever shows.
                sliderPanel(open ?? .exposure, controller: capture)
                    .opacity(open == nil ? 0 : 1).allowsHitTesting(open != nil).accessibilityHidden(open == nil)
            }
        }
        .padding(.horizontal, 12)
        .environment(\.colorScheme, .dark)
        .tint(.white)
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        // Back to Auto, the Focus slider has nothing to set, so the steps come back.
        .onChange(of: behavior.offersManualFocus) { _, manual in
            if !manual && openSlider == .focus { openSlider = nil }
        }
    }

    /// The Zoom Steps, the iPhone's own lenses labeled as its Camera app labels them, in a pill as tall as a line of the
    /// strip. Each label turns in place with the hold. A step can be taken only between photo exposures or Recorded Clips.
    private func zoomStepsPill(_ steps: [ZoomStep], controller capture: CaptureController) -> some View {
        HStack(spacing: 0) {
            ForEach(steps) { step in
                let selected = step == capture.controls.zoomStep
                Button {
                    model.perform { try await capture.selectZoomStep(step) } failure: { error = $0 }
                } label: {
                    TurnedInPlace {
                        Text(step.label).font(.footnote.weight(.semibold).monospacedDigit()).lineLimit(1)
                    }
                    // 8 points around a label in every hold, as "0.5x" has at its sides in its 44 points at the
                    // default size: upright at its sides, turned at its ends.
                    .padding(8)
                    .foregroundStyle(selected ? Color.black : Color.white)
                    .frame(minWidth: 44, minHeight: 44)
                    .background { if selected { Circle().fill(Color.white).padding(3) } }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(capture.phase != .idle || capture.busy)
                .accessibilityLabel("Zoom \(step.spokenLabel)")
                .accessibilityShowsLargeContentViewer { Text(step.label) }
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier("zoom-\(step.label)")
            }
        }
        .padding(.horizontal, 4)
        .background(.black.opacity(0.6), in: Capsule())
        // Like the focus switch's words, its labels reserve their turned length, so they grow no further than the
        // largest size short of the accessibility sizes, where the 6×6's two lines still fit under the Viewfinder area.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        #if DEBUG
        .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }) { probe?.zoomSteps = $0 }
        #endif
    }

    /// The 6×6's Focus or Exposure button, which opens its slider in the strip. With no lens running there is no slider
    /// to show, so it waits for one.
    private func sliderButton(_ slider: StripSlider, controller capture: CaptureController) -> some View {
        Button { openSlider = slider } label: {
            Image(systemName: slider.symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .turnedWithTheHold()
                .frame(width: 44, height: 44)
                .background(Color.black.opacity(0.6), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!capture.lensIsLive)
        // "Focus" or "Exposure" with the slider's current value (FR-39).
        .accessibilityLabel(slider.name)
        .accessibilityValue(slider == .focus ? "\(Int((capture.focus * 100).rounded())) percent"
                                              : String(format: "%.1f EV", capture.exposure))
        .accessibilityShowsLargeContentViewer { Label(slider.name, systemImage: slider.symbol) }
        .accessibilityIdentifier("strip-\(slider.identifier)")
        .controlStripLine(.settings)
    }

    /// A slider opened in the strip, with a close button that brings the Zoom Steps back. The slider keeps its caption, its
    /// value and, where the lens cannot do it, its note in the slider's place (`CaptionedSlider`).
    private func sliderPanel(_ slider: StripSlider, controller: CaptureController) -> some View {
        @Bindable var capture = controller
        let bias: ClosedRange<Double>? = {
            guard let minimum = capture.controls.minimumExposureBias, let maximum = capture.controls.maximumExposureBias,
                  minimum < maximum else { return nil }
            return Double(minimum)...Double(maximum)
        }()
        return HStack(spacing: 4) {
            switch slider {
            case .focus:
                CaptionedSlider(
                    caption: Text("Focus").font(.caption),
                    unavailable: "Manual focus unavailable on this lens", lensIsLive: capture.lensIsLive,
                    slider: capture.controls.manualFocus
                        ? Slider(value: $capture.focus, in: 0...1, onEditingChanged: { editing in
                            if !editing { model.perform { try await capture.setFocus() } failure: { error = $0 } }
                        }).accessibilityLabel("Focus")
                        : nil
                )
            case .exposure:
                CaptionedSlider(
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
            Button { openSlider = nil } label: {
                Image(systemName: "xmark").font(.body.weight(.semibold)).foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close \(slider.name)")
            .accessibilityShowsLargeContentViewer { Label("Close \(slider.name)", systemImage: "xmark") }
            .accessibilityIdentifier("strip-close-slider")
        }
        .padding(.leading, 14).padding(.vertical, 4)
        .frame(maxHeight: .infinity)
        .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 14))
        #if DEBUG
        .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }) { if openSlider != nil { probe?.slider = $0 } }
        #endif
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

    /// Switch Camera, the shutter and flash. The icons turn in place; the shutter is a circle and stays as it is, on the
    /// screen's centre line whatever the symbols beside it are and however large the text makes them: each side takes
    /// the same width, Switch Camera against the shutter on its left and the flash on its right.
    @ViewBuilder private func shutterBar(_ controller: CaptureController) -> some View {
        @Bindable var capture = controller
        if let film = model.film(filmID), film.completionState == .open {
            HStack(spacing: 32) {
                Button("Switch Camera", systemImage: "arrow.triangle.2.circlepath.camera") {
                    model.perform { try await capture.switchLens(film: film) } failure: { error = $0 }
                }.labelStyle(.iconOnly).font(.title2)
                    .frame(minWidth: 44, minHeight: 44).turnedWithTheHold()
                    .disabled(capture.phase != .idle || capture.busy)
                    .accessibilityShowsLargeContentViewer()
                    .frame(maxWidth: .infinity, alignment: .trailing)
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
                    }.frame(width: 76, height: 76)
                }
                .disabled(capture.busy || (capture.phase != .idle && capture.phase != .recordingMovie) || model.busyFilms.contains(filmID))
                .accessibilityLabel(capture.phase == .recordingMovie ? "Stop recording" : film.camera.medium == .movie ? "Record clip" : "Take photo")
                .accessibilityIdentifier("capture-shutter")
                #if DEBUG
                .onGeometryChange(for: CGRect.self, of: { $0.frame(in: .global) }) { probe?.shutter = $0 }
                #endif
                Group {
                    if CaptureBehavior.for(film.camera.id, focusSetting: film.effectiveFocusSetting).offersFlash && capture.controls.flash {
                        Toggle(isOn: $capture.flash) { Label("Flash", systemImage: capture.flash ? "bolt.fill" : "bolt.slash") }
                            .toggleStyle(.button).labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                            .turnedWithTheHold().disabled(capture.phase != .idle)
                            .accessibilityShowsLargeContentViewer()
                    } else if film.camera.medium == .photo {
                        Image(systemName: "bolt.slash").foregroundStyle(.secondary).frame(width: 44).turnedWithTheHold()
                    } else {
                        Color.clear.frame(width: 44, height: 44).accessibilityHidden(true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            // As short as the shutter, which leaves the 6×6's two-line control strip room under the Viewfinder area, with
            // room under it only where no home indicator's area gives it some, as on the iPhone SE. Its symbols, like the
            // top bar's, grow no further than the largest size short of the accessibility sizes, where they are still
            // shorter than the shutter, and show in the Large Content Viewer.
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .padding(.bottom, bottomInset > 0 ? 0 : 8)
            .frame(maxWidth: .infinity).background(Self.ground)
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

/// The 6×6's sliders, each opened in the control strip from a button of its own.
enum StripSlider: Equatable {
    case focus, exposure

    /// The slider's own name, which its caption, its button and VoiceOver use.
    var name: String { self == .focus ? "Focus" : "Exposure" }
    var symbol: String { self == .focus ? "scope" : "plusminus.circle" }
    var identifier: String { self == .focus ? "focus" : "exposure" }
}

#if DEBUG
/// Where the shooting screen put its parts, in the window, for hosted tests, which cannot read the accessibility tree.
@Observable final class CaptureLayoutProbe {
    /// The room the screen leaves the column above the shutter bar.
    var room = CGRect.zero
    var viewfinder = CGRect.zero
    var strip: CGRect?
    var zoomSteps: CGRect?
    /// The slider open in the 6×6's strip, once one has opened.
    var slider: CGRect?
    var focusSwitch: CGRect?
    var shutter = CGRect.zero
}
#endif

/// The focus switch, "Auto / Fixed" or "Auto / Manual" (FR-25), in the control strip: one segment per setting, as wide as
/// its word reads upright and as tall as the longest word is long, turned, with room at each end, so the switch takes the
/// same room in every hold while its words turn in place to read upright. VoiceOver reads it as one control, "Focus, Auto", changed with a
/// double tap or the adjustable action.
struct FocusModeSwitch: View {
    let settings: [FilmFocusSetting]
    let selected: FilmFocusSetting
    let select: (FilmFocusSetting) -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        HStack(spacing: 0) {
            ForEach(settings, id: \.self) { setting in
                Button { select(setting) } label: {
                    TurnedInPlace { Text(setting.title).font(.footnote.weight(.semibold)).lineLimit(1) }
                        // Room at each end of a turned word, which "Manual" at this size needs.
                        .padding(.horizontal, 14).padding(.vertical, 4)
                        .frame(minWidth: 44, minHeight: 44)
                        .frame(maxHeight: .infinity)
                        .background { if setting == selected { Capsule().fill(Color.white.opacity(0.24)).padding(3) } }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(isEnabled ? 1 : 0.45))
            }
        }
        // Every segment as tall as the tallest, so the selected one's capsule is the same whichever is selected.
        .fixedSize()
        .background(Color.black.opacity(0.6), in: Capsule())
        // Its words reserve their turned length, which makes it the strip's tallest control, so they grow no further
        // than the largest size short of the accessibility sizes, where the 6×6's two lines still fit under the
        // Viewfinder area on the largest iPhone.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Focus")
        .accessibilityValue(selected.title)
        .accessibilityShowsLargeContentViewer { Text(settings.map(\.title).joined(separator: " / ")) }
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

/// The leading part of the shooting screen's top bar: Done and, in a Debug build, the notice that Develop at once is on
/// for this Camera. `CaptureView` places the Camera name and count beside this row.
struct CaptureDoneRow: View {
    @Environment(\.heldTurn) private var turn
    let done: @MainActor () -> Void
    #if DEBUG
    /// Whether Develop at once is on for the Camera (`DevelopedPreviews.applies(to:)`).
    var developsAtOnce = false
    #endif

    var body: some View {
        if turn.isSideways {
            // Held sideways Done turns in place in the top bar's corner: a round button as tall as the upright one, whose
            // word reads upright inside it, so no part of it runs over the Viewfinder area.
            HStack(spacing: 8) {
                Button(action: done) {
                    TurnedInPlace { Text("Done").font(.footnote.weight(.semibold)) }
                        .frame(width: Self.height, height: Self.height)
                }
                .buttonStyle(.plain)
                // A glass circle, against the bar's edge where the upright button starts.
                .glassEffect(.regular.interactive(), in: Circle())
                .contentShape(Self.tapArea)
                .accessibilityLabel("Done")
                .accessibilityShowsLargeContentViewer()
                #if DEBUG
                if developsAtOnce { DevelopAtOnceNotice() }
                #endif
            }
        } else {
            uprightRow
        }
    }

    /// How tall Done shows: 6 points short of the 44-point top bar, which leaves that much between it and the Viewfinder
    /// area below (the captain, 2026-10-29: "please add little bit of spacing between the "Done" button and the
    /// viewfinder").
    static let height: CGFloat = 38
    /// Done's tap area, 44 points tall: 3 points past its glass above and below.
    private static var tapArea: some Shape { Rectangle().inset(by: -3) }

    @ViewBuilder private var uprightRow: some View {
        // The glass adds 7 points above and below its label.
        let button = Button(action: done) { Text("Done").frame(minHeight: Self.height - 14) }.buttonStyle(.glass)
            .contentShape(Self.tapArea)
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

/// The Camera's short name and compact count in the shooting screen's top bar. The visible words stay short at every
/// text size; the full Camera name and count remain available to VoiceOver and the Large Content Viewer. Held sideways
/// only the count shows, turned in place in the bar's corner, as tall as the bar at most.
private struct CaptureHeaderLabel: View {
    @Environment(\.heldTurn) private var turn
    let film: Film
    let status: CaptureHeaderStatus
    let recording: Bool

    var body: some View {
        Group {
            if turn.isSideways {
                // Lines as long as Done is tall, which turned keeps the count level with it: "27" and "3:20" fit at the
                // size the bar holds, and the longer states ("Film complete") shrink to fit rather than run over the area.
                TurnedBlock(length: CaptureDoneRow.height) {
                    count.multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.5)
                        .frame(width: CaptureDoneRow.height)
                }
            } else {
                HStack(spacing: 6) {
                    Text(SpokenText.shown(film.camera.shortName))
                        .font(.system(.title3, design: .serif))
                        .lineLimit(1).minimumScaleFactor(0.6)
                    count.lineLimit(1).minimumScaleFactor(0.6)
                }
            }
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

    private var count: some View {
        Text(status.visible)
            .font(.body.monospaced())
            .foregroundStyle(recording ? .red : .primary)
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
    /// How long the caption reads when the iPhone is on its side, which is as tall as the row.
    @ScaledMetric(relativeTo: .caption) private var captionLength: CGFloat = 64
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
        // As tall as the turned caption makes it, in every hold, so the control strip never depends on the hold.
        .frame(minHeight: captionLength)
    }

    /// Text across the width it is given, against the leading edge upright and centred turned.
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

/// A notice's text, which never breaks inside a word: offered lines shorter than its longest word, it asks for that
/// word's length instead, so the notices read at a smaller text size rather than hyphenate the word. Where every word
/// fits it is the text as it was.
struct WholeWords: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        WholeWordsLayout {
            Text(text)
            // Each word on a line of its own, in the text's own font, is as wide as the longest word.
            Text(text.split(whereSeparator: \.isWhitespace).joined(separator: "\n")).fixedSize().hidden()
        }
        // One element, the text as it shows, for VoiceOver and for anything the notice adds to it.
        .accessibilityRepresentation { Text(text) }
    }
}

private struct WholeWordsLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let longestWord = subviews[1].sizeThatFits(.unspecified).width
        return subviews[0].sizeThatFits(ProposedViewSize(width: proposal.width.map { max($0, longestWord) },
                                                         height: proposal.height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        // Offered no height, so the text takes the height it measured (as `TurnedLayout` does).
        subviews[0].place(at: bounds.origin, anchor: .topLeading, proposal: ProposedViewSize(width: bounds.width, height: nil))
        subviews[1].place(at: bounds.origin, anchor: .topLeading, proposal: .zero)
    }
}

private extension View {
    /// A button in a notice: white on the dark ground it sits on over the viewfinder, the app's own tint elsewhere.
    @ViewBuilder func noticeButtonStyle(onDark: Bool) -> some View {
        if onDark { buttonStyle(.bordered).tint(.white).foregroundStyle(.white) } else { self }
    }
}
