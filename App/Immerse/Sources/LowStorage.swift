import FilmDomain
import NativeAdapters
import Observation
import SwiftUI

/// A step that needs free space, which the low-storage warning comes before: taking captures on a Film, or
/// developing it.
enum LowStorageStep: CaseIterable {
    case capture, development
}

/// The low-storage warning's words (DEC-12): the cause, what may not finish, what is not affected and what the
/// person can do. It warns and stops nothing; a save that cannot complete still fails as it always has.
enum LowStorageCopy {
    static func warning(for step: LowStorageStep) -> String {
        switch step {
        case .capture:
            "This iPhone has less than 2 GB free, so a capture may not save. A capture that does not save uses no exposures or time, and saved captures are unchanged. Free space in iPhone Settings."
        case .development:
            "This iPhone has less than 2 GB free, so Development may not finish. Saved captures are unchanged, and Development can be resumed. Free space in iPhone Settings."
        }
    }
}

/// Whether this iPhone is low on free space, as last read. The screens that show the warning read again each time
/// they appear, and the Journal reads again whenever it refreshes, so the warning goes once space is freed.
@MainActor @Observable
final class LowStorageCheck {
    private let reader: any FreeSpaceReading
    private(set) var isLow = false

    init(reader: any FreeSpaceReading) { self.reader = reader }

    /// Reads free space off the main actor, since the system can take a moment to count what it could clear.
    /// A reading that fails is not low: the warning states a fact about this iPhone, and the app does not state one
    /// it could not read. Nothing depends on the warning, so a save that cannot complete still fails honestly.
    func refresh() async {
        let reader = reader
        isLow = await Task.detached { (try? reader.availableBytes()).map(LowStorage.isLow(availableBytes:)) ?? false }.value
    }

    /// The warning to show before `step`, or nil while there is room or no reading.
    func warning(for step: LowStorageStep) -> String? {
        isLow ? LowStorageCopy.warning(for: step) : nil
    }
}

extension Film {
    /// The step this Film's screen offers that needs space: captures while the Film is open, then Development until
    /// it is developed. A developed Film offers neither.
    var stepNeedingSpace: LowStorageStep? {
        if completionState == .open { return .capture }
        return canStartDevelopment || offersResumeDevelopment ? .development : nil
    }
}

/// The warning as every screen shows it: Orbit's outlined note with the drive mark (B04, G01), one element that VoiceOver
/// reads whole, with text that wraps at any size and its mark beside the first line.
struct LowStorageNotice: View {
    let text: String

    var body: some View {
        OrbitNote(.custom("externaldrive.badge.exclamationmark", outlined: true), text, identifier: "low-storage-warning")
    }
}

#if DEBUG
/// A set free-space reading for screen tests and screenshots, which cannot fill a disk: launching with
/// `-ImmerseDebugFreeSpace <bytes>` reads that many bytes, and any other value, such as `unreadable`, is a reading
/// that fails. Without the argument the app reads the iPhone. Compiled out of Release, which
/// `Scripts/verify-release-excludes-testing-unlock.sh` checks.
struct DebugFreeSpace: FreeSpaceReading {
    static let defaultsKey = "ImmerseDebugFreeSpace"
    private let bytes: Int64?

    init?(defaults: UserDefaults) {
        guard let value = defaults.string(forKey: Self.defaultsKey) else { return nil }
        bytes = Int64(value)
    }

    func availableBytes() throws -> Int64 {
        guard let bytes else { throw FreeSpaceError.noReading }
        return bytes
    }
}
#endif
