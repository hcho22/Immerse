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
        let awaitsPrints = camera.revealRule == .instantPerExposure && captures.contains { $0.revealState == .sealed }
        return canStartDevelopment || developmentState == .developing || awaitsPrints ? .development : nil
    }
}

/// The warning as every screen shows it: one element that VoiceOver reads whole, with text that wraps at any size
/// and its symbol beside the first line. A `Label` would center the symbol on the paragraph in a list and color it
/// as text outside one. The symbol grows with the text only as far as body text is at Extra Extra Extra Large,
/// 23 points: at the accessibility sizes a larger one left the words a column two or three words wide. Its size is
/// set in points because a list row did not apply a `dynamicTypeSize` limit to it.
struct LowStorageNotice: View {
    let text: String
    @ScaledMetric(relativeTo: .body) private var symbolSize: CGFloat = 17

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: "externaldrive.badge.exclamationmark").font(.system(size: min(symbolSize, 23)))
                .foregroundStyle(.tint).accessibilityHidden(true)
            Text(text).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("low-storage-warning")
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
