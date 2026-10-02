import EntitlementCore
import Foundation
import Security
import Synchronization

/// Only this non-shipping adapter owns fault simulation. No production fallback.
final class RecordedReceiptCalls: TrialKeychainCalling, Sendable {
    private struct FaultState: Codable { var unreadable = false; var resolved = false }
    private let state: Mutex<FaultState>
    private let configuration: ScenarioConfiguration
    private let evidence: ScenarioEvidence
    private let native = SystemTrialKeychainCalls()
    private let receiptFile: URL
    private let faultFile: URL

    init(configuration: ScenarioConfiguration, evidence: ScenarioEvidence) throws {
        self.configuration = configuration; self.evidence = evidence
        receiptFile = configuration.directory.appendingPathComponent("injected-receipt.json")
        faultFile = configuration.directory.appendingPathComponent("fault-state.json")
        let saved = FileManager.default.fileExists(atPath: faultFile.path)
            ? try JSONDecoder().decode(FaultState.self, from: Data(contentsOf: faultFile)) : FaultState()
        state = Mutex(saved)
    }

    func resolveInjectedFault() throws {
        try state.withLock { value in
            value.resolved = true; value.unreadable = false
            try ScenarioEvidence.persist(value, to: faultFile)
        }
        evidence.record("injected-fault-resolved", ["receiptChanged": "false"])
    }

    func observeUnderlying() -> TrialKeychainRead { state.withLock { _ in underlyingRead() } }

    func read(service: String) -> TrialKeychainRead {
        guard allowed(service) else { return TrialKeychainRead(status: errSecParam, data: nil) }
        return state.withLock { value in
            let actual = underlyingRead()
            if value.unreadable && !value.resolved {
                evidence.record("injected-read-status", ["returned": String(errSecInteractionNotAllowed), "actual": String(actual.status)])
                return TrialKeychainRead(status: errSecInteractionNotAllowed, data: nil)
            }
            return actual
        }
    }

    func add(service: String, data: Data) -> OSStatus {
        guard allowed(service) else { return errSecParam }
        return state.withLock { _ in
            let status: OSStatus
            if configuration.backend == .security { status = native.add(service: service, data: data) }
            else {
                do { try data.write(to: receiptFile, options: .withoutOverwriting); status = errSecSuccess }
                catch { status = FileManager.default.fileExists(atPath: receiptFile.path) ? errSecDuplicateItem : errSecIO }
            }
            evidence.record("adapter-add", ["backend": configuration.backend.rawValue, "status": String(status), "sha256": ScenarioEvidence.hash(data)])
            return status
        }
    }

    func update(service: String, data: Data) -> OSStatus {
        guard allowed(service) else { return errSecParam }
        return state.withLock { value in
            let fault = value.resolved ? ReceiptFault.none : configuration.fault
            let status: OSStatus
            if fault == .unknownNotApplied {
                status = errSecNotAvailable
                evidence.record("injected-update-not-dispatched")
            } else if configuration.backend == .security {
                status = native.update(service: service, data: data)
            } else {
                do {
                    guard FileManager.default.fileExists(atPath: receiptFile.path) else { return errSecItemNotFound }
                    try data.write(to: receiptFile, options: .atomic)
                    let file = try FileHandle(forWritingTo: receiptFile)
                    try file.synchronize(); try file.close()
                    status = errSecSuccess
                } catch { status = errSecIO }
            }
            evidence.record("adapter-update", ["backend": configuration.backend.rawValue, "actualStatus": String(status),
                "dispatched": String(fault != .unknownNotApplied), "sha256": ScenarioEvidence.hash(data)])
            if fault == .unknownApplied || fault == .unknownNotApplied {
                value.unreadable = true
                do { try ScenarioEvidence.persist(value, to: faultFile) }
                catch { fatalError("Cannot retain injected fault: \(error)") }
            }
            if [.lostReply, .unknownApplied, .unknownNotApplied].contains(fault) {
                evidence.record("injected-update-reply", ["returned": String(errSecNotAvailable), "actual": String(status)])
                return errSecNotAvailable
            }
            return status
        }
    }

    private func allowed(_ service: String) -> Bool {
        service == configuration.service && service.hasPrefix("com.immerse.validation.receipt035.")
    }

    private func underlyingRead() -> TrialKeychainRead {
        let result: TrialKeychainRead
        if configuration.backend == .security { result = native.read(service: configuration.service) }
        else if !FileManager.default.fileExists(atPath: receiptFile.path) { result = .init(status: errSecItemNotFound, data: nil) }
        else {
            do { result = .init(status: errSecSuccess, data: try Data(contentsOf: receiptFile)) }
            catch { result = .init(status: errSecIO, data: nil) }
        }
        evidence.record("adapter-read", ["backend": configuration.backend.rawValue, "status": String(result.status),
            "sha256": result.data.map(ScenarioEvidence.hash) ?? "none"])
        return result
    }
}
