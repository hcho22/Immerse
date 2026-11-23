import AuthenticationServices
import DeclaredAgeRange
import ImmerseServer
import SwiftUI
import Synchronization

extension EnvironmentValues {
    /// Signing in to host, where the app has a server; nil everywhere else, which hides every part of it.
    @Entry var hosting: HostingSession? = nil
}

/// Group Film under Start a Film (V2-FR-02, V2-FR-10): the one place that asks a signed-out person to sign in. Stage 1
/// builds the way in: the age 13-or-over confirmation, then Sign in with Apple, Google or email through Clerk, then the
/// Account. Creating the Group Film itself is Stage 2.
struct GroupFilmEntry: View {
    var body: some View {
        NavigationLink { GroupFilmGate() } label: {
            Label("Host a Group Film", systemImage: "person.2").labelStyle(.titleAndIcon)
        }
        .buttonStyle(OrbitPillStyle(kind: .outline, minHeight: 48))
        .accessibilityIdentifier("group-film")
    }
}

struct GroupFilmGate: View {
    @Environment(\.hosting) private var hosting
    @State private var confirmation: AgeConfirmationMethod?
    @State private var tooYoung = false

    var body: some View {
        Group {
            if let hosting {
                switch hosting.phase {
                case .signedIn(let name):
                    GroupFilmSignedIn(displayName: name)
                case .needsAccount:
                    if tooYoung { TooYoungView() }
                    else if let confirmation { CreatingAccount(confirmation: confirmation) }
                    else { AgeConfirmationView(confirmed: { confirmation = $0 }, declined: decline) }
                case .signedOut:
                    if tooYoung { TooYoungView() }
                    else if let confirmation { SignInMethodsView(confirmation: confirmation) }
                    else { AgeConfirmationView(confirmed: { confirmation = $0 }, declined: decline) }
                }
            }
        }
        .orbitSheetGround(screen: true)
        .navigationTitle("Group Film")
        .toolbarTitleDisplayMode(.inline)
        .onAppear { tooYoung = hosting.map { AgeDecline.isRecent(defaults: $0.defaults) } ?? false }
        .task { await hosting?.refresh() }
    }

    private func decline() {
        if let hosting { AgeDecline.record(defaults: hosting.defaults) }
        tooYoung = true
    }
}

/// A decline is kept for a day, so going back does not simply offer the question again (the FTC's advice on age
/// screens). Nothing about the person is kept with it.
enum AgeDecline {
    private static let key = "ImmerseAgeDeclinedAt"

    static func record(defaults: UserDefaults, now: Date = .now) { defaults.set(now, forKey: key) }

    static func isRecent(defaults: UserDefaults, now: Date = .now) -> Bool {
        guard let at = defaults.object(forKey: key) as? Date else { return false }
        return now.timeIntervalSince(at) < 24 * 60 * 60
    }
}

/// The age 13-or-over confirmation (V2-FR-03, open check OC-9). Where iOS says the person is in a region whose law
/// requires an age check (iOS 26.2's `isEligibleForAgeFeatures`), Apple's Declared Age Range answers with a gate at 13.
/// Everywhere else, or when the person does not share an age range, they give their birth month and year, which stay on
/// the iPhone: a neutral question with no answer chosen for them, never an "I'm 13 or over" box.
struct AgeConfirmationView: View {
    let confirmed: (AgeConfirmationMethod) -> Void
    let declined: () -> Void
    @State private var askingApple = true
    @State private var month: Int?
    @State private var yearText = ""
    @FocusState private var yearFocused: Bool

