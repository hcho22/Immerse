import SwiftUI
import UIKit

@main
struct SetupAccessibilityProbeApp: App {
    var body: some Scene {
        WindowGroup { ProbeRoot().tint(.accentColor) }
    }
}

private struct ProbeRoot: View {
    @State private var setup = false

    var body: some View {
        NavigationStack {
            Text("Film Journal").navigationTitle("Film Journal")
                .toolbar {
                    ToolbarItem(placement: .bottomBar) {
                        Button("Start a Film", systemImage: "plus") { setup = true }
                            .accessibilityIdentifier("start-film")
                    }
                }
        }.sheet(isPresented: $setup) { NavigationStack { ProbeSetup() } }
    }
}

private struct ProbeSetup: View {
    @Environment(\.dynamicTypeSize) private var size
    @State private var title = "16mm - Roll #01"
    @State private var orientation = "Portrait"
    private var stackContainer: Bool { ProcessInfo.processInfo.arguments.contains("-stackContainer") }

    var body: some View {
        Group {
            if stackContainer {
                if ProcessInfo.processInfo.arguments.contains("-boundedViewport") {
                    GeometryReader { viewport in
                        stackScroll.frame(width: viewport.size.width, height: viewport.size.height)
                    }
                } else if ProcessInfo.processInfo.arguments.contains("-outerPadding") {
                    stackScroll.padding(.vertical, 16)
                } else {
                    stackScroll
                }
            } else {
                originalForm
            }
        }
        .scrollEdgeEffectStyle(ProcessInfo.processInfo.arguments.contains("-hardEdge") ? .hard : nil, for: .all)
        .scrollEdgeEffectHidden(ProcessInfo.processInfo.arguments.contains("-suppressEdges"))
        .navigationTitle("16mm")
        .background(WindowMetrics())
        .onScrollGeometryChange(for: ScrollGeometry.self) { $0 } action: { _, geometry in
            ProbeLog.record("scroll", [
                "offset": [geometry.contentOffset.x, geometry.contentOffset.y],
                "bounds": ProbeLog.rect(geometry.bounds), "visibleRect": ProbeLog.rect(geometry.visibleRect),
                "insets": [geometry.contentInsets.top, geometry.contentInsets.leading,
                           geometry.contentInsets.bottom, geometry.contentInsets.trailing],
                "containerSize": [geometry.containerSize.width, geometry.containerSize.height],
                "contentSize": [geometry.contentSize.width, geometry.contentSize.height]
            ])
            ProbeLog.nativeViewports()
        }
        .onChange(of: size) { _, _ in
            DispatchQueue.main.async { ProbeLog.captureWindow() }
        }
    }

