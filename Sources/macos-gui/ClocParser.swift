import Foundation

enum ClocParser {
    static func parse(jsonText: String, mode: ClocResultMode) throws -> ClocResult {
        guard let data = jsonText.data(using: .utf8) else {
            throw ClocStudioError.invalidJSON
        }

        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClocStudioError.unexpectedJSON
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
}
