import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

final class DroppedPathAccumulator: @unchecked Sendable {
    private var items: [String] = []
    private let lock = NSLock()

    func append(_ path: String) {
        lock.lock()
        items.append(path)
        lock.unlock()
    }

    func snapshot() -> [String] {
        lock.lock()
        let copy = items
        lock.unlock()
        return copy
    }
}

struct ClocSummary {
    let files: Int
    let blank: Int
    let comment: Int
    let code: Int
    let elapsedSeconds: Double?
}

struct LanguageRow: Identifiable {
    let id = UUID()
    let name: String
    let files: Int
    let blank: Int
    let comment: Int
    let code: Int
}

@MainActor
final class ClocViewModel: ObservableObject {
    @Published var targetPaths: [String]
    @Published var resolvedClocPath: String = "Resolving..."
    @Published var useVCSGit: Bool = false
    @Published var byFile: Bool = false
    @Published var excludeDirs: String = ""
    @Published var includeLangs: String = ""
    @Published var excludeLangs: String = ""
    @Published var includeExts: String = ""
    @Published var excludeExts: String = ""
    @Published var maxFileSizeMB: String = ""
    @Published var skipUniqueness: Bool = false

    @Published var isRunning: Bool = false
    @Published var lastCommand: String = ""
    @Published var statusMessage: String = "Ready"
    @Published var summary: ClocSummary?
    @Published var rows: [LanguageRow] = []

    init() {
        self.targetPaths = []
        self.resolvedClocPath = resolveExecutableURL()?.path ?? "Not found"
    }

    func run() {
        Task {
            await runCloc()
        }
    }

