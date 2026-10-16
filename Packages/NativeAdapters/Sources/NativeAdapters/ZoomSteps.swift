import Foundation

/// A rear lens of the iPhone, from the widest to the longest.
public enum RearLens: Int, Codable, Equatable, Comparable, Sendable {
    case ultraWide, wide, telephoto

    public static func < (lhs: RearLens, rhs: RearLens) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// One zoom step the 6×6 offers on the rear camera. A step is a whole lens, or a native crop of the wide lens that the
/// camera API reports as a step (the sensor crop some iPhones offer as 2x), and it is labeled the way the iPhone's own
/// Camera app labels it. The app never offers a step the iPhone does not report, and never a digital zoom between steps.
public struct ZoomStep: Codable, Equatable, Hashable, Sendable, Identifiable {
    public let lens: RearLens
    /// The zoom factor of `lens` itself: 1 where the step is the whole lens, above 1 where it is a native sensor crop.
    public let lensZoomFactor: Double
    /// The factor as the iPhone's Camera app labels it, where its wide lens is 1: 0.5, 1, 2, 2.5, 3, 5.
    public let displayFactor: Double

    public var id: Double { displayFactor }

    /// Whether the step crops the sensor of its lens instead of using the whole lens.
    public var isSensorCrop: Bool { lensZoomFactor > 1 }

    /// "0.5x", "1x", "2.5x": a whole number without its decimal.
    public var label: String { "\(Self.number(displayFactor))x" }

    /// What VoiceOver says: "0.5 times", since "x" is read as a letter.
    public var spokenLabel: String { "\(Self.number(displayFactor)) times" }

    public init(lens: RearLens, lensZoomFactor: Double = 1, displayFactor: Double) {
        self.lens = lens
        self.lensZoomFactor = lensZoomFactor
        self.displayFactor = displayFactor
    }

    private static func number(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }
}

/// The rear lenses an iPhone reports and the native crops of its wide lens: the facts the zoom steps derive from.
/// The camera API fills this in at run time (`AVFoundationCaptureDeviceDiscoverer`); a test injects it.
public struct RearLensCapabilities: Codable, Equatable, Sendable {
    public struct Lens: Codable, Equatable, Sendable {
        public let lens: RearLens
        /// The factor the iPhone's Camera app labels this lens with, where its wide lens is 1: 0.5 for an ultra wide
        /// lens, 3 or 5 for a telephoto lens.
        public let displayFactor: Double

        public init(_ lens: RearLens, displayFactor: Double) {
            self.lens = lens
            self.displayFactor = displayFactor
        }
    }

    /// The phone's rear lenses, widest first.
    public let lenses: [Lens]
    /// The zoom factors of the wide lens, above 1, at which the camera API reports native resolution: the sensor crops
    /// some iPhones offer (2x). Empty where the API reports none.
    public let wideNativeCropFactors: [Double]

    public init(lenses: [Lens], wideNativeCropFactors: [Double] = []) {
        self.lenses = lenses
        self.wideNativeCropFactors = wideNativeCropFactors
    }

    /// One wide lens, as every iPhone has at least.
    public static let wideOnly = RearLensCapabilities(lenses: [Lens(.wide, displayFactor: 1)])

    /// Two steps within a tenth of each other are one step.
    private static let sameStep = 0.05

    /// The zoom steps this iPhone offers, narrowest field of view last: each lens, and each native crop of the wide lens
    /// that is not already a lens's step (a 2x telephoto lens and a 2x crop are one step, the lens). Empty unless there
    /// are at least two, so an iPhone with one rear lens and no reported crop shows no zoom control.
    public var zoomSteps: [ZoomStep] {
        var steps = lenses.map { ZoomStep(lens: $0.lens, displayFactor: $0.displayFactor) }
        if let wide = lenses.first(where: { $0.lens == .wide }) {
            for factor in wideNativeCropFactors where factor > 1 {
                let display = (wide.displayFactor * factor * 10).rounded() / 10
                guard !steps.contains(where: { abs($0.displayFactor - display) < Self.sameStep }) else { continue }
                steps.append(ZoomStep(lens: .wide, lensZoomFactor: factor, displayFactor: display))
            }
        }
        steps.sort { $0.displayFactor < $1.displayFactor }
        return steps.count > 1 ? steps : []
    }

    /// The step an exposure starts on: the wide lens as a whole, which is 1x on every iPhone.
    public var restingStep: ZoomStep? {
        zoomSteps.first { $0.lens == .wide && !$0.isSensorCrop }
    }
}
