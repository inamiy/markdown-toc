import Markdown

/// A heading entry extracted from a markdown document.
public struct HeadingEntry: Sendable, Equatable {
    public let level: Int
    public let text: String

    public init(level: Int, text: String) {
        self.level = level
        self.text = text
    }
}

/// Extracts headings from a parsed Markdown document using `MarkupWalker`.
///
/// Code blocks are automatically excluded because swift-markdown's AST
/// does not parse `#` inside code blocks as `Heading` nodes.
public struct HeadingExtractor: MarkupWalker {
    public private(set) var headings: [HeadingEntry] = []

    public init() {}

    public mutating func visitHeading(_ heading: Heading) {
        let text = plainText(of: heading)
        headings.append(HeadingEntry(level: heading.level, text: text))
        // Do not descend further; we've already extracted text.
    }

    /// Recursively extract plain text from inline markup children.
    /// Strips formatting (bold, italic, links, etc.) but keeps their text content.
    /// Images are represented as their alt text.
    private func plainText(of markup: any Markup) -> String {
        var result = ""
        for child in markup.children {
            if let text = child as? Markdown.Text {
                result += text.string
            } else if let code = child as? InlineCode {
                result += "`\(code.code)`"
            } else if let image = child as? Markdown.Image {
                // Images get alt text or "*" placeholder
                let alt = image.plainText
                result += alt.isEmpty ? "*" : alt
            } else if child is SoftBreak || child is LineBreak {
                result += " "
            } else {
                // Recurse into emphasis, strong, links, strikethrough, etc.
                result += plainText(of: child)
            }
        }
        return result
    }
}

/// Extract all headings from markdown source text.
public func extractHeadings(from source: String) -> [HeadingEntry] {
    let document = Document(parsing: source)
    var extractor = HeadingExtractor()
    extractor.visit(document)
    return extractor.headings
}
