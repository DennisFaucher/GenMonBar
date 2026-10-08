import Foundation

struct RunResult {
    let output: String
    let error: String?
    let exitCode: Int32

    var succeeded: Bool { exitCode == 0 && error == nil }
}

enum WidgetRunner {
    static let timeout: TimeInterval = 10

    /// Runs a command in the user's login shell so PATH matches a normal terminal.
    static func run(_ command: String, completion: @escaping (RunResult) -> Void) {
        let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shell)
        process.arguments = ["-lc", command]

        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        process.environment = env

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        let queue = DispatchQueue(label: "genmonbar.runner", qos: .utility)
        var timedOut = false

        queue.async {
            do {
                try process.run()
            } catch {
                DispatchQueue.main.async {
                    completion(RunResult(output: "", error: error.localizedDescription, exitCode: -1))
                }
                return
            }

            let timeoutItem = DispatchWorkItem {
                if process.isRunning {
                    timedOut = true
                    process.terminate()
                }
            }
            queue.asyncAfter(deadline: .now() + timeout, execute: timeoutItem)

            process.waitUntilExit()
            timeoutItem.cancel()

            let outData = stdout.fileHandleForReading.readDataToEndOfFile()
            let errData = stderr.fileHandleForReading.readDataToEndOfFile()
            let out = String(data: outData, encoding: .utf8) ?? ""
            let err = String(data: errData, encoding: .utf8) ?? ""

            DispatchQueue.main.async {
                if timedOut {
                    completion(RunResult(output: out, error: "Timed out after \(Int(timeout))s", exitCode: -1))
                } else {
                    let errorText = err.trimmingCharacters(in: .whitespacesAndNewlines)
                    completion(RunResult(
                        output: out,
                        error: process.terminationStatus == 0 ? nil : (errorText.isEmpty ? "Exit \(process.terminationStatus)" : errorText),
                        exitCode: process.terminationStatus
                    ))
                }
            }
        }
    }

    /// First non-empty line, trimmed — what gets shown in the status bar.
    static func displayText(for result: RunResult) -> String {
        if let error = result.error, !error.isEmpty {
            return "⚠️"
        }
        let lines = result.output
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard let first = lines.first else { return "—" }
        return String(first)
    }
}