    func chooseTargets() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Select"
        if panel.runModal() == .OK {
            let paths = panel.urls.map { $0.path }
            setTargets(paths: paths)
        }
    }

    func setTargets(paths: [String]) {
        var unique: [String] = []
        var seen = Set<String>()
        for rawPath in paths {
            let path = normalizePath(rawPath)
            if seen.insert(path).inserted {
                unique.append(path)
            }
        }
        targetPaths = unique
    }

    func removeTarget(path: String) {
        targetPaths.removeAll { $0 == path }
    }

    func clearTargets() {
        targetPaths = []
    }

    private func normalizePath(_ rawPath: String) -> String {
        let path = NSString(string: rawPath).expandingTildeInPath
        if path.hasPrefix("/") {
            return path
        }
        let cwd = FileManager.default.currentDirectoryPath
        return URL(fileURLWithPath: cwd).appendingPathComponent(path).path
    }

    private func resolveExecutableURL() -> URL? {
        if let bundled = Bundle.main.url(forResource: "cloc", withExtension: nil),
           FileManager.default.isExecutableFile(atPath: bundled.path) {
            return bundled
        }
        if let resourceDir = Bundle.main.resourceURL {
            let resourceCloc = resourceDir.appendingPathComponent("cloc")
            if FileManager.default.isExecutableFile(atPath: resourceCloc.path) {
                return resourceCloc
            }
        }

        let cwd = FileManager.default.currentDirectoryPath
        let candidates = [
            URL(fileURLWithPath: cwd).appendingPathComponent("vendor/cloc").path,
            URL(fileURLWithPath: cwd).appendingPathComponent("../cloc").path,
            URL(fileURLWithPath: cwd).appendingPathComponent("cloc").path,
            "/opt/homebrew/bin/cloc",
            "/usr/local/bin/cloc",
            "/usr/bin/cloc",
        ]
        for candidate in candidates {
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return URL(fileURLWithPath: candidate)
            }
        }
        return nil
    }

    private func runCloc() async {
        isRunning = true
        statusMessage = "Running..."
        summary = nil
        rows = []

        do {
            guard !targetPaths.isEmpty else {
                throw NSError(domain: "ClocGUI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Please select or drop at least one file/folder."])
            }
            guard let executable = resolveExecutableURL() else {
                throw NSError(domain: "ClocGUI", code: 2, userInfo: [NSLocalizedDescriptionKey: "cloc executable not found. Please bundle it in app resources or install it in /opt/homebrew/bin or /usr/local/bin."])
            }
            resolvedClocPath = executable.path

            var args = buildArgs()
            args.append(contentsOf: targetPaths.map(normalizePath))

            lastCommand = ([executable.path] + args).joined(separator: " ")

            let (stdout, stderr) = try await runProcess(executable: executable, arguments: args)
            if !stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                statusMessage = "Completed with stderr output"
            } else {
                statusMessage = "Completed"
            }

            try parse(jsonText: stdout)
        } catch {
            statusMessage = "Failed: \(error.localizedDescription)"
        }

        isRunning = false
    }

    private func runProcess(executable: URL, arguments: [String]) async throws -> (String, String) {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()

            process.executableURL = executable
            process.arguments = arguments
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            process.terminationHandler = { proc in
                let outData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let out = String(decoding: outData, as: UTF8.self)
                let err = String(decoding: errData, as: UTF8.self)

                if proc.terminationStatus == 0 {
                    continuation.resume(returning: (out, err))
                } else {
                    let message = err.isEmpty ? "cloc exited with status \(proc.terminationStatus)" : err
                    continuation.resume(throwing: NSError(domain: "ClocGUI", code: Int(proc.terminationStatus), userInfo: [NSLocalizedDescriptionKey: message]))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func parse(jsonText: String) throws {
        guard let data = jsonText.data(using: .utf8) else {
            throw NSError(domain: "ClocGUI", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to decode JSON output as UTF-8."])
        }

        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "ClocGUI", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unexpected JSON structure from cloc."])
        }

        let header = root["header"] as? [String: Any]
        let sum = root["SUM"] as? [String: Any] ?? [:]
        summary = ClocSummary(
            files: asInt(sum["nFiles"]),
            blank: asInt(sum["blank"]),
            comment: asInt(sum["comment"]),
            code: asInt(sum["code"]),
            elapsedSeconds: asDouble(header?["elapsed_seconds"])
        )

        var parsedRows: [LanguageRow] = []
        for (key, value) in root {
            if key == "header" || key == "SUM" { continue }
            guard let dict = value as? [String: Any] else { continue }
            parsedRows.append(
                LanguageRow(
                    name: key,
                    files: asInt(dict["nFiles"]),
                    blank: asInt(dict["blank"]),
                    comment: asInt(dict["comment"]),
                    code: asInt(dict["code"])
                )
            )
        }

        rows = parsedRows.sorted { lhs, rhs in
            if lhs.code == rhs.code {
                return lhs.name < rhs.name
            }
            return lhs.code > rhs.code
        }
    }

    private func asInt(_ value: Any?) -> Int {
        if let intValue = value as? Int { return intValue }
        if let number = value as? NSNumber { return number.intValue }
        if let stringValue = value as? String, let intValue = Int(stringValue) { return intValue }
        return 0
    }

    private func asDouble(_ value: Any?) -> Double? {
        if let doubleValue = value as? Double { return doubleValue }
        if let number = value as? NSNumber { return number.doubleValue }
        if let stringValue = value as? String, let doubleValue = Double(stringValue) { return doubleValue }
        return nil
    }

    private func buildArgs() -> [String] {
        var args = ["--json"]
        if useVCSGit { args.append("--vcs=git") }
        if byFile { args.append("--by-file") }
        if skipUniqueness { args.append("--skip-uniqueness") }
        appendValueArg("--exclude-dir", value: excludeDirs, to: &args)
        appendValueArg("--include-lang", value: includeLangs, to: &args)
        appendValueArg("--exclude-lang", value: excludeLangs, to: &args)
        appendValueArg("--include-ext", value: includeExts, to: &args)
        appendValueArg("--exclude-ext", value: excludeExts, to: &args)
        appendValueArg("--max-file-size", value: maxFileSizeMB, to: &args)
        return args
    }

    private func appendValueArg(_ flag: String, value: String, to args: inout [String]) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        args.append("\(flag)=\(trimmed)")
    }
}

struct ContentView: View {
    @StateObject private var viewModel = ClocViewModel()
    @State private var isDropTargeted = false

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.width < 980
            let filterColumns = [GridItem(.adaptive(minimum: compact ? 220 : 260), spacing: 10)]

            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.97, green: 0.98, blue: 1.00),
                        Color(red: 0.95, green: 0.98, blue: 0.96),
                        Color(red: 0.95, green: 0.96, blue: 1.00),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                Circle()
                    .fill(Color(red: 0.26, green: 0.66, blue: 0.98).opacity(0.15))
                    .frame(width: 420, height: 420)
                    .offset(x: 330, y: -240)

                Circle()
                    .fill(Color(red: 0.19, green: 0.75, blue: 0.56).opacity(0.13))
                    .frame(width: 360, height: 360)
                    .offset(x: -380, y: 260)

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 10) {
                        Text("Cloc Studio")
                            .font(.system(size: compact ? 30 : 34, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.14, green: 0.18, blue: 0.28))

                        Text("Count source lines with a fast visual wrapper")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(Color(red: 0.28, green: 0.34, blue: 0.45))

                        Label("macOS Prototype", systemImage: "hammer.fill")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.white.opacity(0.85), in: Capsule())
                            .foregroundStyle(Color(red: 0.20, green: 0.29, blue: 0.39))
                    }

                    card {
                        VStack(alignment: .leading, spacing: 11) {
                            Label("Inputs", systemImage: "slider.horizontal.3")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color(red: 0.16, green: 0.23, blue: 0.34))

                            HStack {
                                Text("Targets")
                                    .frame(width: 90, alignment: .leading)
                                    .foregroundStyle(Color(red: 0.24, green: 0.31, blue: 0.41))
                                Text("\(viewModel.targetPaths.count) selected")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color(red: 0.24, green: 0.31, blue: 0.41))
                                Spacer()
                                if !viewModel.targetPaths.isEmpty {
                                    Button("Clear") { viewModel.clearTargets() }
                                        .buttonStyle(.bordered)
                                        .tint(Color(red: 0.95, green: 0.35, blue: 0.35))
                                }
                                Button("Select") { viewModel.chooseTargets() }
                                    .buttonStyle(.bordered)
                                    .tint(Color(red: 0.16, green: 0.57, blue: 0.95))
                            }

                            if viewModel.targetPaths.isEmpty {
                                Text("Drop files/folders below or click Select.")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color(red: 0.40, green: 0.46, blue: 0.56))
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(viewModel.targetPaths, id: \.self) { path in
                                            targetChip(path: path)
                                        }
                                    }
                                }
                            }

                            if compact {
                                VStack(alignment: .leading, spacing: 8) {
                                    Toggle("Use git scope (--vcs=git)", isOn: $viewModel.useVCSGit)
                                    Toggle("Break down by file (--by-file)", isOn: $viewModel.byFile)
                                    Toggle("Skip uniqueness check", isOn: $viewModel.skipUniqueness)
                                }
                            } else {
                                HStack(spacing: 16) {
                                    Toggle("Use git scope (--vcs=git)", isOn: $viewModel.useVCSGit)
                                    Toggle("Break down by file (--by-file)", isOn: $viewModel.byFile)
                                    Toggle("Skip uniqueness check", isOn: $viewModel.skipUniqueness)
                                }
                            }

                            LazyVGrid(columns: filterColumns, spacing: 10) {
                                filterField(title: "Exclude dirs", placeholder: ".git,node_modules,dist", text: $viewModel.excludeDirs)
                                filterField(title: "Include lang", placeholder: "Swift,Objective-C", text: $viewModel.includeLangs)
                                filterField(title: "Exclude lang", placeholder: "Markdown,JSON", text: $viewModel.excludeLangs)
                                filterField(title: "Include ext", placeholder: "swift,m,mm", text: $viewModel.includeExts)
                                filterField(title: "Exclude ext", placeholder: "min.js,map", text: $viewModel.excludeExts)
                                filterField(title: "Max MB", placeholder: "20", text: $viewModel.maxFileSizeMB)
                            }

                            dropZone
                        }
                    }

                    HStack {
                        Button {
                            viewModel.run()
                        } label: {
                            Label(viewModel.isRunning ? "Running..." : "Run cloc", systemImage: "play.fill")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(red: 0.12, green: 0.72, blue: 0.56))
                        .disabled(viewModel.isRunning)

                        Text(viewModel.statusMessage)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(red: 0.22, green: 0.30, blue: 0.40))
                    }

                    if !viewModel.lastCommand.isEmpty {
                        Text("Last command: \(viewModel.lastCommand)")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color(red: 0.35, green: 0.42, blue: 0.52))
                            .lineLimit(2)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }

                        if let summary = viewModel.summary {
                            card {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        statPill(title: "Files", value: "\(summary.files)", color: Color(red: 0.36, green: 0.69, blue: 0.95))
                                        statPill(title: "Code", value: "\(summary.code)", color: Color(red: 0.21, green: 0.78, blue: 0.58))
                                        statPill(title: "Comment", value: "\(summary.comment)", color: Color(red: 0.98, green: 0.68, blue: 0.31))
                                        statPill(title: "Blank", value: "\(summary.blank)", color: Color(red: 0.77, green: 0.58, blue: 0.95))
                                        if let elapsed = summary.elapsedSeconds {
                                            statPill(title: "Elapsed", value: String(format: "%.3fs", elapsed), color: Color(red: 0.96, green: 0.52, blue: 0.45))
                                        }
                                    }
                                }
                            }
                        }

                        card {
                            VStack(alignment: .leading, spacing: 10) {
                                Label("Language Breakdown", systemImage: "chart.bar.xaxis")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color(red: 0.16, green: 0.23, blue: 0.34))

                                breakdownList
                            }
                        }
                    }
                    .padding(16)
                }
            }
        }
        .frame(minWidth: 760, minHeight: 580)
    }

    private var dropZone: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(isDropTargeted ? Color(red: 0.16, green: 0.57, blue: 0.95).opacity(0.16) : .white.opacity(0.72))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isDropTargeted ? Color(red: 0.16, green: 0.57, blue: 0.95) : Color(red: 0.66, green: 0.73, blue: 0.83), style: StrokeStyle(lineWidth: 1.4, dash: [6, 5]))
            )
            .frame(height: 70)
            .overlay(
                HStack(spacing: 8) {
                    Image(systemName: "tray.and.arrow.down.fill")
                    Text("Drop files/folders here to merge and run")
                }
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.22, green: 0.31, blue: 0.41))
            )
            .onDrop(of: [UTType.fileURL.identifier], isTargeted: $isDropTargeted) { providers in
                handleDrop(providers: providers)
            }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        let fileProviders = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !fileProviders.isEmpty else {
            return false
        }

        let group = DispatchGroup()
        let accumulator = DroppedPathAccumulator()

        for provider in fileProviders {
            group.enter()
            provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                defer { group.leave() }
                guard
                    let data,
                    let url = URL(dataRepresentation: data, relativeTo: nil)
                else {
                    return
                }
                accumulator.append(url.path)
            }
        }

        group.notify(queue: .main) {
            let droppedPaths = accumulator.snapshot()
            guard !droppedPaths.isEmpty else { return }
            viewModel.setTargets(paths: droppedPaths)
            if !viewModel.isRunning {
                viewModel.run()
            }
        }
        return true
    }

    private func targetChip(path: String) -> some View {
        HStack(spacing: 6) {
            Text(path)
                .lineLimit(1)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color(red: 0.20, green: 0.29, blue: 0.39))
            Button {
                viewModel.removeTarget(path: path)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12, weight: .bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color(red: 0.88, green: 0.35, blue: 0.35))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.86), in: Capsule())
    }

    private func statPill(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.18, green: 0.24, blue: 0.33))
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Color(red: 0.10, green: 0.16, blue: 0.24))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(color.opacity(0.20), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(12)
            .background(Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.95), lineWidth: 1)
            )
    }

    private func filterField(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.32, green: 0.38, blue: 0.48))
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var breakdownList: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    breakdownHeader("Language", width: 260, align: .leading)
                    breakdownHeader("Files", width: 90)
                    breakdownHeader("Code", width: 90)
                    breakdownHeader("Comment", width: 100)
                    breakdownHeader("Blank", width: 90)
                }
                .background(Color.white.opacity(0.75))

                if viewModel.rows.isEmpty {
                    Text("No results yet")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(Color(red: 0.40, green: 0.46, blue: 0.56))
                        .frame(maxWidth: .infinity, minHeight: 120)
                        .background(Color.white.opacity(0.56))
                } else {
                    ForEach(viewModel.rows) { row in
                        HStack(spacing: 0) {
                            breakdownCell(row.name, width: 260, align: .leading)
                            breakdownCell("\(row.files)", width: 90)
                            breakdownCell("\(row.code)", width: 90)
                            breakdownCell("\(row.comment)", width: 100)
                            breakdownCell("\(row.blank)", width: 90)
                        }
                        .background(Color.white.opacity(0.56))
                        Divider().overlay(Color(red: 0.85, green: 0.89, blue: 0.95))
                    }
                }
            }
            .frame(minWidth: 630)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .frame(minHeight: 220)
    }

    private func breakdownHeader(_ text: String, width: CGFloat, align: Alignment = .center) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(Color(red: 0.22, green: 0.30, blue: 0.40))
            .frame(width: width, height: 34, alignment: align)
            .padding(.horizontal, align == .leading ? 10 : 0)
    }

    private func breakdownCell(_ text: String, width: CGFloat, align: Alignment = .center) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundStyle(Color(red: 0.20, green: 0.29, blue: 0.39))
            .lineLimit(1)
            .truncationMode(.middle)
            .frame(width: width, height: 32, alignment: align)
            .padding(.horizontal, align == .leading ? 10 : 0)
    }
}

@main
struct ClocGUIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("Cloc GUI") {
            ContentView()
                .preferredColorScheme(.light)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.appearance = NSAppearance(named: .aqua)
        NSApp.activate(ignoringOtherApps: true)
    }
}
