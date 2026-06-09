import Foundation

enum ClocResultMode: Equatable {
    case language
    case file

    var rowTitle: String {
        switch self {
        case .language: return "Language"
        case .file: return "File"
        }
    }

    var breakdownTitle: String {
        switch self {
        case .language: return "Language Breakdown"
        case .file: return "File Breakdown"
        }
    }
}

struct ClocSummary: Equatable {
    let files: Int
    let blank: Int
    let comment: Int
    let code: Int
    let elapsedSeconds: Double?
}

struct ClocRow: Identifiable, Equatable {
    let id: String
    let name: String
    let files: Int
    let blank: Int
    let comment: Int
    let code: Int

    init(name: String, files: Int, blank: Int, comment: Int, code: Int) {
        self.id = name
        self.name = name
        self.files = files
        self.blank = blank
        self.comment = comment
        self.code = code
    }
}

struct ClocResult: Equatable {
    let mode: ClocResultMode
    let summary: ClocSummary
    let rows: [ClocRow]
}

enum ClocStudioError: LocalizedError, Equatable {
    case noTargets
    case executableNotFound
    case invalidOption(String)
    case invalidJSON
    case unexpectedJSON
    case processFailed(status: Int32, stderr: String)
    case timedOut(seconds: TimeInterval)
    case cancelled
    case archiveExtractionFailed(path: String, message: String)

    var errorDescription: String? {
        switch self {
        case .noTargets:
            return "Please select or drop at least one file/folder."
        case .executableNotFound:
            return "cloc executable not found. Bundle it in app resources or install it in /opt/homebrew/bin or /usr/local/bin."
        case .invalidOption(let message):
            return message
        case .invalidJSON:
            return "Failed to decode JSON output as UTF-8."
        case .unexpectedJSON:
            return "Unexpected JSON structure from cloc."
        case .processFailed(let status, let stderr):
            let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "cloc exited with status \(status)." : trimmed
        case .timedOut(let seconds):
            return "cloc timed out after \(Int(seconds)) seconds."
        case .cancelled:
            return "Run cancelled."
        case .archiveExtractionFailed(let path, let message):
            return "Failed to extract \(path): \(message)"
        }
    }
}
