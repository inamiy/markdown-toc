import Foundation

public enum ToCMarker {
    /// Marker written to files.
    public static let start = "<!-- START ToC -->"
    public static let end = "<!-- END ToC -->"
}

/// Replaces the ToC block between markers in markdown content.
public struct ToCInserter: Sendable {
    public init() {}

    /// Replace ToC between existing markers.
    /// Returns the updated content, or nil if no markers found.
    public func insert(into content: String, toc: String) -> String? {
        let wrappedToC = wrapWithMarkers(toc)

        guard let range = findMarkerRange(in: content) else {
            return nil
        }

        var updated = content
        updated.replaceSubrange(range, with: wrappedToC)
        return updated
    }

    /// Check if the content contains ToC markers.
    public func hasMarkers(in content: String) -> Bool {
        findMarkerRange(in: content) != nil
    }

    private func wrapWithMarkers(_ toc: String) -> String {
        [
            ToCMarker.start,
            "",
            toc,
            "",
            ToCMarker.end,
        ].joined(separator: "\n")
    }

    private func findMarkerRange(in content: String) -> Range<String.Index>? {
        // Find start marker (case-insensitive)
        guard let startRange = content.range(of: "<!-- start toc", options: .caseInsensitive) else {
            return nil
        }

        // Find start of the start marker line
        let lineStart = content[..<startRange.lowerBound].lastIndex(of: "\n")
            .map { content.index(after: $0) } ?? content.startIndex

        // Find end marker after start marker
        guard let endRange = content.range(
            of: "<!-- end toc",
            options: .caseInsensitive,
            range: startRange.upperBound..<content.endIndex
        ) else {
            return nil
        }

        // Find end of the end marker line (exclude trailing newline for idempotency)
        let lineEnd: String.Index
        if let nextNewline = content[endRange.upperBound...].firstIndex(of: "\n") {
            lineEnd = nextNewline
        } else {
            lineEnd = content.endIndex
        }

        return lineStart..<lineEnd
    }
}