    private var stackScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 35) { sections }
                .padding(.horizontal, 16)
        }.background(Color(uiColor: .systemGroupedBackground))
    }

    private var originalForm: some View {
        Form {
            Section {
                LabeledContent("Capacity", value: "2:45 of film")
                Text("One silent Movie after Development")
                Text("Deliberate framing, finer grain").foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true).probe("camera-description")
                HStack {
                    Image(systemName: "mic.slash").font(.system(size: 20)).accessibilityHidden(true)
                    Text("Silent capture").fixedSize(horizontal: false, vertical: true).probe("silent-capture")
                }.accessibilityElement(children: .combine)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Movie Orientation").fixedSize(horizontal: false, vertical: true).probe("orientation-label")
                    if size.isAccessibilitySize || ProcessInfo.processInfo.arguments.contains("-stableOrientationMenu") {
                        orientationPicker.pickerStyle(.menu).labelsHidden()
                    }
                    else { orientationPicker.pickerStyle(.segmented).labelsHidden() }
                }
            }
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Film title").font(.headline).foregroundStyle(Color.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("film-title-heading").accessibilityAddTraits(.isHeader)
                        .probe("film-title")
                    TextField("Title", text: $title, axis: .vertical).accessibilityLabel("Film title")
                }
            }
            Section {
                Label("One Trial Film on this iPhone", systemImage: "ticket").probe("trial-label")
                Text("The first saved capture uses the Trial. Your Camera and Movie Orientation cannot change after loading.")
                    .font(.footnote).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
            }
            Section { NavigationLink("Subscription") { Text("Subscription") } }
            Section {
                Button {} label: {
                    HStack { Text("Load Film").probe("load-film"); Spacer(); Image(systemName: "camera") }
                }.accessibilityIdentifier("load-film")
            }
        }
    }

    private var sections: some View {
        Group {
            section {
                row { LabeledContent("Capacity", value: "2:45 of film") }
                row { Text("One silent Movie after Development") }
                row {
                    Text("Deliberate framing, finer grain").foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true).probe("camera-description")
                }
                row { HStack {
                    Image(systemName: "mic.slash").font(.system(size: 20)).accessibilityHidden(true)
                    Text("Silent capture").fixedSize(horizontal: false, vertical: true).probe("silent-capture")
                }.accessibilityElement(children: .combine) }
                row { VStack(alignment: .leading, spacing: 8) {
                    Text("Movie Orientation").fixedSize(horizontal: false, vertical: true).probe("orientation-label")
                    if size.isAccessibilitySize || ProcessInfo.processInfo.arguments.contains("-stableOrientationMenu") {
                        orientationPicker.pickerStyle(.menu).labelsHidden()
                    }
                    else { orientationPicker.pickerStyle(.segmented).labelsHidden() }
                } }
            }
            section {
                row { VStack(alignment: .leading, spacing: 8) {
                    Text("Film title").font(.headline).foregroundStyle(Color.primary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("film-title-heading").accessibilityAddTraits(.isHeader)
                        .probe("film-title")
                    TextField("Title", text: $title, axis: .vertical).accessibilityLabel("Film title")
                } }
            }
            section {
                row { Label("One Trial Film on this iPhone", systemImage: "ticket").probe("trial-label") }
                row {
                    Text("The first saved capture uses the Trial. Your Camera and Movie Orientation cannot change after loading.")
                        .font(.footnote).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
                }
            }
            section { row { NavigationLink("Subscription") { Text("Subscription") } } }
            section {
                row { Button {} label: {
                    HStack { Text("Load Film").probe("load-film"); Spacer(); Image(systemName: "camera") }
                }.accessibilityIdentifier("load-film") }
            }
        }
    }

    private func section<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0, content: content)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
    }

    private func row<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        // Match the observed default Form insets/minimum; rows remain unbounded at larger sizes.
        content().padding(.vertical, 15).padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
    }

    private var orientationPicker: some View {
        Picker("Movie Orientation", selection: $orientation) {
            Text("Portrait").tag("Portrait")
            Text("Landscape").tag("Landscape")
        }
    }
}

private struct Metrics: ViewModifier {
    @Environment(\.dynamicTypeSize) private var size
    @Environment(\.colorScheme) private var appearance
    @State private var frame = CGRect.zero
    let id: String

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { value in
                frame = value
                snapshot()
            }
            .onChange(of: size, initial: true) { _, _ in snapshot() }
            .onChange(of: appearance, initial: true) { _, _ in snapshot() }
    }

    private func snapshot() {
        let record: [String: Any] = [
            "id": id, "dynamicTypeSize": String(describing: size),
            "appearance": String(describing: appearance),
            "preferredBodyPoints": UIFont.preferredFont(forTextStyle: .body).pointSize,
            "frame": [frame.minX, frame.minY, frame.width, frame.height],
            "time": Date().timeIntervalSince1970,
            "uptime": ProcessInfo.processInfo.systemUptime
        ]
        if let data = try? JSONSerialization.data(withJSONObject: record, options: [.sortedKeys]),
           let string = String(data: data, encoding: .utf8) { print("SETUP_PROBE \(string)") }
    }
}

@MainActor
private enum ProbeLog {
    static weak var window: UIWindow?
    private static var nativeGeometry: [ObjectIdentifier: [CGFloat]] = [:]
    private static let captureRun = UUID().uuidString
    private static var captureNumber = 0

    static func rect(_ value: CGRect) -> [CGFloat] { [value.minX, value.minY, value.width, value.height] }
    static func insets(_ value: UIEdgeInsets) -> [CGFloat] { [value.top, value.left, value.bottom, value.right] }

