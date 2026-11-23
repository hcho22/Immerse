import Foundation

/// The age 13-or-over rule for signing in and hosting (V2-FR-03), as checked from a birth month and year (open check
/// OC-9). The screen asks for both freely, a neutral age screen in the FTC's words, never a checkbox; the answer stays on
/// the iPhone and only "confirmed" reaches the server.
public enum AgeGate {
    public static let minimumAge = 13

    /// Whether someone born in that month and year is 13 or over on `date`. A month and year cannot say which day
    /// someone turns 13, so the rule takes the last day of the birth month: in the month of their thirteenth birthday a
    /// person counts as 12, and from the month after as 13.
    public static func isOldEnough(birthYear: Int, birthMonth: Int, on date: Date = .now, calendar: Calendar = .current) -> Bool {
        guard (1...12).contains(birthMonth) else { return false }
        let today = calendar.dateComponents([.year, .month], from: date)
        guard let year = today.year, let month = today.month else { return false }
        let monthsSinceBirthMonth = (year - birthYear) * 12 + (month - birthMonth)
        return monthsSinceBirthMonth > minimumAge * 12
    }

    /// The birth years the screen offers: this year back 120 years.
    public static func selectableYears(on date: Date = .now, calendar: Calendar = .current) -> [Int] {
        let year = calendar.component(.year, from: date)
        return Array((year - 120...year).reversed())
    }
}
