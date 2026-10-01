import AVFoundation
import FilmDomain
import NativeAdapters
import SwiftUI

struct CaptureView: View {
    @Environment(JournalModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let filmID: UUID
    @State private var error: String?
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
                                Text(String(format: "%.1f seconds left", max(0, (film.remainingMovieSeconds ?? 0) - context.date.timeIntervalSince(start))))
                                    .font(.body.monospaced()).foregroundStyle(.red)
                            } else { Text(film.remainingLabel).font(.body.monospaced()) }
                        }
                        ZStack {
                            Color.black
                            if let preview = capture.preview {
                                CameraPreview(source: preview, position: capture.position, orientation: capture.orientation,
                                              square: film.camera.id == .mediumFormat6x6 || film.camera.id == .instant1970s)
                            } else { Image(systemName: "camera").font(.largeTitle).foregroundStyle(.white) }
                        }
                        .aspectRatio(film.camera.id == .mediumFormat6x6 || film.camera.id == .instant1970s ? 1 : 0.75, contentMode: .fit)
                        .clipped()
                        .accessibilityLabel(capture.position == .front ? "Mirrored front viewfinder" : "Rear viewfinder")
                        if let error { Text(error).foregroundStyle(.red).font(.callout) }
                        if let message = capture.message { Text(message).font(.callout).foregroundStyle(.secondary) }
                        if capture.phase == .interrupted || error != nil || capture.message?.contains("Retry") == true {
                            Button("Resume Camera", systemImage: "arrow.clockwise") { open(film) }.disabled(capture.busy)
                        }
                        if film.completionState != .open {
                            Text(film.camera.revealRule == .instantPerExposure ? "Pack complete" : "Film complete").font(.headline)
                        } else {
                            HStack(spacing: 32) {
                                Button("Switch Camera", systemImage: "arrow.triangle.2.circlepath.camera") {
                                    model.perform { try await capture.switchLens(camera: film.camera) }
                                }.labelStyle(.iconOnly).font(.title2)
                                    .disabled(capture.phase != .idle || capture.busy)
                                Button {
                                    Task {
                                        do { try await capture.shutter(film: film) }
                                        catch { self.error = error.localizedDescription }
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
                                if film.camera.id == .disposable1990s && capture.controls.flash {
                                    Toggle(isOn: $capture.flash) { Label("Flash", systemImage: capture.flash ? "bolt.fill" : "bolt.slash") }
                                        .toggleStyle(.button).labelStyle(.iconOnly).disabled(capture.phase != .idle)
                                } else { Image(systemName: film.camera.medium == .movie ? "mic.slash" : "bolt.slash").foregroundStyle(.secondary).frame(width: 44) }
                            }
                            if film.camera.id == .mediumFormat6x6 {
                                if capture.controls.manualFocus {
                                    VStack(alignment: .leading) {
                                        Text("Focus").font(.caption)
                                        Slider(value: $capture.focus, in: 0...1, onEditingChanged: { editing in
                                            if !editing { model.perform { try await capture.setFocus() } }
                                        }).accessibilityLabel("Focus")
                                    }
                                } else { Text("Manual focus unavailable on this lens").font(.caption).foregroundStyle(.secondary) }
                                if let minimum = capture.controls.minimumExposureBias, let maximum = capture.controls.maximumExposureBias, minimum < maximum {
                                    VStack(alignment: .leading) {
                                        Text("Exposure \(capture.exposure, specifier: "%.1f") EV").font(.caption.monospaced())
                                        Slider(value: $capture.exposure, in: Double(minimum)...Double(maximum), onEditingChanged: { editing in
                                            if !editing { model.perform { try await capture.setExposure() } }
                                        }).accessibilityLabel("Exposure")
                                    }
                                }
                            }
                            if film.camera.id == .disposable1990s && !capture.controls.flash {
                                Text("Flash unavailable on this lens").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }.padding()
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { capture.suspend(); dismiss() } } }
            .task { if let film = model.film(filmID) { open(film) } }
            .onAppear {
                UIDevice.current.beginGeneratingDeviceOrientationNotifications()
                lastRevealedSequence = model.film(filmID)?.captures.last(where: { $0.revealState == .revealed })?.sequenceNumber
            }
            .onDisappear { UIDevice.current.endGeneratingDeviceOrientationNotifications(); capture.suspend() }
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
    private func open(_ film: Film) {
        Task {
            do { try await model.capture.open(film: film, model: model); error = nil }
            catch { self.error = "Camera unavailable. \(error.localizedDescription)" }
        }
    }
}

private struct CameraPreview: UIViewRepresentable {
    let source: CapturePreviewSource
    let position: CapturePosition
    let orientation: CaptureFrameOrientation
    let square: Bool
    func makeUIView(context: Context) -> PreviewSurface {
        let surface = PreviewSurface()
        surface.preview = source.makeLayer()
        return surface
    }
    func updateUIView(_ uiView: PreviewSurface, context: Context) {
        if let layer = uiView.preview {
            layer.videoGravity = square ? .resizeAspectFill : .resizeAspect
            try? source.update(layer, position: position, orientation: orientation)
        }
    }
}

private final class PreviewSurface: UIView {
    var preview: AVCaptureVideoPreviewLayer? {
        didSet { oldValue?.removeFromSuperlayer(); if let preview { layer.addSublayer(preview) }; setNeedsLayout() }
    }
    override func layoutSubviews() { super.layoutSubviews(); preview?.frame = bounds }
}