    /// The year typed, once it is four digits from 120 years ago to this year.
    private var year: Int? {
        guard yearText.count == 4, let value = Int(yearText), AgeGate.selectableYears().contains(value) else { return nil }
        return value
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Hosting needs an Account").orbitFont(.title).accessibilityAddTraits(.isHeader)
                Text("Only the Host signs in. Guests and personal Films never need an Account. Accounts are for people 13 or over.")
                    .orbitFont(.body).foregroundStyle(Orbit.body).fixedSize(horizontal: false, vertical: true)
                if askingApple {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 20)
                } else {
                    birthMonthAndYear
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, Orbit.gutter).padding(.vertical, 16)
        }
        .scrollBounceBehavior(.basedOnSize)
        .task { await askApple() }
    }

    private var birthMonthAndYear: some View {
        VStack(alignment: .leading, spacing: 16) {
            OrbitSectionLabel("When were you born?").padding(.leading, 4)
            HStack(spacing: 12) {
                Menu {
                    ForEach(1...12, id: \.self) { value in
                        Button(Calendar.current.monthSymbols[value - 1]) { month = value }
                    }
                } label: {
                    choice(month.map { Calendar.current.monthSymbols[$0 - 1] } ?? "Month")
                }
                .accessibilityIdentifier("birth-month")
                TextField("Year", text: $yearText)
                    .keyboardType(.numberPad).textContentType(.none)
                    .focused($yearFocused)
                    .onChange(of: yearText) { _, typed in
                        let digits = String(typed.filter(\.isNumber).prefix(4))
                        if digits != typed { yearText = digits }
                    }
                    .orbitFont(.headline).foregroundStyle(.white).tint(.white)
                    .padding(.horizontal, 20).frame(minHeight: 56)
                    .background(Orbit.button, in: Capsule())
                    .accessibilityLabel("Birth year")
                    .accessibilityIdentifier("birth-year")
            }
            Text("Your birth month and year stay on this iPhone. Immerse keeps only that you confirmed you are 13 or over.")
                .orbitFont(.footnote).foregroundStyle(Orbit.label).fixedSize(horizontal: false, vertical: true)
            Button("Continue") {
                yearFocused = false
                guard let month, let year else { return }
                if AgeGate.isOldEnough(birthYear: year, birthMonth: month) { confirmed(.birthMonthAndYear) } else { declined() }
            }
            .primaryAction()
            .disabled(month == nil || year == nil)
            .accessibilityIdentifier("age-continue")
            .padding(.top, 8)
        }
    }

    private func choice(_ text: String) -> some View {
        HStack {
            Text(text).orbitFont(.headline)
            Spacer(minLength: 4)
            Image(systemName: "chevron.up.chevron.down").font(.system(size: 13, weight: .bold)).foregroundStyle(Orbit.label)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20).frame(minHeight: 56)
        .background(Orbit.button, in: Capsule())
    }

    /// Whether iOS says the person is in a region whose law requires apps to check age (iOS 26.2 and later). An answer
    /// that does not come within three seconds, as on an iPhone or simulator with no Apple Account, counts as no: the birth
    /// month and year stand in rather than leaving the person waiting.
    private nonisolated static func regionRequiresAgeCheck() async -> Bool {
        guard #available(iOS 26.2, *) else { return false }
        // A task group would wait for a call that never returns, so whichever answers first resumes the wait.
        return await withCheckedContinuation { continuation in
            let answered = Mutex(false)
            let answer: @Sendable (Bool) -> Void = { value in
                let first = answered.withLock { done in
                    defer { done = true }
                    return !done
                }
                if first { continuation.resume(returning: value) }
            }
            Task { answer((try? await AgeRangeService.shared.isEligibleForAgeFeatures) == true) }
            Task {
                try? await Task.sleep(for: .seconds(3))
                answer(false)
            }
        }
    }

    private enum AppleAnswer: Sendable { case oldEnough, tooYoung, notShared }

    /// Apple's Declared Age Range with a gate at 13, presented over `controller`.
    private nonisolated static func askAppleForAgeRange(in controller: UIViewController) async -> AppleAnswer {
        do {
            switch try await AgeRangeService.shared.requestAgeRange(ageGates: AgeGate.minimumAge, in: controller) {
            case .sharing(let range):
                guard let lower = range.lowerBound else { return .tooYoung }
                return lower >= AgeGate.minimumAge ? .oldEnough : .tooYoung
            case .declinedSharing:
                return .notShared
            @unknown default:
                return .notShared
            }
        } catch {
            // Not available on this Account or iPhone: the birth month and year stand in.
            return .notShared
        }
    }

    private func askApple() async {
        defer { askingApple = false }
        guard await Self.regionRequiresAgeCheck(), let controller = Self.presentingController() else { return }
        switch await Self.askAppleForAgeRange(in: controller) {
        case .oldEnough: confirmed(.declaredAgeRange)
        case .tooYoung: declined()
        case .notShared: break
        }
    }

    private static func presentingController() -> UIViewController? {
        let root = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }.first
        var top = root
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

private struct TooYoungView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.crop.circle.badge.xmark").font(.system(size: 34, weight: .light))
                .frame(width: 96, height: 96).background(Orbit.surface, in: Circle())
                .accessibilityHidden(true)
            Text("You can't sign in yet").orbitFont(.title).multilineTextAlignment(.center).accessibilityAddTraits(.isHeader)
            Text("Accounts are for people 13 or over. You can still join Group Films as a guest, and every personal Film works as before.")
                .orbitFont(.body).foregroundStyle(Orbit.body).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button("Back") { dismiss() }
                .buttonStyle(OrbitPillStyle(kind: .white, minHeight: 56, fullWidth: true))
                .accessibilityIdentifier("too-young-back")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Sign in with Apple, Google or email, all through Clerk (V2-FR-01). Apple's button is Apple's own, offered first and
