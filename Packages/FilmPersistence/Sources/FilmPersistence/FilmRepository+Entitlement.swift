import FilmDomain
import Foundation

extension FilmRepository {
    public func filmAccess(filmID: UUID) throws -> FilmAccess {
        _ = try film(id: filmID)
        guard let data = try database.value(filmID: filmID, key: "access") else { return .subscription }
        return try decoder.decode(FilmAccess.self, from: data)
    }

    public func pendingTrialConsumptions() throws -> [PendingTrialConsumption] {
        try database.pendingTrialData().map { try decoder.decode(PendingTrialConsumption.self, from: $0) }
    }

    public func finishTrialConsumption(filmID: UUID) throws {
        try database.finishTrialConsumption(filmID: filmID)
    }
}
