import SwiftUI

/// The Group Film a shooting screen or print belongs to (v2 PRD V2-FR-31, V2-FR-32): the End Time this phone last
/// learned, at which shooting stops. Nil, the default, is a personal Film, which nothing here changes.
struct EventShooting: Equatable {
    let endsAt: Date
}

extension EnvironmentValues {
    @Entry var eventShooting: EventShooting? = nil
}
