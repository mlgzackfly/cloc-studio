import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case traditionalChinese = "zh-Hant"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .traditionalChinese: return "中文"
        }
    }
}

struct AppStrings {
    let language: AppLanguage

    var subtitle: String { text("Count source lines with a fast visual wrapper", "快速視覺化統計程式碼行數") }
    var prototypeBadge: String { text("macOS Prototype", "macOS 原型") }
    var inputs: String { text("Inputs", "輸入") }
    var clear: String { text("Clear", "清除") }
    var select: String { text("Select", "選取") }
    var targets: String { text("Targets", "目標") }
    func selectedCount(_ count: Int) -> String { text("\(count) selected", "已選取 \(count) 個") }
    var dropOrSelectHint: String { text("Drop files/folders below or click Select.", "將檔案或資料夾拖到下方，或點擊選取。") }
    var excludeDirs: String { text("Exclude dirs", "排除目錄") }
    var includeLang: String { text("Include lang", "包含語言") }
    var excludeLang: String { text("Exclude lang", "排除語言") }
    var includeExt: String { text("Include ext", "包含副檔名") }
    var excludeExt: String { text("Exclude ext", "排除副檔名") }
    var maxMB: String { text("Max MB", "最大 MB") }
    var useGitScope: String { text("Use git scope (--vcs=git)", "使用 git 範圍 (--vcs=git)") }
    var byFile: String { text("Break down by file (--by-file)", "依檔案統計 (--by-file)") }
    var skipUniqueness: String { text("Skip uniqueness check", "略過唯一性檢查") }
    var autoExtractArchives: String { text("Auto extract archives", "自動解壓縮壓縮檔") }
    var runCloc: String { text("Run cloc", "執行 cloc") }
    var running: String { text("Running...", "執行中...") }
    var cancel: String { text("Cancel", "取消") }
    var details: String { text("Details", "詳細資訊") }
    var lastCommand: String { text("Last command", "上次指令") }
    var files: String { text("Files", "檔案") }
    var code: String { text("Code", "程式碼") }
    var comment: String { text("Comment", "註解") }
    var blank: String { text("Blank", "空白") }
    var elapsed: String { text("Elapsed", "耗時") }
    var copyTable: String { text("Copy Table", "複製表格") }
    var copyText: String { text("Copy Text", "複製文字") }
    var copyMarkdown: String { text("Copy Markdown", "複製 Markdown") }
    var dropZone: String { text("Drop files/folders here to select and run", "將檔案或資料夾拖到這裡以選取並執行") }
    var noResultsYet: String { text("No results yet", "尚無結果") }
    var ready: String { text("Ready", "就緒") }
    var resolving: String { text("Resolving...", "解析中...") }
    var notFound: String { text("Not found", "找不到") }
    var extractingArchives: String { text("Extracting archives...", "解壓縮中...") }
    var completed: String { text("Completed", "完成") }
    var completedWithStderr: String { text("Completed with stderr output", "完成，但有 stderr 輸出") }
    var copiedWordTable: String { text("Copied Word table format to clipboard", "已複製 Word 表格格式到剪貼簿") }
    var copiedText: String { text("Copied text format to clipboard", "已複製文字格式到剪貼簿") }
    var copiedMarkdown: String { text("Copied Markdown table to clipboard", "已複製 Markdown 表格到剪貼簿") }
    var clocProducedNoOutput: String { text("cloc produced no output.", "cloc 沒有輸出任何內容。") }

    func rowTitle(for mode: ClocResultMode) -> String {
        switch mode {
        case .language: return text("Language", "語言")
        case .file: return text("File", "檔案")
        }
    }

    func breakdownTitle(for mode: ClocResultMode) -> String {
        switch mode {
        case .language: return text("Language Breakdown", "語言統計")
        case .file: return text("File Breakdown", "檔案統計")
        }
    }

    func completedAfterExtracting(_ count: Int) -> String {
        text("Completed after extracting \(count) archive\(count == 1 ? "" : "s").", "完成，已解壓縮 \(count) 個壓縮檔。")
    }

    func failed(_ message: String) -> String {
        text("Failed: \(message)", "失敗：\(message)")
    }

    func parseFailure(_ message: String) -> String {
        text("Failed to parse cloc JSON output: \(message)", "無法解析 cloc JSON 輸出：\(message)")
    }

    func stdoutPreview(_ preview: String) -> String {
        text("stdout preview:\n\(preview)", "stdout 預覽：\n\(preview)")
    }

    func stderrPreview(_ preview: String) -> String {
        text("stderr preview:\n\(preview)", "stderr 預覽：\n\(preview)")
    }

    private func text(_ english: String, _ traditionalChinese: String) -> String {
        switch language {
        case .english: return english
        case .traditionalChinese: return traditionalChinese
        }
    }
}
