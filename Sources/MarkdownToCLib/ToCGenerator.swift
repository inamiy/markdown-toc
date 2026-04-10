/// Configuration for ToC generation.
public struct ToCConfig: Sendable {
    public var minLevel: Int
    public var maxLevel: Int

    public init(minLevel: Int = 1, maxLevel: Int = 6) {
        precondition((1...6).contains(minLevel), "minLevel must be between 1 and 6")
        precondition((1...6).contains(maxLevel), "maxLevel must be between 1 and 6")
        precondition(minLevel <= maxLevel, "minLevel must be <= maxLevel")
        self.minLevel = minLevel
        self.maxLevel = maxLevel
    }
}

/// Generates a Markdown Table of Contents string from extracted headings.
public struct ToCGenerator: Sendable {
    public init() {}

    /// Generate a ToC from headings with the given configuration.
    /// Returns the ToC body lines (without markers) or nil if no headings match.
    public func generate(
        headings: [HeadingEntry],
        config: ToCConfig = ToCConfig()
    ) -> String? {
        // Pre-generate slugs for all headings (including filtered-out ones)
        // to ensure duplicate counters match GitHub's behavior.
        // GitHub counts all headings on the page, not just visible ToC entries.
        var slugger = GitHubSlugger()
        var slugs: [(heading: HeadingEntry, slug: String)] = []
        for heading in headings {
            let s = slugger.slug(heading.text)
            if heading.level >= config.minLevel && heading.level <= config.maxLevel {
                slugs.append((heading, s))
            }
        }

        guard !slugs.isEmpty else { return nil }

        let minDisplayLevel = slugs.map(\.heading.level).min() ?? config.minLevel

        var lines: [String] = []
        for (heading, slug) in slugs {
            let indent = String(repeating: "  ", count: heading.level - minDisplayLevel)
            lines.append("\(indent)- [\(heading.text)](#\(slug))")
        }

        return lines.joined(separator: "\n")
    }
}