/// wherever Google is (guideline 4.8).
struct SignInMethodsView: View {
    @Environment(\.hosting) private var hosting
    let confirmation: AgeConfirmationMethod
    @State private var email = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Sign in to host").orbitFont(.title).accessibilityAddTraits(.isHeader)
                Text("Sign in with Apple, Google or your email address.")
                    .orbitFont(.body).foregroundStyle(Orbit.body).fixedSize(horizontal: false, vertical: true)
                if let hosting {
                    if email {
                        EmailCodeForm(confirmation: confirmation)
                    } else {
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
                            guard case .success(let authorization) = result,
                                  let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                                  let token = credential.identityToken.flatMap({ String(data: $0, encoding: .utf8) })
                            else { return }
                            Task {
                                await hosting.signInWithApple(identityToken: token, givenName: credential.fullName?.givenName,
                                                              familyName: credential.fullName?.familyName, confirmedBy: confirmation)
                            }
                        }
                        .signInWithAppleButtonStyle(.white)
                        .frame(height: 56).clipShape(Capsule())
                        .accessibilityIdentifier("sign-in-apple")
                        Button { Task { await hosting.signInWithGoogle(confirmedBy: confirmation) } } label: {
                            Text("Continue with Google")
                        }
                        .buttonStyle(OrbitPillStyle(kind: .outline, minHeight: 56, fullWidth: true))
                        .accessibilityIdentifier("sign-in-google")
                        Button { email = true } label: { Text("Continue with email") }
                            .buttonStyle(OrbitPillStyle(kind: .outline, minHeight: 56, fullWidth: true))
                            .accessibilityIdentifier("sign-in-email")
                    }
                    if hosting.busy { ProgressView().frame(maxWidth: .infinity) }
                    if let problem = hosting.problem { OrbitNote(.error, problem, identifier: "sign-in-problem") }
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, Orbit.gutter).padding(.vertical, 16)
        }
        .scrollBounceBehavior(.basedOnSize)
        .disabled(hosting?.busy == true)
    }
}

private struct EmailCodeForm: View {
    @Environment(\.hosting) private var hosting
    let confirmation: AgeConfirmationMethod
    @State private var address = ""
    @State private var code = ""
    @State private var codeSent = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if codeSent {
                Text("Enter the code sent to \(address).").orbitFont(.footnote).foregroundStyle(Orbit.label)
                TextField("Code", text: $code)
                    .textContentType(.oneTimeCode).keyboardType(.numberPad)
                    .modifier(FieldLook()).accessibilityIdentifier("email-code")
                Button("Sign In") { Task { await hosting?.verifyEmailCode(code, confirmedBy: confirmation) } }
                    .primaryAction().disabled(code.isEmpty).accessibilityIdentifier("email-verify")
            } else {
                TextField("Email address", text: $address)
                    .textContentType(.emailAddress).keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .modifier(FieldLook()).accessibilityIdentifier("email-address")
                Button("Send Code") {
                    Task { if await hosting?.sendEmailCode(to: address) == true { codeSent = true } }
                }
                .primaryAction().disabled(!address.contains("@")).accessibilityIdentifier("email-send")
            }
        }
    }
}

private struct FieldLook: ViewModifier {
    func body(content: Content) -> some View {
        content.orbitFont(.headline).foregroundStyle(.white).tint(.white)
            .padding(.horizontal, 20).frame(minHeight: 56)
            .background(Orbit.button, in: Capsule())
    }
}

/// Signed in with Clerk but with no Account yet, as after signing in on a new iPhone whose Account was never made: the
/// Account is made with the confirmation just given.
private struct CreatingAccount: View {
    @Environment(\.hosting) private var hosting
    let confirmation: AgeConfirmationMethod

    var body: some View {
        VStack(spacing: 16) {
            if let problem = hosting?.problem {
                OrbitNote(.error, problem)
                Button("Try Again") { Task { await hosting?.createAccount(confirmedBy: confirmation) } }.primaryAction()
            } else {
                ProgressView()
            }
        }
        .padding(.horizontal, Orbit.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await hosting?.createAccount(confirmedBy: confirmation) }
    }
}

/// Signed in, with an Account. Stage 2 puts creating the Group Film here.
private struct GroupFilmSignedIn: View {
    let displayName: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Signed in as \(displayName)").orbitFont(.title).accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("hosting-signed-in")
                Text("Creating a Group Film, with its link and QR code, comes in a later update. Your personal Films work as always.")
                    .orbitFont(.body).foregroundStyle(Orbit.body).fixedSize(horizontal: false, vertical: true)
                Text("Manage your Account in Settings.").orbitFont(.footnote).foregroundStyle(Orbit.label)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, Orbit.gutter).padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
