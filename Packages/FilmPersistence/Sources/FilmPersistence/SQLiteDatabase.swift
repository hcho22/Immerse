import Foundation
import SQLite3

enum SQLiteError: Error, Equatable {
    case openFailed(String)
    case executeFailed(String)
    case prepareFailed(String)
    case stepFailed(String)
    case bindFailed(String)
}

final class SQLiteDatabase {
    private var handle: OpaquePointer?

    init(url: URL) throws {
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(url.path, &handle, flags, nil) != SQLITE_OK {
            throw SQLiteError.openFailed(lastMessage)
        }
        sqlite3_busy_timeout(handle, 5_000)
        try execute("PRAGMA journal_mode = WAL;")
        try execute("PRAGMA foreign_keys = ON;")
        try execute("PRAGMA synchronous = FULL;")
    }

    deinit {
        sqlite3_close(handle)
    }

    func execute(_ sql: String) throws {
        var errorMessage: UnsafeMutablePointer<CChar>?
        let status = sqlite3_exec(handle, sql, nil, nil, &errorMessage)
        if status != SQLITE_OK {
            let message = errorMessage.map { String(cString: $0) } ?? lastMessage
            sqlite3_free(errorMessage)
            throw SQLiteError.executeFailed(message)
        }
    }

    func withTransaction<T>(_ operation: () throws -> T) throws -> T {
        try execute("BEGIN IMMEDIATE;")
        do {
            let result = try operation()
            try execute("COMMIT;")
            return result
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }
    }

    func upsertFilm(id: String, data: Data) throws {
        try withStatement(
            """
            INSERT INTO films (id, data, updated_at)
            VALUES (?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET data = excluded.data, updated_at = excluded.updated_at;
            """
        ) { statement in
            try bindText(id, to: statement, index: 1)
            try bindBlob(data, to: statement, index: 2)
            try bindDouble(Date().timeIntervalSince1970, to: statement, index: 3)
            try stepDone(statement)
        }
    }

    func filmData(id: String) throws -> Data? {
        try withStatement("SELECT data FROM films WHERE id = ?;") { statement in
            try bindText(id, to: statement, index: 1)
            let status = sqlite3_step(statement)
            if status == SQLITE_ROW {
                let bytes = sqlite3_column_blob(statement, 0)
                let count = Int(sqlite3_column_bytes(statement, 0))
                return Data(bytes: bytes!, count: count)
            }
            if status == SQLITE_DONE {
                return nil
            }
            throw SQLiteError.stepFailed(lastMessage)
        }
    }

    func upsertAsset(_ asset: StoredAsset) throws {
        try withStatement(
            """
            INSERT INTO assets (film_id, sequence, kind, relative_path, sha256)
            VALUES (?, ?, ?, ?, ?)
            ON CONFLICT(film_id, sequence, kind)
            DO UPDATE SET relative_path = excluded.relative_path, sha256 = excluded.sha256;
            """
        ) { statement in
            try bindText(asset.filmID.uuidString, to: statement, index: 1)
            try bindInt(asset.sequenceNumber, to: statement, index: 2)
            try bindText(asset.kind.rawValue, to: statement, index: 3)
            try bindText(asset.relativePath, to: statement, index: 4)
            try bindText(asset.sha256, to: statement, index: 5)
            try stepDone(statement)
        }
    }

    func insertReceipt(_ receipt: CaptureCommitReceipt, data: Data) throws {
        try withStatement("INSERT INTO capture_receipts (film_id, capture_id, data) VALUES (?, ?, ?);") { statement in
            try bindText(receipt.filmID.uuidString, to: statement, index: 1)
            try bindText(receipt.captureID, to: statement, index: 2)
            try bindBlob(data, to: statement, index: 3)
            try stepDone(statement)
        }
    }

    func receiptData(filmID: UUID, captureID: String) throws -> Data? {
        try withStatement("SELECT data FROM capture_receipts WHERE film_id = ? AND capture_id = ?;") { statement in
            try bindText(filmID.uuidString, to: statement, index: 1)
            try bindText(captureID, to: statement, index: 2)
            let status = sqlite3_step(statement)
            if status == SQLITE_DONE { return nil }
            guard status == SQLITE_ROW else { throw SQLiteError.stepFailed(lastMessage) }
            return Data(bytes: sqlite3_column_blob(statement, 0)!, count: Int(sqlite3_column_bytes(statement, 0)))
        }
    }

