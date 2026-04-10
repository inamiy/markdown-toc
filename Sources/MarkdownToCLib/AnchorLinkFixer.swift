import Foundation

/// Result of attempting to fix a single broken anchor link.
public struct AnchorFixResult: Sendable, Equatable {
    public let linkText: String
    public let brokenAnchor: String
    /// The corrected anchor, or `nil` if no confident fix was found.
    public let fixedAnchor: String?

    public init(linkText: String, brokenAnchor: String, fixedAnchor: String?) {
        self.linkText = linkText
        self.brokenAnchor = brokenAnchor
        self.fixedAnchor = fixedAnchor
    }
}

/// Scans markdown content for internal anchor links (`[text](#anchor)`)
/// and fixes broken ones by matching against heading-derived slugs.
public struct AnchorLinkFixer: Sendable {
    public init() {}

    /// Fix broken anchor links in the given markdown content.
    /// Returns the updated content and a list of results for each broken link found.
    public func fix(content: String) -> (updatedContent: String, results: [AnchorFixResult]) {
        // Build valid slug set from all headings (with duplicate tracking).
        let headings = extractHeadings(from: content)
        var slugger = GitHubSlugger()
        var validSlugs: [String] = []
        for heading in headings {
            validSlugs.append(slugger.slug(heading.text))
        }
        let validSlugSet = Set(validSlugs)

        // Internal anchor link pattern: [text](#anchor)
        let matches = content.matches(of: /\[([^\]]*)\]\(#([^)\s]+)\)/)

        var results: [AnchorFixResult] = []
        var updatedContent = content

        // Process in reverse document order so earlier indices remain valid.
        for match in matches.reversed() {
            let linkText = String(match.output.1)
            let anchor = String(match.output.2)

            if validSlugSet.contains(anchor) {
                continue  // anchor is valid
            }

            let fixedAnchor = findBestMatch(
                brokenAnchor: anchor,
                linkText: linkText,
                validSlugs: validSlugs,
                validSlugSet: validSlugSet
            )

            if let fixed = fixedAnchor {
                updatedContent.replaceSubrange(match.range, with: "[\(linkText)](#\(fixed))")
            }

            results.append(AnchorFixResult(
                linkText: linkText,
                brokenAnchor: anchor,
                fixedAnchor: fixedAnchor
            ))
        }

        results.reverse()  // restore document order
        return (updatedContent, results)
    }

    // MARK: - Matching strategies

    private func findBestMatch(
        brokenAnchor: String,
        linkText: String,
        validSlugs: [String],
        validSlugSet: Set<String>
    ) -> String? {
        // Strategy 1: Percent-decode the anchor.
        // Handles anchors like %E6%AD%A3%E8%A6%8F%E5%BD%A2 → 正規形条件
        if let decoded = brokenAnchor.removingPercentEncoding, decoded != brokenAnchor {
            if validSlugSet.contains(decoded) {
                return decoded
            }
            // Also try lowercasing the decoded result.
            let decodedLowered = decoded.lowercased()
            if validSlugSet.contains(decodedLowered) {
                return decodedLowered
            }
        }

        // Strategy 2: Case-only mismatch (anchors are case-sensitive).
        let lowered = brokenAnchor.lowercased()
        if validSlugSet.contains(lowered) {
            return lowered
        }

        // Strategy 3: Re-slugify the link display text.
        let reSlugged = GitHubSlugger.slugify(linkText)
        if validSlugSet.contains(reSlugged) {
            return reSlugged
        }

        // Strategy 4: Levenshtein distance — pick the closest valid slug.
        let threshold = 0.4
        var best: (slug: String, distance: Int)?
        for slug in validSlugs {
            let maxLen = max(lowered.count, slug.count)
            let cutoff = best.map(\.distance) ?? (maxLen > 0 ? Int(Double(maxLen) * threshold) + 1 : 1)
            let d = levenshteinDistance(lowered, slug, cutoff: cutoff)
            if best == nil || d < best!.distance {
                best = (slug, d)
            }
        }

        if let best = best {
            let maxLen = max(brokenAnchor.count, best.slug.count)
            guard maxLen > 0 else { return nil }
            if Double(best.distance) / Double(maxLen) <= threshold {
                return best.slug
            }
        }

        return nil
    }

    // MARK: - Levenshtein

    /// Space-optimized Levenshtein edit distance with early termination.
    /// Returns `cutoff` if the actual distance would meet or exceed it.
    func levenshteinDistance(_ s1: String, _ s2: String, cutoff: Int = .max) -> Int {
        let a = Array(s1.unicodeScalars)
        let b = Array(s2.unicodeScalars)
        let m = a.count
        let n = b.count

        // Quick length-difference check.
        if abs(m - n) >= cutoff { return cutoff }
        if m == 0 { return n }
        if n == 0 { return m }

        var prev = Array(0...n)
        var curr = Array(repeating: 0, count: n + 1)

        for i in 1...m {
            curr[0] = i
            var rowMin = curr[0]
            for j in 1...n {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                curr[j] = min(
                    prev[j] + 1,        // deletion
                    curr[j - 1] + 1,    // insertion
                    prev[j - 1] + cost  // substitution
                )
                rowMin = min(rowMin, curr[j])
            }
            // If every cell in this row already exceeds cutoff, bail out.
            if rowMin >= cutoff { return cutoff }
            swap(&prev, &curr)
        }

        return prev[n]
    }
}
