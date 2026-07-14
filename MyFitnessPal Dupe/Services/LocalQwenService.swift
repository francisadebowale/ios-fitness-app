import Foundation
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import Tokenizers

actor LocalQwenService {
    static let shared = LocalQwenService()

    private static let modelFolderName = "Qwen3-1.7B-4bit"

    private var container: ModelContainer?

    func generate(
        prompt: String,
        instructions: String,
        maxTokens: Int = 512,
        temperature: Float = 0.2
    ) async throws -> String {
        let container = try await loadedContainer()
        let session = ChatSession(
            container,
            instructions: instructions,
            generateParameters: GenerateParameters(
                maxTokens: maxTokens,
                temperature: temperature,
                topP: 0.9,
                repetitionPenalty: 1.05
            )
        )
        let response = try await session.respond(to: prompt)
        return cleaned(response)
    }

    private func loadedContainer() async throws -> ModelContainer {
        if let container {
            return container
        }

        let directory = try modelDirectory()
        let loaded = try await LLMModelFactory.shared.loadContainer(
            from: directory,
            using: #huggingFaceTokenizerLoader()
        )
        container = loaded
        return loaded
    }

    private func modelDirectory() throws -> URL {
        let fileManager = FileManager.default
        let bundle = Bundle.main

        var candidates: [URL] = []
        if let direct = bundle.url(forResource: Self.modelFolderName, withExtension: nil) {
            candidates.append(direct)
        }
        if let resourceURL = bundle.resourceURL {
            candidates.append(resourceURL.appendingPathComponent(Self.modelFolderName, isDirectory: true))
            candidates.append(resourceURL.appendingPathComponent("Models", isDirectory: true).appendingPathComponent(Self.modelFolderName, isDirectory: true))
            candidates.append(resourceURL)
        }

        for candidate in candidates where fileManager.fileExists(atPath: candidate.appendingPathComponent("config.json").path) {
            return candidate
        }

        throw LocalQwenError.modelFolderMissing(
            Self.modelFolderName,
            diagnostics: bundleDiagnostics(bundle: bundle, candidates: candidates)
        )
    }

    private func bundleDiagnostics(bundle: Bundle, candidates: [URL]) -> String {
        let fileManager = FileManager.default
        var lines = [
            "Bundle resource URL: \(bundle.resourceURL?.path ?? "nil")",
            "Checked model paths:"
        ]

        if candidates.isEmpty {
            lines.append("- <none>")
        } else {
            for candidate in candidates {
                let configURL = candidate.appendingPathComponent("config.json")
                let status = fileManager.fileExists(atPath: configURL.path) ? "config.json found" : "config.json missing"
                lines.append("- \(candidate.path) (\(status))")
            }
        }

        guard let resourceURL = bundle.resourceURL else {
            return lines.joined(separator: "\n")
        }

        lines.append("Bundle contents:")
        lines.append(contentsList(at: resourceURL, label: nil))

        let modelsURL = resourceURL.appendingPathComponent("Models", isDirectory: true)
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: modelsURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
            lines.append("Models contents:")
            lines.append(contentsList(at: modelsURL, label: nil))
        }

        return lines.joined(separator: "\n")
    }

    private func contentsList(at url: URL, label: String?) -> String {
        let fileManager = FileManager.default
        let contents: [URL]
        do {
            contents = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            return "- <unreadable: \(error.localizedDescription)>"
        }

        if contents.isEmpty {
            return "- <empty>"
        }

        let names = contents
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .prefix(80)
            .map { entry in
                let isDirectory = (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                return "- \(entry.lastPathComponent)\(isDirectory ? "/" : "")"
            }

        var lines = Array(names)
        if contents.count > names.count {
            lines.append("- ... \(contents.count - names.count) more items")
        }
        return lines.joined(separator: "\n")
    }

    private func cleaned(_ response: String) -> String {
        response
            .replacingOccurrences(of: "<think>", with: "")
            .replacingOccurrences(of: "</think>", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum LocalQwenError: LocalizedError {
    case modelFolderMissing(String, diagnostics: String)

    var errorDescription: String? {
        switch self {
        case .modelFolderMissing(let folderName, let diagnostics):
            return "The bundled model folder \"\(folderName)\" could not be found.\n\n\(diagnostics)"
        }
    }
}
