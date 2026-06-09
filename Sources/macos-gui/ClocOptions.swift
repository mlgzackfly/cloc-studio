import Foundation

struct ClocOptions: Equatable {
    var useVCSGit = true
    var byFile = false
    var excludeDirs = ""
    var includeLangs = ""
    var excludeLangs = ""
    var includeExts = ""
    var excludeExts = ""
    var maxFileSizeMB = ""
    var skipUniqueness = false
    var autoExtractArchives = false

    func buildArguments() throws -> [String] {
        var args = ["--json", "--hide-rate"]
        if useVCSGit { args.append("--vcs=git") }
        if byFile { args.append("--by-file") }
        if skipUniqueness { args.append("--skip-uniqueness") }

        appendListArg("--exclude-dir", value: excludeDirs, to: &args)
        appendListArg("--include-lang", value: includeLangs, to: &args)
        appendListArg("--exclude-lang", value: excludeLangs, to: &args)
        appendListArg("--include-ext", value: includeExts, to: &args)
        appendListArg("--exclude-ext", value: excludeExts, to: &args)

        let maxSize = maxFileSizeMB.trimmingCharacters(in: .whitespacesAndNewlines)
        if !maxSize.isEmpty {
            guard let value = Double(maxSize), value > 0 else {
                throw ClocStudioError.invalidOption("Max MB must be a positive number.")
            }
            args.append("--max-file-size=\(maxSize)")
        }

        return args
    }

    private func appendListArg(_ flag: String, value: String, to args: inout [String]) {
        let normalized = value
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ",")

        guard !normalized.isEmpty else { return }
        args.append("\(flag)=\(normalized)")
    }
}

enum PathNormalizer {
    static func normalize(_ rawPath: String, currentDirectory: String = FileManager.default.currentDirectoryPath) -> String {
        let path = NSString(string: rawPath).expandingTildeInPath
        if path.hasPrefix("/") {
            return path
        }
        return URL(fileURLWithPath: currentDirectory).appendingPathComponent(path).path
    }

    static func uniqueNormalized(_ paths: [String], currentDirectory: String = FileManager.default.currentDirectoryPath) -> [String] {
        var unique: [String] = []
        var seen = Set<String>()
        for rawPath in paths {
            let path = normalize(rawPath, currentDirectory: currentDirectory)
            if seen.insert(path).inserted {
                unique.append(path)
            }
        }
        return unique
    }
}

enum ShellCommandFormatter {
    static func command(executable: String, arguments: [String]) -> String {
        ([executable] + arguments).map(shellQuote).joined(separator: " ")
    }

    static func shellQuote(_ part: String) -> String {
        let safeCharacters = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_+-./=,:")
        if !part.isEmpty, part.unicodeScalars.allSatisfy({ safeCharacters.contains($0) }) {
            return part
        }
        return "'\(part.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
