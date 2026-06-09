import Foundation

enum ClocParser {
    static func parse(jsonText: String, mode: ClocResultMode) throws -> ClocResult {
        guard let data = jsonText.data(using: .utf8) else {
            throw ClocStudioError.invalidJSON("Failed to decode cloc output as UTF-8.")
        }

        let object = try parseJSONObject(data: data, fallbackText: jsonText)

        guard let root = object as? [String: Any] else {
            throw ClocStudioError.unexpectedJSON("Unexpected JSON structure from cloc.")
        }

        let header = root["header"] as? [String: Any]
        let sum = root["SUM"] as? [String: Any] ?? [:]
        let summary = ClocSummary(
            files: asInt(sum["nFiles"]),
            blank: asInt(sum["blank"]),
            comment: asInt(sum["comment"]),
            code: asInt(sum["code"]),
            elapsedSeconds: asDouble(header?["elapsed_seconds"])
        )

        var rows: [ClocRow] = []
        for (key, value) in root {
            if key == "header" || key == "SUM" { continue }
            guard let dict = value as? [String: Any] else { continue }
            rows.append(
                ClocRow(
                    name: key,
                    files: asInt(dict["nFiles"], fallback: mode == .file ? 1 : 0),
                    blank: asInt(dict["blank"]),
                    comment: asInt(dict["comment"]),
                    code: asInt(dict["code"])
                )
            )
        }

        return ClocResult(
            mode: mode,
            summary: summary,
            rows: rows.sorted { lhs, rhs in
                if lhs.code == rhs.code {
                    return lhs.name < rhs.name
                }
                return lhs.code > rhs.code
            }
        )
    }

    private static func asInt(_ value: Any?, fallback: Int = 0) -> Int {
        if let intValue = value as? Int { return intValue }
        if let number = value as? NSNumber { return number.intValue }
        if let stringValue = value as? String, let intValue = Int(stringValue) { return intValue }
        return fallback
    }

    private static func asDouble(_ value: Any?) -> Double? {
        if let doubleValue = value as? Double { return doubleValue }
        if let number = value as? NSNumber { return number.doubleValue }
        if let stringValue = value as? String, let doubleValue = Double(stringValue) { return doubleValue }
        return nil
    }

    private static func parseJSONObject(data: Data, fallbackText: String) throws -> Any {
        do {
            return try JSONSerialization.jsonObject(with: data)
        } catch {
            if let text = String(data: data, encoding: .utf8),
               let normalized = normalizeNonStandardJSONNumbers(in: text).data(using: .utf8),
               let object = try? JSONSerialization.jsonObject(with: normalized) {
                return object
            }
            return try parseEmbeddedJSONObject(from: fallbackText, originalError: error)
        }
    }

    private static func parseEmbeddedJSONObject(from text: String, originalError: Error) throws -> Any {
        guard
            let start = text.firstIndex(of: "{"),
            let end = text.lastIndex(of: "}"),
            start <= end
        else {
            throw ClocStudioError.invalidJSON("Failed to parse cloc JSON output: \(originalError.localizedDescription)")
        }

        let jsonSlice = String(text[start...end])
        guard let data = jsonSlice.data(using: .utf8) else {
            throw ClocStudioError.invalidJSON("Failed to decode extracted cloc JSON output as UTF-8.")
        }

        do {
            return try JSONSerialization.jsonObject(with: data)
        } catch {
            if let normalized = normalizeNonStandardJSONNumbers(in: jsonSlice).data(using: .utf8),
               let object = try? JSONSerialization.jsonObject(with: normalized) {
                return object
            }
            throw ClocStudioError.invalidJSON("Failed to parse cloc JSON output: \(error.localizedDescription)")
        }
    }

    private static func normalizeNonStandardJSONNumbers(in text: String) -> String {
        let pattern = #"(:\s*)(-?(?:inf|nan|Infinity))(?=\s*[,}\]])"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return text
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "$1null")
    }
}
