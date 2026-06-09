import Foundation

enum BreakdownFormatter {
    static func tsv(rows: [ClocRow], mode: ClocResultMode) -> String {
        var lines = ["\(mode.rowTitle)\tFiles\tCode\tComment\tBlank"]
        for row in rows {
            lines.append("\(row.name)\t\(row.files)\t\(row.code)\t\(row.comment)\t\(row.blank)")
        }
        return lines.joined(separator: "\n")
    }

    static func plainText(rows: [ClocRow], mode: ClocResultMode) -> String {
        let top = rows.prefix(5)
        var lines = ["\(mode.breakdownTitle) Summary"]
        lines.append("Total \(mode.rowTitle.lowercased())s: \(rows.count)")
        lines.append("Top \(mode.rowTitle.lowercased())s by code lines:")
        for row in top {
            lines.append("- \(row.name): \(row.code) code lines (\(row.files) files)")
        }
        return lines.joined(separator: "\n")
    }

    static func markdownTable(rows: [ClocRow], mode: ClocResultMode) -> String {
        var lines = [
            "| \(mode.rowTitle) | Files | Code | Comment | Blank |",
            "|---|---:|---:|---:|---:|",
        ]
        for row in rows {
            lines.append("| \(escapeMarkdown(row.name)) | \(row.files) | \(row.code) | \(row.comment) | \(row.blank) |")
        }
        return lines.joined(separator: "\n")
    }

    static func htmlTable(rows: [ClocRow], mode: ClocResultMode) -> String {
        var html = "<table style=\"border-collapse:collapse;border:1px solid #222;font-family:-apple-system,BlinkMacSystemFont,Segoe UI,Arial,sans-serif;font-size:12px;\">"
        html += "<thead><tr>"
        html += "<th style=\"border:1px solid #222;padding:6px 8px;text-align:left;\">\(escapeHTML(mode.rowTitle))</th>"
        html += "<th style=\"border:1px solid #222;padding:6px 8px;text-align:right;\">Files</th>"
        html += "<th style=\"border:1px solid #222;padding:6px 8px;text-align:right;\">Code</th>"
        html += "<th style=\"border:1px solid #222;padding:6px 8px;text-align:right;\">Comment</th>"
        html += "<th style=\"border:1px solid #222;padding:6px 8px;text-align:right;\">Blank</th>"
        html += "</tr></thead><tbody>"
        for row in rows {
            html += "<tr>"
            html += "<td style=\"border:1px solid #222;padding:6px 8px;text-align:left;\">\(escapeHTML(row.name))</td>"
            html += "<td style=\"border:1px solid #222;padding:6px 8px;text-align:right;\">\(row.files)</td>"
            html += "<td style=\"border:1px solid #222;padding:6px 8px;text-align:right;\">\(row.code)</td>"
            html += "<td style=\"border:1px solid #222;padding:6px 8px;text-align:right;\">\(row.comment)</td>"
            html += "<td style=\"border:1px solid #222;padding:6px 8px;text-align:right;\">\(row.blank)</td>"
            html += "</tr>"
        }
        html += "</tbody></table>"
        return html
    }

    static func escapeHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    static func escapeMarkdown(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "`", with: "\\`")
    }
}
