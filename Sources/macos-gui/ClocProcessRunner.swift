import Foundation

final class ClocProcessRunner: @unchecked Sendable {
    private let lock = NSLock()
    private var currentProcess: Process?

    func cancel() {
        lock.lock()
        let process = currentProcess
        lock.unlock()

        if let process, process.isRunning {
            process.terminate()
        }
    }

    func run(executable: URL, arguments: [String], timeout: TimeInterval = 300) async throws -> (stdout: String, stderr: String) {
        let fileManager = FileManager.default
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("cloc-studio-\(UUID().uuidString)", isDirectory: true)
        let stdoutURL = tempDir.appendingPathComponent("stdout.json")
        let stderrURL = tempDir.appendingPathComponent("stderr.txt")

        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        _ = fileManager.createFile(atPath: stdoutURL.path, contents: nil)
        _ = fileManager.createFile(atPath: stderrURL.path, contents: nil)

        let stdoutHandle = try FileHandle(forWritingTo: stdoutURL)
        let stderrHandle = try FileHandle(forWritingTo: stderrURL)

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            let state = RunState(
                process: process,
                stdoutHandle: stdoutHandle,
                stderrHandle: stderrHandle,
                tempDir: tempDir,
                stdoutURL: stdoutURL,
                stderrURL: stderrURL,
                continuation: continuation,
                clearCurrent: { [weak self, weak process] in
                    guard let self, let process else { return }
                    self.clearCurrentProcess(process)
                }
            )

            process.executableURL = executable
            process.arguments = arguments
            process.standardOutput = stdoutHandle
            process.standardError = stderrHandle
            process.terminationHandler = { proc in
                state.finish(status: proc.terminationStatus)
            }

            setCurrentProcess(process)

            let timeoutWork = DispatchWorkItem { [weak process] in
                guard let process, process.isRunning else { return }
                process.terminate()
                state.finish(error: ClocStudioError.timedOut(seconds: timeout))
            }
            state.timeoutWork = timeoutWork
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutWork)

            do {
                try process.run()
            } catch {
                state.finish(error: error)
            }
        }
    }

    private func setCurrentProcess(_ process: Process) {
        lock.lock()
        currentProcess = process
        lock.unlock()
    }

    private func clearCurrentProcess(_ process: Process) {
        lock.lock()
        if currentProcess === process {
            currentProcess = nil
        }
        lock.unlock()
    }
}

private final class RunState: @unchecked Sendable {
    private let lock = NSLock()
    private var didFinish = false

    let process: Process
    let stdoutHandle: FileHandle
    let stderrHandle: FileHandle
    let tempDir: URL
    let stdoutURL: URL
    let stderrURL: URL
    let continuation: CheckedContinuation<(stdout: String, stderr: String), Error>
    let clearCurrent: () -> Void
    var timeoutWork: DispatchWorkItem?

    init(
        process: Process,
        stdoutHandle: FileHandle,
        stderrHandle: FileHandle,
        tempDir: URL,
        stdoutURL: URL,
        stderrURL: URL,
        continuation: CheckedContinuation<(stdout: String, stderr: String), Error>,
        clearCurrent: @escaping () -> Void
    ) {
        self.process = process
        self.stdoutHandle = stdoutHandle
        self.stderrHandle = stderrHandle
        self.tempDir = tempDir
        self.stdoutURL = stdoutURL
        self.stderrURL = stderrURL
        self.continuation = continuation
        self.clearCurrent = clearCurrent
    }

    func finish(status: Int32) {
        finish {
            let outData = (try? Data(contentsOf: stdoutURL)) ?? Data()
            let errData = (try? Data(contentsOf: stderrURL)) ?? Data()
            let out = String(decoding: outData, as: UTF8.self)
            let err = String(decoding: errData, as: UTF8.self)

            if status == 0 {
                continuation.resume(returning: (out, err))
            } else if status == SIGTERM {
                continuation.resume(throwing: ClocStudioError.cancelled)
            } else {
                continuation.resume(throwing: ClocStudioError.processFailed(status: status, stderr: err))
            }
        }
    }

    func finish(error: Error) {
        finish {
            continuation.resume(throwing: error)
        }
    }

    private func finish(_ resume: () -> Void) {
        lock.lock()
        if didFinish {
            lock.unlock()
            return
        }
        didFinish = true
        lock.unlock()

        process.terminationHandler = nil
        timeoutWork?.cancel()
        timeoutWork = nil
        try? stdoutHandle.close()
        try? stderrHandle.close()
        clearCurrent()
        resume()
        try? FileManager.default.removeItem(at: tempDir)
    }
}
