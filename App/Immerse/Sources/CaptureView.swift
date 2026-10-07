import AVFoundation
import FilmDomain
import NativeAdapters
import SwiftUI

struct CaptureView: View {
    @Environment(JournalModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    let filmID: UUID
    @State private var error: String?
    @State private var cameraDenied = false
    @State private var instantPrint: CaptureRecord?
    @State private var lastRevealedSequence: Int?

    var body: some View {
        @Bindable var capture = model.capture
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let film = model.film(filmID) {
                        Text(film.camera.displayName).font(.system(.title3, design: .serif))
                        TimelineView(.periodic(from: .now, by: 0.1)) { context in
                            if let start = capture.recordingStarted {
                                film.remainingText(recordedFor: context.date.timeIntervalSince(start))
                                    .font(.body.monospaced()).foregroundStyle(.red)
                            } else { (model.hasPendingSave(filmID) ? Text("Finishing save") : film.remainingText).font(.body.monospaced()) }
                        }
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
                        let behavior = CaptureBehavior.for(film.camera.id)
                        let mirrored = behavior.isViewfinderMirrored(position: capture.position)
                        ZStack {
                            Color.black
                            if let preview = capture.preview {
                                CameraPreview(source: preview, mirrored: mirrored, fillsFrame: behavior.viewfinder.cropsCapture)
                            } else { Image(systemName: "camera").font(.largeTitle).foregroundStyle(.white) }
                        }
                        .overlay(alignment: .top) {
                            if capture.showsLowLightCue { LowLightCueView().padding(8) }
                        }
                        // The 4:3 capture fills a 3:4 viewfinder in a portrait interface and a 4:3 one in landscape;
                        // the square and 3:2 Cameras crop it to the shape they develop to.
                        .aspectRatio(behavior.viewfinder.aspectRatio(landscape: verticalSizeClass == .compact), contentMode: .fit)
                        .clipped()
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel(viewfinderLabel(position: capture.position, behavior: behavior))
                        .onChange(of: capture.showsLowLightCue) { _, showing in
                            if showing { AccessibilityNotification.Announcement(LowLightCueView.spokenText).post() }
                        }
                        if film.completionState == .open {
                            if behavior.offersManualFocus {
                                if capture.controls.manualFocus {
                                    VStack(alignment: .leading) {
                                        Text("Focus").font(.caption)
                                        Slider(value: $capture.focus, in: 0...1, onEditingChanged: { editing in
                                            if !editing { model.perform { try await capture.setFocus() } failure: { error = $0 } }
                                        }).accessibilityLabel("Focus")
                                    }
                                } else { Text("Manual focus unavailable on this lens").font(.caption).foregroundStyle(.secondary) }
                            }
                            if behavior.offersExposureBias {
                                if let minimum = capture.controls.minimumExposureBias, let maximum = capture.controls.maximumExposureBias, minimum < maximum {
                                    VStack(alignment: .leading) {
                                        Text("Exposure \(capture.exposure, specifier: "%.1f") EV").font(.caption.monospaced())
                                        Slider(value: $capture.exposure, in: Double(minimum)...Double(maximum), onEditingChanged: { editing in
                                            if !editing { model.perform { try await capture.setExposure() } failure: { error = $0 } }
                                        }).accessibilityLabel("Exposure")
                                    }
                                }
                            }
                            if behavior.offersFlash && !capture.controls.flash {
                                Text("Flash unavailable on this lens").font(.caption).foregroundStyle(.secondary)
                            }
                            if behavior.exposure == .fixed && capture.preview != nil && !capture.controls.fixedExposure {
                                Text("Fixed exposure unavailable on this lens").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }.padding()
            }
            // The shutter stays on screen on small iPhones, at large text sizes and below messages.
            .safeAreaInset(edge: .bottom) {
                if let film = model.film(filmID), film.completionState == .open {
                    HStack(spacing: 32) {
                        Button("Switch Camera", systemImage: "arrow.triangle.2.circlepath.camera") {
                            model.perform { try await capture.switchLens(camera: film.camera) } failure: { error = $0 }
                        }.labelStyle(.iconOnly).font(.title2)
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
                                .toggleStyle(.button).labelStyle(.iconOnly).disabled(capture.phase != .idle)
                        } else { Image(systemName: film.camera.medium == .movie ? "mic.slash" : "bolt.slash").foregroundStyle(.secondary).frame(width: 44) }
                    }
                        .padding(.vertical, 8).frame(maxWidth: .infinity).background(.bar)
                }
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { capture.suspend(); dismiss() } } }
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
                      let newest = captures?.last(where: { $0.revealState == .revealed }),
                      newest.sequenceNumber != lastRevealedSequence else { return }
                lastRevealedSequence = newest.sequenceNumber
                capture.suspend()
                instantPrint = newest
            }
            .sheet(item: $instantPrint) { print in PhotoView(filmID: filmID, sequence: print.sequenceNumber) }
        }
    }
    private func viewfinderLabel(position: CapturePosition, behavior: CaptureBehavior) -> String {
        if position == .front { return "Mirrored front viewfinder" }
        return behavior.reversesRearViewfinder ? "Rear viewfinder, reversed left to right" : "Rear viewfinder"
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
            .accessibilityIdentifier("low-light-cue")
    }
}

private struct CameraPreview: UIViewRepresentable {
    let source: CapturePreviewSource
    let mirrored: Bool
    let fillsFrame: Bool
    func makeUIView(context: Context) -> PreviewSurface {
        let surface = PreviewSurface()
        surface.source = source
        surface.preview = source.makeLayer()
        return surface
    }
    func updateUIView(_ uiView: PreviewSurface, context: Context) {
        uiView.preview?.videoGravity = fillsFrame ? .resizeAspectFill : .resizeAspect
        uiView.mirrored = mirrored
        uiView.setNeedsLayout()
    }
}

/// The viewfinder turns with the interface, which stays upright when the iPhone is upside down
/// and keeps turning while a clip records in the orientation it started in. A turn from one
/// landscape side to the other keeps the same size, so the scene's geometry is observed too.
private final class PreviewSurface: UIView {
    var source: CapturePreviewSource?
    var mirrored = false
    var preview: AVCaptureVideoPreviewLayer? {
        didSet { oldValue?.removeFromSuperlayer(); if let preview { layer.addSublayer(preview) }; setNeedsLayout() }
    }
    private var geometry: NSKeyValueObservation?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        geometry = window?.windowScene?.observe(\.effectiveGeometry) { [weak self] _, _ in
            Task { @MainActor in self?.rotatePreview() }
        }
        rotatePreview()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        preview?.frame = bounds
        rotatePreview()
    }
    private func rotatePreview() {
        guard let preview, let source, let interface = window?.windowScene?.effectiveGeometry.interfaceOrientation,
              let orientation = CaptureFrameOrientation(interface: interface) else { return }
        try? source.update(preview, mirrored: mirrored, orientation: orientation)
    }
}
