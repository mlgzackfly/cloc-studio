import AppKit
import Foundation

@MainActor
final class ClocViewModel: ObservableObject {
    @Published var targetPaths: [String] = []
    @Published var resolvedClocPath: String = AppStrings(language: .english).resolving
    @Published var options = ClocOptions()
    @Published var isRunning = false
    @Published var lastCommand = ""
    @Published var statusMessage = AppStrings(language: .english).ready
    @Published var errorDetails = ""
    @Published var language: AppLanguage = .english {
        didSet {
            if oldValue != language, statusMessage == AppStrings(language: oldValue).ready {
                statusMessage = strings.ready
            }
        }
    }
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
    private var strings: AppStrings { AppStrings(language: language) }

    init() {
        resolvedClocPath = ClocExecutableResolver.resolve()?.path ?? strings.notFound
    }

    func chooseTargets() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = strings.select
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
        statusMessage = strings.copiedWordTable
    }

    func copyBreakdownAsText() {
        copyToPasteboard(BreakdownFormatter.plainText(rows: rows, mode: mode))
        statusMessage = strings.copiedText
    }

    func copyBreakdownAsMarkdown() {
        copyToPasteboard(BreakdownFormatter.markdownTable(rows: rows, mode: mode))
        statusMessage = strings.copiedMarkdown
    }

    private func runCloc() async {
        isRunning = true
        statusMessage = strings.running
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
                statusMessage = strings.extractingArchives
            }
            let preparedTargets = try ArchiveExtractor.prepareTargets(targetPaths, autoExtract: options.autoExtractArchives)
            archiveTemporaryDirectory = preparedTargets.temporaryDirectory

            var args = try options.buildArguments()
            args.append(contentsOf: preparedTargets.paths)
            lastCommand = ShellCommandFormatter.command(executable: executable.path, arguments: args)

            statusMessage = strings.running
            let output = try await runner.run(executable: executable, arguments: args)
            do {
                result = try ClocParser.parse(jsonText: output.stdout, mode: options.byFile ? .file : .language)
            } catch {
                throw ClocStudioError.invalidJSON(parseFailureMessage(error: error, stdout: output.stdout, stderr: output.stderr))
            }

            let stderr = output.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            let extractionMessage = archiveExtractionMessage(preparedTargets.extractedArchives)
            if stderr.isEmpty {
                statusMessage = extractionMessage ?? strings.completed
            } else {
                statusMessage = strings.completedWithStderr
                errorDetails = [extractionMessage, stderr].compactMap { $0 }.joined(separator: "\n\n")
            }
        } catch {
            statusMessage = strings.failed(localizedMessage(for: error))
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
        return strings.completedAfterExtracting(archives.count)
    }

    private func detailedMessage(for error: Error) -> String {
        localizedMessage(for: error)
    }

    private func localizedMessage(for error: Error) -> String {
        if let studioError = error as? ClocStudioError {
            return localizedMessage(for: studioError)
        }
        if let localized = error as? LocalizedError {
            return localized.errorDescription ?? String(describing: error)
        }
        return String(describing: error)
    }

    private func localizedMessage(for error: ClocStudioError) -> String {
        switch error {
        case .noTargets:
            return language == .traditionalChinese ? "請至少選取或拖入一個檔案或資料夾。" : error.localizedDescription
        case .executableNotFound:
            return language == .traditionalChinese ? "找不到 cloc 執行檔。請將它打包到 App resources，或安裝到 /opt/homebrew/bin 或 /usr/local/bin。" : error.localizedDescription
        case .invalidOption(let message), .invalidJSON(let message), .unexpectedJSON(let message):
            return message
        case .processFailed(let status, let stderr):
            let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
            return language == .traditionalChinese ? "cloc 結束，狀態碼 \(status)。" : error.localizedDescription
        case .timedOut(let seconds):
            return language == .traditionalChinese ? "cloc 在 \(Int(seconds)) 秒後逾時。" : error.localizedDescription
        case .cancelled:
            return language == .traditionalChinese ? "執行已取消。" : error.localizedDescription
        case .archiveExtractionFailed(let path, let message):
            return language == .traditionalChinese ? "解壓縮 \(path) 失敗：\(message)" : error.localizedDescription
        }
    }

    private func parseFailureMessage(error: Error, stdout: String, stderr: String) -> String {
        var parts = [strings.parseFailure(localizedMessage(for: error))]
        let stdoutPreview = outputPreview(stdout)
        let stderrPreview = outputPreview(stderr)
        if !stdoutPreview.isEmpty {
            parts.append(strings.stdoutPreview(stdoutPreview))
        }
        if !stderrPreview.isEmpty {
            parts.append(strings.stderrPreview(stderrPreview))
        }
        if stdoutPreview.isEmpty && stderrPreview.isEmpty {
            parts.append(strings.clocProducedNoOutput)
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
