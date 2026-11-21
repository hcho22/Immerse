import SwiftUI

/// What a confirmation's ring shows (C04): the share used, and the amount and its word in the middle.
struct OrbitRingValue: Equatable {
    let progress: Double
    let amount: String
    let caption: String
}

extension View {
    /// A sheet the screen raises over itself with Orbit's 32-point corners: on the surface for a dialog's choice
    /// (G02), on the black ground for a whole screen such as Settings or the Darkroom (A04, I01).
    func orbitSheet(screen: Bool = false) -> some View {
        presentationBackground(screen ? Orbit.ground : Orbit.surface).presentationCornerRadius(32)
    }

    /// The ground under a sheet's scrolling content, matching `orbitSheet(screen:)`.
    func orbitSheetGround(screen: Bool = false) -> some View {
        background((screen ? Orbit.ground : Orbit.surface).ignoresSafeArea())
    }

    /// A confirmation that rises from the bottom (C04, C05, H05, J04): a mark or a ring, its question, what it does, the
    /// white confirm, never red, and Cancel. It is as tall as it needs, and scrolls where the text size makes it taller
    /// than the screen.
    func orbitConfirmation(
        isPresented: Binding<Bool>, symbol: String? = nil, emphasized: Bool = false, ring: OrbitRingValue? = nil,
        title: String, message: String, confirm: String, identifier: String? = nil, action: @escaping () -> Void
    ) -> some View {
        sheet(isPresented: isPresented) {
            OrbitConfirmation(symbol: symbol, emphasized: emphasized, ring: ring, title: title, message: message,
                              confirm: confirm, identifier: identifier, action: action)
        }
    }
}

private struct OrbitConfirmation: View {
    @Environment(\.dismiss) private var dismiss
    let symbol: String?
    let emphasized: Bool
    let ring: OrbitRingValue?
    let title: String
    let message: String
    let confirm: String
    let identifier: String?
    let action: () -> Void
    @State private var height: CGFloat = 400

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let ring {
                    ZStack {
                        OrbitRing(progress: ring.progress, lineWidth: 12)
                        VStack(spacing: 0) {
                            Text(ring.amount).orbitFont(.display)
                            Text(ring.caption).orbitFont(.footnote).foregroundStyle(Orbit.label)
                        }
                    }
                    .frame(width: 180, height: 180)
                    .accessibilityHidden(true)
                } else if let symbol {
                    Image(systemName: symbol).font(.system(size: 30, weight: .regular))
                        .foregroundStyle(emphasized ? Color.black : Color.white)
                        .frame(width: 88, height: 88)
                        .background(emphasized ? Color.white : Orbit.pressed, in: Circle())
                        .padding(.top, 12)
                        .accessibilityHidden(true)
                }
                Text(title).orbitFont(.heading).multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text(message).orbitFont(.body).foregroundStyle(Orbit.body).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 10) {
                    Button(confirm) { dismiss(); action() }
                        .buttonStyle(OrbitPillStyle(kind: .white, minHeight: 56, fullWidth: true))
                        .accessibilityIdentifier(identifier ?? confirm)
                    Button("Cancel") { dismiss() }
                        .buttonStyle(OrbitDialogCancelStyle())
                }
                .padding(.top, 8)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 24).padding(.top, 28).padding(.bottom, 12)
            .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { height = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        .presentationDetents([.height(height)])
        .presentationDragIndicator(.visible)
        .orbitSheet()
    }
}

/// A dialog's Cancel: a full-width 56-point pill on the pressed grey (C04).
struct OrbitDialogCancelStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .orbitFont(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(configuration.isPressed ? Orbit.hairline : Orbit.pressed, in: Capsule())
            .contentShape(Capsule())
    }
}

/// One choice of a radio group in a sheet (G02, H06): a dot and its words on a rounded row, the dot filled and the row
/// outlined in white once chosen.
struct OrbitRadioRow: View {
    let title: String
    let selected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: 14) {
                ZStack {
                    if selected {
                        Circle().fill(Color.white)
                        Circle().fill(Color.black).frame(width: 10, height: 10)
                    } else {
                        Circle().strokeBorder(Orbit.disabledMark, lineWidth: 1.5)
                    }
                }
                .frame(width: 28, height: 28)
                Text(title).orbitFont(.headline).foregroundStyle(.white).multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 18).padding(.vertical, 16)
            .background(Orbit.button, in: RoundedRectangle(cornerRadius: 28))
            .overlay { if selected { RoundedRectangle(cornerRadius: 28).strokeBorder(Color.white, lineWidth: 1.5) } }
            .contentShape(RoundedRectangle(cornerRadius: 28))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}
