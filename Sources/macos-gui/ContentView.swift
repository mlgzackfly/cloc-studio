import AppKit
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
                        header
                        inputPanel(filterColumns: filterColumns, compact: compact)
                        runControls
                        commandAndErrors
                        summaryPanel
                        breakdownPanel
                    }
                    .padding(16)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 760, minHeight: 580)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Cloc Studio")
                .font(.system(size: 34, weight: .bold, design: .rounded))
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
    }

    private func inputPanel(filterColumns: [GridItem], compact: Bool) -> some View {
        panel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Inputs", systemImage: "slider.horizontal.3")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(red: 0.16, green: 0.23, blue: 0.34))
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

                HStack {
                    Text("Targets")
                        .frame(width: 88, alignment: .leading)
                        .foregroundStyle(Color(red: 0.24, green: 0.31, blue: 0.41))
                    Text("\(viewModel.targetPaths.count) selected")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(red: 0.24, green: 0.31, blue: 0.41))
                    Spacer()
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
                        optionToggles
                    }
                } else {
                    HStack(spacing: 16) {
                        optionToggles
                    }
                }

                LazyVGrid(columns: filterColumns, spacing: 10) {
                    filterField(title: "Exclude dirs", placeholder: ".git,node_modules,dist", text: $viewModel.options.excludeDirs)
                    filterField(title: "Include lang", placeholder: "Swift,Objective-C", text: $viewModel.options.includeLangs)
                    filterField(title: "Exclude lang", placeholder: "Markdown,JSON", text: $viewModel.options.excludeLangs)
                    filterField(title: "Include ext", placeholder: "swift,m,mm", text: $viewModel.options.includeExts)
                    filterField(title: "Exclude ext", placeholder: "min.js,map", text: $viewModel.options.excludeExts)
                    filterField(title: "Max MB", placeholder: "20", text: $viewModel.options.maxFileSizeMB)
                }

                dropZone
            }
        }
    }

    private var optionToggles: some View {
        Group {
            Toggle("Use git scope (--vcs=git)", isOn: $viewModel.options.useVCSGit)
            Toggle("Break down by file (--by-file)", isOn: $viewModel.options.byFile)
            Toggle("Skip uniqueness check", isOn: $viewModel.options.skipUniqueness)
            Toggle("Auto extract archives", isOn: $viewModel.options.autoExtractArchives)
        }
    }

    private var runControls: some View {
        HStack(spacing: 10) {
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

            if viewModel.isRunning {
                Button {
                    viewModel.cancel()
                } label: {
                    Label("Cancel", systemImage: "xmark.circle")
                }
                .buttonStyle(.bordered)
            }

            Text(viewModel.statusMessage)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color(red: 0.22, green: 0.30, blue: 0.40))
                .lineLimit(2)
        }
    }

    private var commandAndErrors: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !viewModel.lastCommand.isEmpty {
                Text("Last command: \(viewModel.lastCommand)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(red: 0.35, green: 0.42, blue: 0.52))
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }

            if !viewModel.errorDetails.isEmpty {
                DisclosureGroup("Details") {
                    ScrollView {
                        Text(viewModel.errorDetails)
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 120)
                    .padding(8)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                }
                .font(.system(size: 12, weight: .medium))
            }
        }
    }

    @ViewBuilder
    private var summaryPanel: some View {
        if let summary = viewModel.summary {
            panel {
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
    }

    private var breakdownPanel: some View {
        panel {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(viewModel.mode.breakdownTitle, systemImage: viewModel.mode == .file ? "doc.text" : "chart.bar.xaxis")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(red: 0.16, green: 0.23, blue: 0.34))
                    Spacer()
                    Button("Copy Table") { viewModel.copyBreakdownAsWordTable() }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.rows.isEmpty)
                    Button("Copy Text") { viewModel.copyBreakdownAsText() }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.rows.isEmpty)
                    Button("Copy Markdown") { viewModel.copyBreakdownAsMarkdown() }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.rows.isEmpty)
                }

                breakdownList
            }
        }
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
                    Text("Drop files/folders here to select and run")
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

    private func panel<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
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
                    breakdownHeader(viewModel.mode.rowTitle, width: 300, align: .leading)
                    breakdownHeader("Files", width: 90)
                    breakdownHeader("Code", width: 90)
                    breakdownHeader("Comment", width: 100)
                    breakdownHeader("Blank", width: 90)
                }
                .background(Color.white.opacity(0.75))

                if viewModel.rows.isEmpty {
                    Text("No results yet")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color(red: 0.40, green: 0.46, blue: 0.56))
                        .frame(maxWidth: .infinity, minHeight: 120)
                        .background(Color.white.opacity(0.56))
                } else {
                    ForEach(viewModel.rows) { row in
                        HStack(spacing: 0) {
                            breakdownCell(row.name, width: 300, align: .leading)
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
            .frame(minWidth: 670)
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
