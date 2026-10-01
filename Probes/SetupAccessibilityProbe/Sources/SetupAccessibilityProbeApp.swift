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
                ScrollView {
                    VStack(alignment: .leading, spacing: 35) { sections }
                        .padding(.horizontal, 16)
                }.background(Color(uiColor: .systemGroupedBackground))
            } else {
                originalForm
            }
        }
        .scrollEdgeEffectStyle(ProcessInfo.processInfo.arguments.contains("-hardEdge") ? .hard : nil, for: .all)
        .navigationTitle("16mm")
        .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, offset in
            print("SETUP_PROBE scrollOffset=\(offset)")
        }
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
                Label("One Trial Film on this iPhone", systemImage: "ticket")
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
                row { Label("One Trial Film on this iPhone", systemImage: "ticket") }
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
            "time": Date().timeIntervalSince1970
        ]
        if let data = try? JSONSerialization.data(withJSONObject: record, options: [.sortedKeys]),
           let string = String(data: data, encoding: .utf8) { print("SETUP_PROBE \(string)") }
    }
}

private extension View {
    func probe(_ id: String) -> some View { modifier(Metrics(id: id)) }
}
