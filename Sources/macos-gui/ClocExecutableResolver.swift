import Foundation

enum ClocExecutableResolver {
    static func resolve() -> URL? {
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

        let candidates = [
            "/opt/homebrew/bin/cloc",
            "/usr/local/bin/cloc",
            "/usr/bin/cloc",
        ]
        for candidate in candidates {
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return URL(fileURLWithPath: candidate)
            }
        }

        #if DEBUG
        if let override = ProcessInfo.processInfo.environment["CLOC_STUDIO_LOCAL_CLOC"],
           override.hasPrefix("/"),
           FileManager.default.isExecutableFile(atPath: override) {
            return URL(fileURLWithPath: override)
        }
        #endif

        return nil
    }
}
