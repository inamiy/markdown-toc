import ArgumentParser
import Foundation
import MarkdownToCLib

@main
struct MarkdownToC: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "markdown-toc",
        abstract: "Generate GitHub-compatible table of contents for Markdown files.",
        discussion: """
            Scans Markdown files for headings and generates a linked table of contents \
            using GitHub's exact anchor slug algorithm. The ToC is inserted between \
            <!-- START ToC --> / <!-- END ToC --> markers.
            """
    )

    @Argument(help: "Markdown file paths or directories to process.")
    var files: [String]

    @Option(name: .long, help: "Minimum heading level to include (1-6).")
    var minlevel: Int = 1

    @Option(name: .long, help: "Maximum heading level to include (1-6).")
    var maxlevel: Int = 6

    @Flag(name: .long, help: "Print result to stdout instead of modifying files.")
    var stdout: Bool = false

    @Flag(name: .long, help: "Also check and fix broken internal anchor links.")
    var fixAnchors: Bool = false

    func validate() throws {
        guard (1...6).contains(minlevel) else {
            throw ValidationError("--minlevel must be between 1 and 6")
        }
        guard (1...6).contains(maxlevel) else {
            throw ValidationError("--maxlevel must be between 1 and 6")
        }
        guard minlevel <= maxlevel else {
            throw ValidationError("--minlevel must be <= --maxlevel")
        }
    }

    func run() throws {
        let filePaths = try resolveFiles(files)

        guard !filePaths.isEmpty else {
            print("No Markdown files found.")
            return
        }

        let config = ToCConfig(minLevel: minlevel, maxLevel: maxlevel)
        let generator = ToCGenerator()
        let inserter = ToCInserter()
        let fixer = fixAnchors ? AnchorLinkFixer() : nil
        var updatedCount = 0

        for path in filePaths {
            let fileURL = URL(filePath: path)
            var content = try String(contentsOf: fileURL, encoding: .utf8)
            var modified = false

            // 1. ToC generation (if markers exist)
            let headings = extractHeadings(from: content)
            if let toc = generator.generate(headings: headings, config: config) {
                if inserter.hasMarkers(in: content) {
                    if let updated = inserter.insert(into: content, toc: toc), updated != content {
                        content = updated
                        modified = true
                    }
                } else {
                    print("\"\(path)\" has no ToC markers, skipping. Add <!-- START ToC --> / <!-- END ToC --> to enable.")
                }
            }

            // 2. Anchor link fixing (if --fix-anchors)
            if let fixer {
                let (fixedContent, results) = fixer.fix(content: content)

                for result in results {
                    if let fixed = result.fixedAnchor {
                        print("\"\(path)\": Detected broken link #\(result.brokenAnchor) → Fixed to #\(fixed)")
                    } else {
                        print("\"\(path)\": Detected broken link #\(result.brokenAnchor) → Could not fix")
                    }
                }

                if fixedContent != content {
                    content = fixedContent
                    modified = true
                }
            }

            // 3. Output
            if stdout {
                print(content)
            } else if modified {
                try content.write(to: fileURL, atomically: true, encoding: .utf8)
                updatedCount += 1
                print("\"\(path)\" updated")
            } else {
                print("\"\(path)\" already up to date")
            }
        }

        if !stdout {
            print("\nUpdated \(updatedCount) file(s).")
        }
    }

    private func resolveFiles(_ paths: [String]) throws -> [String] {
        let fm = FileManager.default
        var result: [String] = []

        for path in paths {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: path, isDirectory: &isDir) else {
                throw ValidationError("Path does not exist: \(path)")
            }

            if isDir.boolValue {
                if let enumerator = fm.enumerator(atPath: path) {
                    while let file = enumerator.nextObject() as? String {
                        if file.hasSuffix(".md") || file.hasSuffix(".markdown") {
                            let fullPath = URL(filePath: path).appending(path: file).path
                            result.append(fullPath)
                        }
                    }
                }
            } else {
                result.append(path)
            }
        }

        return result.sorted()
    }
}