    func asset(filmID: UUID, sequenceNumber: Int, kind: StoredAsset.Kind) throws -> StoredAsset? {
        try withStatement(
            """
            SELECT relative_path, sha256 FROM assets
            WHERE film_id = ? AND sequence = ? AND kind = ?;
            """
        ) { statement in
            try bindText(filmID.uuidString, to: statement, index: 1)
            try bindInt(sequenceNumber, to: statement, index: 2)
            try bindText(kind.rawValue, to: statement, index: 3)
            let status = sqlite3_step(statement)
            if status == SQLITE_ROW {
                return StoredAsset(
                    filmID: filmID,
                    sequenceNumber: sequenceNumber,
                    kind: kind,
                    relativePath: String(cString: sqlite3_column_text(statement, 0)),
                    sha256: String(cString: sqlite3_column_text(statement, 1))
                )
            }
            if status == SQLITE_DONE {
                return nil
            }
            throw SQLiteError.stepFailed(lastMessage)
        }
    }

    func deleteAsset(filmID: UUID, sequenceNumber: Int, kind: StoredAsset.Kind) throws {
        try withStatement(
            "DELETE FROM assets WHERE film_id = ? AND sequence = ? AND kind = ?;"
        ) { statement in
            try bindText(filmID.uuidString, to: statement, index: 1)
            try bindInt(sequenceNumber, to: statement, index: 2)
            try bindText(kind.rawValue, to: statement, index: 3)
            try stepDone(statement)
        }
    }

    func deleteFilm(id: UUID) throws {
        try withStatement("DELETE FROM films WHERE id = ?;") { statement in
            try bindText(id.uuidString, to: statement, index: 1)
            try stepDone(statement)
        }
    }

    func value(filmID: UUID, key: String) throws -> Data? {
        try withStatement("SELECT data FROM film_values WHERE film_id = ? AND key = ?;") { statement in
            try bindText(filmID.uuidString, to: statement, index: 1)
            try bindText(key, to: statement, index: 2)
            let status = sqlite3_step(statement)
            if status == SQLITE_DONE { return nil }
            guard status == SQLITE_ROW else { throw SQLiteError.stepFailed(lastMessage) }
            return Data(bytes: sqlite3_column_blob(statement, 0)!, count: Int(sqlite3_column_bytes(statement, 0)))
        }
    }

    func deleteValue(filmID: UUID, key: String) throws {
        try withStatement("DELETE FROM film_values WHERE film_id = ? AND key = ?;") { statement in
            try bindText(filmID.uuidString, to: statement, index: 1)
            try bindText(key, to: statement, index: 2)
            try stepDone(statement)
        }
    }

    func allFilmData() throws -> [Data] {
        try withStatement("SELECT data FROM films ORDER BY updated_at DESC;") { statement in
            var result: [Data] = []
            while true {
                let status = sqlite3_step(statement)
                if status == SQLITE_DONE { return result }
                guard status == SQLITE_ROW else { throw SQLiteError.stepFailed(lastMessage) }
                result.append(Data(bytes: sqlite3_column_blob(statement, 0)!, count: Int(sqlite3_column_bytes(statement, 0))))
            }
        }
    }

    func setValue(filmID: UUID, key: String, data: Data) throws {
        try withStatement("""
            INSERT INTO film_values (film_id, key, data) VALUES (?, ?, ?)
            ON CONFLICT(film_id, key) DO UPDATE SET data = excluded.data;
            """) { statement in
            try bindText(filmID.uuidString, to: statement, index: 1)
            try bindText(key, to: statement, index: 2)
            try bindBlob(data, to: statement, index: 3)
            try stepDone(statement)
        }
    }

    func enqueueDeletion(filmID: UUID, relativePath: String) throws {
        try withStatement("INSERT OR IGNORE INTO pending_deletions (film_id, relative_path) VALUES (?, ?);") { statement in
            try bindText(filmID.uuidString, to: statement, index: 1)
            try bindText(relativePath, to: statement, index: 2)
            try stepDone(statement)
        }
    }

