import Foundation
import Testing
@testable import macos_gui

struct ClocCoreTests {
    @Test
    func buildsArgumentsWithNormalizedListsAndValidatedMaxSize() throws {
        let options = ClocOptions(
            useVCSGit: true,
            byFile: true,
            excludeDirs: " .git, node_modules ,, dist ",
            includeLangs: " Swift, Objective-C ",
            excludeLangs: "",
            includeExts: " swift, m ",
            excludeExts: " map ",
            maxFileSizeMB: "20",
            skipUniqueness: true
        )

        #expect(try options.buildArguments() == [
            "--json",
            "--vcs=git",
            "--by-file",
            "--skip-uniqueness",
            "--exclude-dir=.git,node_modules,dist",
            "--include-lang=Swift,Objective-C",
            "--include-ext=swift,m",
            "--exclude-ext=map",
            "--max-file-size=20",
        ])
    }

    @Test
    func rejectsInvalidMaxSize() {
        let options = ClocOptions(maxFileSizeMB: "large")

        #expect(throws: ClocStudioError.invalidOption("Max MB must be a positive number.")) {
            try options.buildArguments()
        }
    }

    @Test
    func parsesLanguageJsonSortedByCode() throws {
        let json = """
        {
          "header": { "elapsed_seconds": 0.12 },
          "Swift": { "nFiles": 2, "blank": 3, "comment": 4, "code": 50 },
          "Markdown": { "nFiles": 1, "blank": 1, "comment": 0, "code": 10 },
          "SUM": { "nFiles": 3, "blank": 4, "comment": 4, "code": 60 }
        }
        """

        let result = try ClocParser.parse(jsonText: json, mode: .language)

        #expect(result.mode == .language)
        #expect(result.summary == ClocSummary(files: 3, blank: 4, comment: 4, code: 60, elapsedSeconds: 0.12))
        #expect(result.rows.map(\.name) == ["Swift", "Markdown"])
        #expect(result.rows.first?.code == 50)
    }

    @Test
    func parsesByFileJsonWithFileFallback() throws {
        let json = """
        {
          "Sources/App.swift": { "language": "Swift", "blank": 3, "comment": 1, "code": 40 },
          "SUM": { "nFiles": 1, "blank": 3, "comment": 1, "code": 40 }
        }
        """

        let result = try ClocParser.parse(jsonText: json, mode: .file)

        #expect(result.mode == .file)
        #expect(result.rows == [
            ClocRow(name: "Sources/App.swift", files: 1, blank: 3, comment: 1, code: 40),
        ])
    }

    @Test
    func formatterEscapesMarkdownAndHTML() {
        let rows = [
            ClocRow(name: "A|B `C` <tag> \"quote\"", files: 1, blank: 0, comment: 0, code: 2),
        ]

        let markdown = BreakdownFormatter.markdownTable(rows: rows, mode: .language)
        let html = BreakdownFormatter.htmlTable(rows: rows, mode: .language)

        #expect(markdown.contains("A\\|B \\`C\\` <tag> \"quote\""))
        #expect(html.contains("A|B `C` &lt;tag&gt; &quot;quote&quot;"))
    }

    @Test
    func normalizesAndDeduplicatesPaths() {
        let paths = PathNormalizer.uniqueNormalized(["src", "/tmp/project/src", "src"], currentDirectory: "/tmp/project")
        #expect(paths == ["/tmp/project/src"])
    }

    @Test
    func detectsSupportedArchiveSuffixes() {
        #expect(ArchiveExtractor.isSupportedArchive(path: "/tmp/source.zip"))
        #expect(ArchiveExtractor.isSupportedArchive(path: "/tmp/source.tar.gz"))
        #expect(ArchiveExtractor.isSupportedArchive(path: "/tmp/source.TBZ2"))
        #expect(!ArchiveExtractor.isSupportedArchive(path: "/tmp/source.swift"))
    }

    @Test
    func leavesTargetsUnchangedWhenAutoExtractIsOff() throws {
        let result = try ArchiveExtractor.prepareTargets(["/tmp/src", "/tmp/source.zip"], autoExtract: false)
        #expect(result.paths == [
            "/tmp/src",
            "/tmp/source.zip",
        ])
        #expect(result.extractedArchives.isEmpty)
        #expect(result.temporaryDirectory == nil)
    }

    @Test
    func extractsNestedZipArchives() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("cloc-studio-test-\(UUID().uuidString)", isDirectory: true)
        let innerSource = root.appendingPathComponent("inner-source", isDirectory: true)
        let outerSource = root.appendingPathComponent("outer-source", isDirectory: true)
        try FileManager.default.createDirectory(at: innerSource, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outerSource, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let swiftFile = innerSource.appendingPathComponent("hello.swift")
        try "print(\"hello\")\n".write(to: swiftFile, atomically: true, encoding: .utf8)

        let innerZip = outerSource.appendingPathComponent("inner.zip")
        try runZip(arguments: ["-qr", innerZip.path, "."], currentDirectory: innerSource)

        let outerZip = root.appendingPathComponent("outer.zip")
        try runZip(arguments: ["-qr", outerZip.path, "."], currentDirectory: outerSource)

        let result = try ArchiveExtractor.prepareTargets([outerZip.path], autoExtract: true)
        defer {
            if let temporaryDirectory = result.temporaryDirectory {
                try? FileManager.default.removeItem(at: temporaryDirectory)
            }
        }

        #expect(result.paths.count == 1)
        #expect(result.extractedArchives.count == 2)
        let extractedRoot = URL(fileURLWithPath: result.paths[0])
        let extractedFiles = try allFiles(in: extractedRoot).map(\.lastPathComponent)
        #expect(extractedFiles.contains("hello.swift"))
    }

    @Test
    func shellCommandQuotesUnsafeParts() {
        let command = ShellCommandFormatter.command(executable: "/tmp/cloc", arguments: ["--json", "/tmp/a project/it's"])
        #expect(command == "/tmp/cloc --json '/tmp/a project/it'\\''s'")
    }

    private func runZip(arguments: [String], currentDirectory: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectory
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
    }

    private func allFiles(in root: URL) throws -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey]
        ) else {
            return []
        }

        var files: [URL] = []
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            if values.isRegularFile == true {
                files.append(url)
            }
        }
        return files
    }
}
