/// GitHub-compatible slug generator that matches the behavior of
/// [github-slugger](https://github.com/Flet/github-slugger).
///
/// Algorithm:
/// 1. Lowercase the heading text
/// 2. Remove characters in Unicode categories: Punctuation, Symbol, Control, Format, Separator (except space)
/// 3. Replace spaces with hyphens
/// 4. Deduplicate: first occurrence = `slug`, second = `slug-1`, third = `slug-2`, etc.
public struct GitHubSlugger: Sendable {
    private var occurrences: [String: Int] = [:]

    public init() {}

    /// Generate a GitHub-compatible slug from heading text.
    public mutating func slug(_ heading: String) -> String {
        let base = Self.slugify(heading)
        if let count = occurrences[base] {
            occurrences[base] = count + 1
            let deduped = "\(base)-\(count + 1)"
            occurrences[deduped] = 0
            return deduped
        } else {
            occurrences[base] = 0
            return base
        }
    }

    /// Reset tracked occurrences for a new document.
    public mutating func reset() {
        occurrences.removeAll()
    }

    /// Pure slug generation without duplicate tracking.
    public static func slugify(_ text: String) -> String {
        let lowered = text.lowercased()
        var result = ""
        result.reserveCapacity(lowered.count)

        for character in lowered {
            if character == " " {
                result.append("-")
            } else if shouldKeep(character) {
                result.append(character)
            }
            // else: drop the character
        }

        return result
    }

    /// Determines whether a character should be kept in the slug.
    /// Keeps: letters, marks, numbers, hyphen, underscore.
    /// Removes: punctuation, symbols, control, format, separators.
    private static func shouldKeep(_ character: Character) -> Bool {
        for scalar in character.unicodeScalars {
            if !shouldKeepScalar(scalar) {
                return false
            }
        }
        return true
    }

    private static func shouldKeepScalar(_ scalar: Unicode.Scalar) -> Bool {
        // Always keep hyphen and underscore (they pass through in github-slugger)
        if scalar == "-" || scalar == "_" {
            return true
        }

        switch scalar.properties.generalCategory {
        // Letters - keep
        case .uppercaseLetter, .lowercaseLetter, .titlecaseLetter,
             .modifierLetter, .otherLetter:
            return true
        // Marks - keep
        case .nonspacingMark, .spacingMark, .enclosingMark:
            return true
        // Numbers - keep decimal digits (0-9 etc.) and letter numbers (Roman numerals etc.)
        // but NOT otherNumber (subscripts ₁₂₃, superscripts ⁴⁵⁶, fractions ½ etc.)
        // which github-slugger explicitly removes.
        case .decimalNumber, .letterNumber:
            return true
        // Everything else (punctuation, symbols, separators, control, format, etc.) - remove
        default:
            return false
        }
    }
}
