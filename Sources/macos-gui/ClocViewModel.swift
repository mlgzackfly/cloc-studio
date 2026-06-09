import AppKit
import Foundation

@MainActor
final class ClocViewModel: ObservableObject {
    @Published var targetPaths: [String] = []
    @Published var resolvedClocPath: String = "Resolving..."
    @Published var options = ClocOptions()
    @Published var isRunning = false
    @Published var lastCommand = ""
    @Published var statusMessage = "Ready"
    @Published var errorDetails = ""
    @Published var result = ClocResult(
        mode: .language,
        summary: ClocSummary(files: 0, blank: 0, comment: 0, code: 0, elapsedSeconds: nil),
        rows: []
    )

    var summary: ClocSummary? {
        result.rows.isEmpty ? nil : result.summary
    }

    var rows: [ClocRow] {
        result.rows
    }

    var mode: ClocResultMode {
        result.mode
    }

    private let runner = ClocProcessRunner()
    private var runTask: Task<Void, Never>?

    init() {
        resolvedClocPath = ClocExecutableResolver.resolve()?.path ?? "Not found"
    }

    func chooseTargets() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Select"
        if panel.runModal() == .OK {
            setTargets(paths: panel.urls.map(\.path))
        }
    }

    func setTargets(paths: [String]) {
        targetPaths = PathNormalizer.uniqueNormalized(paths)
    }

    func removeTarget(path: String) {
        targetPaths.removeAll { $0 == path }
    }

    func clearTargets() {
        targetPaths = []
    }

    func run() {
        guard !isRunning else { return }
        runTask = Task { [weak self] in
            await self?.runCloc()
        }
    }

    func cancel() {
        runner.cancel()
        runTask?.cancel()
    }

    func copyBreakdownAsWordTable() {
        copyWordTableToPasteboard(
            plainText: BreakdownFormatter.tsv(rows: rows, mode: mode),
            html: BreakdownFormatter.htmlTable(rows: rows, mode: mode)
        )
        statusMessage = "Copied Word table format to clipboard"
    }

    func copyBreakdownAsText() {
        copyToPasteboard(BreakdownFormatter.plainText(rows: rows, mode: mode))
        statusMessage = "Copied text format to clipboard"
    }

    func copyBreakdownAsMarkdown() {
        copyToPasteboard(BreakdownFormatter.markdownTable(rows: rows, mode: mode))
        statusMessage = "Copied Markdown table to clipboard"
    }

    private func runCloc() async {
        isRunning = true
        statusMessage = "Running..."
        errorDetails = ""
        var archiveTemporaryDirectory: URL?
        result = ClocResult(
            mode: options.byFile ? .file : .language,
            summary: ClocSummary(files: 0, blank: 0, comment: 0, code: 0, elapsedSeconds: nil),
            rows: []
        )

        do {
            guard !targetPaths.isEmpty else {
                throw ClocStudioError.noTargets
            }
            guard let executable = ClocExecutableResolver.resolve() else {
                throw ClocStudioError.executableNotFound
            }
            resolvedClocPath = executable.path

            if options.autoExtractArchives {
                statusMessage = "Extracting archives..."
            }
            let preparedTargets = try ArchiveExtractor.prepareTargets(targetPaths, autoExtract: options.autoExtractArchives)
            archiveTemporaryDirectory = preparedTargets.temporaryDirectory

            var args = try options.buildArguments()
            args.append(contentsOf: preparedTargets.paths)
            lastCommand = ShellCommandFormatter.command(executable: executable.path, arguments: args)

            statusMessage = "Running..."
            let output = try await runner.run(executable: executable, arguments: args)
            do {
                result = try ClocParser.parse(jsonText: output.stdout, mode: options.byFile ? .file : .language)
            } catch {
                throw ClocStudioError.invalidJSON(parseFailureMessage(error: error, stdout: output.stdout, stderr: output.stderr))
            }

            let stderr = output.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            let extractionMessage = archiveExtractionMessage(preparedTargets.extractedArchives)
            if stderr.isEmpty {
                statusMessage = extractionMessage ?? "Completed"
            } else {
                statusMessage = "Completed with stderr output"
                errorDetails = [extractionMessage, stderr].compactMap { $0 }.joined(separator: "\n\n")
            }
        } catch {
            statusMessage = "Failed: \(error.localizedDescription)"
            errorDetails = detailedMessage(for: error)
        }

        if let archiveTemporaryDirectory {
            try? FileManager.default.removeItem(at: archiveTemporaryDirectory)
        }
        isRunning = false
        runTask = nil
    }

    private func archiveExtractionMessage(_ archives: [String]) -> String? {
        guard !archives.isEmpty else { return nil }
        return "Completed after extracting \(archives.count) archive\(archives.count == 1 ? "" : "s")."
    }

    private func detailedMessage(for error: Error) -> String {
        if let localized = error as? LocalizedError {
            return localized.errorDescription ?? String(describing: error)
        }
        return String(describing: error)
    }

    private func parseFailureMessage(error: Error, stdout: String, stderr: String) -> String {
        var parts = ["Failed to parse cloc JSON output: \(error.localizedDescription)"]
        let stdoutPreview = outputPreview(stdout)
        let stderrPreview = outputPreview(stderr)
        if !stdoutPreview.isEmpty {
            parts.append("stdout preview:\n\(stdoutPreview)")
        }
        if !stderrPreview.isEmpty {
            parts.append("stderr preview:\n\(stderrPreview)")
        }
        if stdoutPreview.isEmpty && stderrPreview.isEmpty {
            parts.append("cloc produced no output.")
        }
        return parts.joined(separator: "\n\n")
    }

    private func outputPreview(_ text: String, limit: Int = 2000) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if trimmed.count <= limit {
            return trimmed
        }
        return "\(trimmed.prefix(limit))\n... truncated ..."
    }

    private func copyToPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func copyWordTableToPasteboard(plainText: String, html: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(plainText, forType: .string)
        pasteboard.setString(html, forType: .html)
    }
}
