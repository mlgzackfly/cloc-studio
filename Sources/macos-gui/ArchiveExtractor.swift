import Foundation

struct ArchiveExtractionResult: Equatable {
    let paths: [String]
    let extractedArchives: [String]
    let temporaryDirectory: URL?
}

enum ArchiveExtractor {
    private static let supportedArchiveSuffixes = [
        ".zip",
        ".tar",
        ".tgz",
        ".tar.gz",
        ".tbz",
        ".tbz2",
        ".tar.bz2",
        ".txz",
        ".tar.xz",
    ]

    static func isSupportedArchive(path: String) -> Bool {
        let lowercased = path.lowercased()
        return supportedArchiveSuffixes.contains { lowercased.hasSuffix($0) }
    }

    static func prepareTargets(_ paths: [String], autoExtract: Bool) throws -> ArchiveExtractionResult {
        let normalizedPaths = paths.map { PathNormalizer.normalize($0) }
        guard autoExtract else {
            return ArchiveExtractionResult(paths: normalizedPaths, extractedArchives: [], temporaryDirectory: nil)
        }

        let archivePaths = normalizedPaths.filter(isSupportedArchive)
        guard !archivePaths.isEmpty else {
            return ArchiveExtractionResult(paths: normalizedPaths, extractedArchives: [], temporaryDirectory: nil)
        }

        let tempRoot = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("cloc-studio-archives-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)

        do {
            var preparedPaths: [String] = []
            var extractedArchives: [String] = []
            var visitedArchives = Set<String>()

            for path in normalizedPaths {
                guard isSupportedArchive(path: path) else {
                    preparedPaths.append(path)
                    continue
                }

                let archiveURL = URL(fileURLWithPath: path)
                let destination = tempRoot.appendingPathComponent(sanitizedDirectoryName(for: archiveURL), isDirectory: true)
                try extractArchive(at: archiveURL, to: destination)
                extractedArchives.append(path)
                visitedArchives.insert(path)
                try extractNestedArchives(in: destination, extractedArchives: &extractedArchives, visitedArchives: &visitedArchives)
                preparedPaths.append(destination.path)
            }

            return ArchiveExtractionResult(
                paths: PathNormalizer.uniqueNormalized(preparedPaths),
                extractedArchives: extractedArchives,
                temporaryDirectory: tempRoot
            )
        } catch {
            try? FileManager.default.removeItem(at: tempRoot)
            throw error
        }
    }

    private static func extractNestedArchives(in root: URL, extractedArchives: inout [String], visitedArchives: inout Set<String>) throws {
        while true {
            let archives = try archiveFiles(in: root)
            var extractedSomething = false

            for archive in archives {
                guard !visitedArchives.contains(archive.path) else { continue }
                let destination = archive
                    .deletingLastPathComponent()
                    .appendingPathComponent("__cloc_studio_extracted__")
                    .appendingPathComponent(sanitizedDirectoryName(for: archive), isDirectory: true)

                try extractArchive(at: archive, to: destination)
                visitedArchives.insert(archive.path)
                extractedArchives.append(archive.path)
                extractedSomething = true
            }

            if !extractedSomething { break }
        }
    }

    private static func archiveFiles(in root: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var archives: [URL] = []
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            if values.isRegularFile == true, isSupportedArchive(path: url.path) {
                archives.append(url)
            }
        }
        return archives
    }

    private static func extractArchive(at archive: URL, to destination: URL) throws {
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        if archive.path.lowercased().hasSuffix(".zip") {
            try runExtractionTool(
                executable: "/usr/bin/ditto",
                arguments: ["-x", "-k", archive.path, destination.path],
                archivePath: archive.path
            )
        } else {
            try runExtractionTool(
                executable: "/usr/bin/tar",
                arguments: ["-xf", archive.path, "-C", destination.path],
                archivePath: archive.path
            )
        }
    }

    private static func runExtractionTool(executable: String, arguments: [String], archivePath: String) throws {
        let process = Process()
        let stderrPipe = Pipe()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardError = stderrPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw ClocStudioError.archiveExtractionFailed(path: archivePath, message: error.localizedDescription)
        }

        guard process.terminationStatus == 0 else {
            let data = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let stderr = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            throw ClocStudioError.archiveExtractionFailed(
                path: archivePath,
                message: stderr.isEmpty ? "extractor exited with status \(process.terminationStatus)" : stderr
            )
        }
    }

    private static func sanitizedDirectoryName(for url: URL) -> String {
        let name = url.lastPathComponent
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return "\(name)-\(UUID().uuidString)"
    }
}
