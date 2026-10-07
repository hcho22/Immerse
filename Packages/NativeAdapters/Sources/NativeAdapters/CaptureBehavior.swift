import FilmDomain
import Foundation

/// How a Camera's lens focuses. `fixed` holds one lens position like a fixed-focus lens; `manual`
/// leaves focus to the person (the 6×6 focus control); `deviceDefault` is the phone's continuous autofocus.
public enum FocusBehavior: Equatable, Sendable {
    case deviceDefault, fixed, manual
}

/// How a Camera sets exposure. `fixed` is one exposure value applied to every exposure (the Disposable),
/// `manualBias` lets the person bias the phone's automatic exposure (the 6×6) and `automatic` is the phone's.
public enum ExposureBehavior: Equatable, Sendable {
    case automatic, fixed, manualBias
}

/// The shape a viewfinder frames, which is the shape the exposure develops to.
public enum ViewfinderShape: Equatable, Sendable {
    case square, threeByTwo, fourByThree

    /// Width over height of the viewfinder box. Photos follow how the iPhone is held and Movies the
    /// interface, so a portrait interface frames the short side across.
    public func aspectRatio(landscape: Bool) -> Double {
        let wide: Double
        switch self {
        case .square: return 1
        case .threeByTwo: wide = 3.0 / 2
        case .fourByThree: wide = 4.0 / 3
        }
        return landscape ? wide : 1 / wide
    }

    /// Whether the phone's 4:3 capture is cropped to this shape on screen. The 4:3 viewfinder shows it whole.
    public var cropsCapture: Bool { self != .fourByThree }
}

/// A Camera's capture behavior in the viewfinder and on the lens, set by PRD 2.1 FR-04 and section 6.
/// Everything here is exposure guidance or lens configuration; none of it previews the developed look.
public struct CaptureBehavior: Equatable, Sendable {
    public let focus: FocusBehavior
    public let exposure: ExposureBehavior
    public let viewfinder: ViewfinderShape
    /// A waist-level finder shows the scene reversed left to right. Applies to the rear viewfinder only
    /// and never to the saved capture; the front viewfinder is mirrored for every Camera.
    public let reversesRearViewfinder: Bool
    public let offersFlash: Bool
    /// The viewfinder shows a cue advising flash when the scene is too dim for the fixed exposure.
    public let showsLowLightCue: Bool

    public var offersManualFocus: Bool { focus == .manual }
    public var offersExposureBias: Bool { exposure == .manualBias }

    public init(
        focus: FocusBehavior = .deviceDefault, exposure: ExposureBehavior = .automatic,
        viewfinder: ViewfinderShape = .fourByThree, reversesRearViewfinder: Bool = false,
        offersFlash: Bool = false, showsLowLightCue: Bool = false
    ) {
        self.focus = focus
        self.exposure = exposure
        self.viewfinder = viewfinder
        self.reversesRearViewfinder = reversesRearViewfinder
        self.offersFlash = offersFlash
        self.showsLowLightCue = showsLowLightCue
    }

    public static let deviceDefault = CaptureBehavior()

    public static func `for`(_ camera: CameraID) -> CaptureBehavior {
        switch camera {
        case .disposable1990s:
            CaptureBehavior(focus: .fixed, exposure: .fixed, viewfinder: .threeByTwo,
                            offersFlash: true, showsLowLightCue: true)
        case .instant1970s:
            CaptureBehavior(viewfinder: .square)
        case .mediumFormat6x6:
            CaptureBehavior(focus: .manual, exposure: .manualBias, viewfinder: .square, reversesRearViewfinder: true)
        case .super8HomeMovie:
            CaptureBehavior(focus: .fixed)
        case .cinema16mm:
            CaptureBehavior()
        }
    }

    /// Only the viewfinder is reversed or mirrored. Saved captures are never mirrored.
    public func isViewfinderMirrored(position: CapturePosition) -> Bool {
        position == .front || reversesRearViewfinder
    }
}

/// The lens position a fixed-focus Camera holds (0 is closest, 1 furthest). Provisional: the phone's lens
/// position is not calibrated in meters, so this far-leaning value (the 6×6 focus control's resting value)
/// needs the physical-phone check in `Evidence/NativeApp/manual-validation.md`.
public enum FixedFocus {
    public static let lensPosition: Float = 0.8
}

/// The Disposable's one exposure value, expressed so that every phone lens meets it.
///
/// A phone lens has a fixed aperture, so "fixed exposure" is a fixed light value: the lens holds the lowest
/// ISO its active format offers and the duration that gives `referenceEV100`. A Fun Saver-class camera
/// (1/100 s, f/10, ISO 800) sits near 10.3. This value is brighter because a sensor, unlike color negative film,
/// has no highlight latitude, so bright daylight stays usable while dim scenes still develop dark.
/// Provisional pending DEC-04 and the physical-phone feel check.
public struct FixedExposure: Equatable, Sendable {
    public static let referenceEV100 = 12.0

    public let duration: Double
    public let iso: Float

    /// The value the lens actually gets once the duration is limited to what its format allows.
    public func equivalentEV100(aperture: Double) -> Double {
        SceneLight.ev100(aperture: aperture, duration: duration, iso: iso)
    }

    public static func settings(
        aperture: Double, isoRange: ClosedRange<Float>, durationRange: ClosedRange<Double>
    ) -> FixedExposure {
        let iso = isoRange.lowerBound
        let ideal = aperture * aperture * 100 / (Double(iso) * pow(2, referenceEV100))
        return FixedExposure(
            duration: min(max(ideal, durationRange.lowerBound), durationRange.upperBound), iso: iso
        )
    }
}

public enum SceneLight {
    /// The light value (EV at ISO 100) a phone's automatic exposure settled on, which is the scene's
    /// brightness: the lower it is, the dimmer the scene.
    public static func ev100(aperture: Double, duration: Double, iso: Float) -> Double {
        guard aperture > 0, duration > 0, iso > 0 else { return .nan }
        return log2(aperture * aperture / duration) - log2(Double(iso) / 100)
    }
}

/// The viewfinder's low-light cue for the fixed exposure. The scene's brightness comes from the phone's
/// automatic exposure on the viewfinder, so the viewfinder itself is never darkened or brightened to
/// preview how the exposure will develop.
///
/// The cue shows once the scene is two stops or more below the fixed exposure, where an exposure develops
/// visibly dark (an overcast day sits at one stop or less, a room lit by a window at four or more), and
/// hides only when the scene is back within one and a half stops so it does not flicker at the threshold.
public struct LowLightCue: Equatable, Sendable {
    public static let showsAtStopsBelow = 2.0
    public static let hidesWithinStopsBelow = 1.5

    public private(set) var isShowing = false

    public init() {}

    /// Returns whether the cue shows for this reading. A reading that is not a number keeps the last state.
    @discardableResult
    public mutating func update(sceneEV100: Double, fixedEV100: Double = FixedExposure.referenceEV100) -> Bool {
        guard sceneEV100.isFinite else { return isShowing }
        let stopsBelow = fixedEV100 - sceneEV100
        if isShowing {
            if stopsBelow <= Self.hidesWithinStopsBelow { isShowing = false }
        } else if stopsBelow >= Self.showsAtStopsBelow {
            isShowing = true
        }
        return isShowing
    }
}