    func pendingDeletionPaths(filmID: UUID? = nil) throws -> [String] {
        let sql = filmID == nil
            ? "SELECT relative_path FROM pending_deletions ORDER BY relative_path;"
            : "SELECT relative_path FROM pending_deletions WHERE film_id = ? ORDER BY relative_path;"
        return try withStatement(sql) { statement in
            if let filmID { try bindText(filmID.uuidString, to: statement, index: 1) }
            var paths: [String] = []
            while true {
                let status = sqlite3_step(statement)
                if status == SQLITE_DONE { return paths }
                guard status == SQLITE_ROW else { throw SQLiteError.stepFailed(lastMessage) }
                paths.append(String(cString: sqlite3_column_text(statement, 0)))
            }
        }
    }

    func finishDeletion(relativePath: String) throws {
        try withStatement("DELETE FROM pending_deletions WHERE relative_path = ?;") { statement in
            try bindText(relativePath, to: statement, index: 1)
            try stepDone(statement)
        }
    }

    func assets(filmID: UUID? = nil) throws -> [StoredAsset] {
        let sql: String
        if filmID == nil {
            sql = "SELECT film_id, sequence, kind, relative_path, sha256 FROM assets;"
        } else {
            sql = "SELECT film_id, sequence, kind, relative_path, sha256 FROM assets WHERE film_id = ?;"
        }

        return try withStatement(sql) { statement in
            if let filmID {
                try bindText(filmID.uuidString, to: statement, index: 1)
            }
            var result: [StoredAsset] = []
            while true {
                let status = sqlite3_step(statement)
                if status == SQLITE_DONE {
                    return result
                }
                guard status == SQLITE_ROW,
                      let id = UUID(uuidString: String(cString: sqlite3_column_text(statement, 0))),
                      let kind = StoredAsset.Kind(rawValue: String(cString: sqlite3_column_text(statement, 2))) else {
                    throw SQLiteError.stepFailed(lastMessage)
                }
                result.append(
                    StoredAsset(
                        filmID: id,
                        sequenceNumber: Int(sqlite3_column_int(statement, 1)),
                        kind: kind,
                        relativePath: String(cString: sqlite3_column_text(statement, 3)),
                        sha256: String(cString: sqlite3_column_text(statement, 4))
                    )
                )
            }
        }
    }

    private func withStatement<T>(_ sql: String, _ operation: (OpaquePointer) throws -> T) throws -> T {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw SQLiteError.prepareFailed(lastMessage)
        }
        defer { sqlite3_finalize(statement) }
        return try operation(statement)
    }

    private func bindText(_ value: String, to statement: OpaquePointer, index: Int32) throws {
        if sqlite3_bind_text(statement, index, value, -1, SQLITE_TRANSIENT) != SQLITE_OK {
            throw SQLiteError.bindFailed(lastMessage)
        }
    }

    private func bindBlob(_ value: Data, to statement: OpaquePointer, index: Int32) throws {
        let status = value.withUnsafeBytes { buffer in
            sqlite3_bind_blob(statement, index, buffer.baseAddress, Int32(value.count), SQLITE_TRANSIENT)
        }
        if status != SQLITE_OK {
            throw SQLiteError.bindFailed(lastMessage)
        }
    }

    private func bindDouble(_ value: Double, to statement: OpaquePointer, index: Int32) throws {
        if sqlite3_bind_double(statement, index, value) != SQLITE_OK {
            throw SQLiteError.bindFailed(lastMessage)
        }
    }

    private func bindInt(_ value: Int, to statement: OpaquePointer, index: Int32) throws {
        if sqlite3_bind_int(statement, index, Int32(value)) != SQLITE_OK {
            throw SQLiteError.bindFailed(lastMessage)
        }
    }

    private func stepDone(_ statement: OpaquePointer) throws {
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteError.stepFailed(lastMessage)
        }
    }

    private var lastMessage: String {
        String(cString: sqlite3_errmsg(handle))
    }
}

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
