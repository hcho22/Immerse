import Foundation
import RenderFixtures

@main
enum RenderFixtureTool {
    static func main() async throws {
        let outputDirectory: URL
        if CommandLine.arguments.count > 1 {
            outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        } else {
            outputDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
                .appendingPathComponent("Evidence/RenderFixtures", isDirectory: true)
        }

        let manifest = try await RenderFixtureGenerator.writeFixtures(
            outputDirectory: outputDirectory,
            settings: .defaultExperimental
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(manifest)
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
    }
}