    static func nativeViewports() {
        guard let window else { return }
        func visit(_ view: UIView) {
            if let scroll = view as? UIScrollView {
                let frame = rect(scroll.convert(scroll.bounds, to: window))
                let bounds = rect(scroll.bounds)
                let adjusted = insets(scroll.adjustedContentInset)
                let contentInset = insets(scroll.contentInset)
                let contentSize = [scroll.contentSize.width, scroll.contentSize.height]
                let geometry = frame + bounds + adjusted + contentInset + contentSize
                let id = ObjectIdentifier(scroll)
                if nativeGeometry[id] != geometry {
                    nativeGeometry[id] = geometry
                    record("native-scroll", ["id": String(describing: id), "windowFrame": frame,
                                              "bounds": bounds, "adjustedInset": adjusted,
                                              "contentInset": contentInset, "contentSize": contentSize,
                                              "safeArea": insets(scroll.safeAreaInsets),
                                              "clipsToBounds": scroll.clipsToBounds])
                }
            } else if let navigation = view as? UINavigationBar {
                let frame = rect(navigation.convert(navigation.bounds, to: window))
                let id = ObjectIdentifier(navigation)
                if nativeGeometry[id] != frame {
                    nativeGeometry[id] = frame
                    record("native-navigation", ["id": String(describing: id), "windowFrame": frame,
                                                  "title": navigation.topItem?.title ?? "",
                                                  "hidden": navigation.isHidden])
                }
            }
            view.subviews.forEach(visit)
        }
        visit(window)
    }

    static func captureWindow() {
        guard let window, !window.bounds.isEmpty else { return }
        if ProcessInfo.processInfo.arguments.contains("-disableWindowCaptures") {
            nativeViewports()
            record("size-screen-disabled", ["category": window.traitCollection.preferredContentSizeCategory.rawValue])
            return
        }
        captureNumber += 1
        let start = Date().timeIntervalSince1970
        let category = window.traitCollection.preferredContentSizeCategory.rawValue
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        var rendered = false
        let image = renderer.image { _ in
            rendered = window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let captured = Date().timeIntervalSince1970
        nativeViewports()
        do {
            guard rendered, let png = image.pngData() else {
                record("size-screen-failed", ["reason": "Window drawing did not complete"])
                return
            }
            let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("ViewportEvidence/\(captureRun)", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let file = "size-\(captureNumber).png"
            try png.write(to: folder.appendingPathComponent(file), options: .atomic)
            record("size-screen", ["file": "\(captureRun)/\(file)", "captureStart": start,
                                   "captureReturned": captured, "category": category])
        } catch {
            record("size-screen-failed", ["reason": String(describing: error)])
        }
    }

    static func record(_ event: String, _ values: [String: Any]) {
        var record = values
        record["event"] = event
        record["time"] = Date().timeIntervalSince1970
        record["uptime"] = ProcessInfo.processInfo.systemUptime
        if let data = try? JSONSerialization.data(withJSONObject: record, options: [.sortedKeys]),
           let string = String(data: data, encoding: .utf8) { print("SETUP_VIEWPORT \(string)") }
    }
}

private struct WindowMetrics: UIViewRepresentable {
    func makeUIView(context: Context) -> WindowMetricsView { WindowMetricsView() }
    func updateUIView(_ uiView: WindowMetricsView, context: Context) {}
}

private final class WindowMetricsView: UIView {
    private var lastGeometry: [CGFloat] = []

    init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used by this probe") }

    override func didMoveToWindow() { super.didMoveToWindow(); snapshot() }
    override func safeAreaInsetsDidChange() { super.safeAreaInsetsDidChange(); snapshot() }
    override func layoutSubviews() { super.layoutSubviews(); snapshot() }

    private func snapshot() {
        guard let window else { return }
        ProbeLog.window = window
        ProbeLog.nativeViewports()
        let frame = convert(bounds, to: window)
        let insets = [safeAreaInsets.top, safeAreaInsets.left, safeAreaInsets.bottom, safeAreaInsets.right]
        let geometry = ProbeLog.rect(frame) + insets + ProbeLog.rect(window.bounds)
        guard geometry != lastGeometry else { return }
        lastGeometry = geometry
        ProbeLog.record("window", ["rootFrame": ProbeLog.rect(frame), "rootSafeArea": insets,
                                   "windowBounds": ProbeLog.rect(window.bounds),
                                   "windowSafeArea": [window.safeAreaInsets.top, window.safeAreaInsets.left,
                                                      window.safeAreaInsets.bottom, window.safeAreaInsets.right]])
    }
}

private extension View {
    func probe(_ id: String) -> some View { modifier(Metrics(id: id)) }
}
