import Testing
@testable import MarkdownToCLib

@Suite("AnchorLinkFixer")
struct AnchorLinkFixerTests {
    let fixer = AnchorLinkFixer()

    @Test("No broken links returns empty results")
    func noBrokenLinks() {
        let content = """
            # Hello

            ## World

            See [Hello](#hello) and [World](#world).
            """
        let (updated, results) = fixer.fix(content: content)
        #expect(results.isEmpty)
        #expect(updated == content)
    }

    @Test("Fixes case mismatch")
    func caseMismatch() {
        let content = """
            # Installation

            Go to [Installation](#Installation).
            """
        let (updated, results) = fixer.fix(content: content)
        #expect(results.count == 1)
        #expect(results[0].brokenAnchor == "Installation")
        #expect(results[0].fixedAnchor == "installation")
        #expect(updated.contains("[Installation](#installation)"))
    }

    @Test("Fixes via re-slugify from link text")
    func reSlugify() {
        // Link text "Getting Started!" re-slugifies to "getting-started"
        // which matches the heading slug.
        let content = """
            ## Getting Started

            See [Getting Started!](#getting-started!).
            """
        let (updated, results) = fixer.fix(content: content)
        #expect(results.count == 1)
        #expect(results[0].fixedAnchor == "getting-started")
        #expect(updated.contains("[Getting Started!](#getting-started)"))
    }

    @Test("Fixes via Levenshtein distance")
    func levenshteinFix() {
        // "instal" is close to "installation" — but too far (6/12 = 50% > 40%).
        // "installaton" is close to "installation" (distance 1).
        let content = """
            ## Installation

            See [here](#installaton).
            """
        let (updated, results) = fixer.fix(content: content)
        #expect(results.count == 1)
        #expect(results[0].fixedAnchor == "installation")
        #expect(updated.contains("[here](#installation)"))
    }

    @Test("Reports could-not-fix for distant anchors")
    func couldNotFix() {
        let content = """
            ## Installation

            See [xyz](#completely-different-anchor).
            """
        let (_, results) = fixer.fix(content: content)
        #expect(results.count == 1)
        #expect(results[0].fixedAnchor == nil)
    }

    @Test("Fixes multiple broken links in one document")
    func multipleBrokenLinks() {
        let content = """
            # Title

            ## Setup

            ## Usage

            See [Setup](#SETUP) and [Usage](#usagee).
            """
        let (updated, results) = fixer.fix(content: content)
        #expect(results.count == 2)
        #expect(results[0].fixedAnchor == "setup")
        #expect(results[1].fixedAnchor == "usage")
        #expect(updated.contains("[Setup](#setup)"))
        #expect(updated.contains("[Usage](#usage)"))
    }

    @Test("Skips valid anchors while fixing broken ones")
    func mixedValidAndBroken() {
        let content = """
            ## Alpha

            ## Beta

            Link to [Alpha](#alpha) and [Beta](#BETA).
            """
        let (updated, results) = fixer.fix(content: content)
        #expect(results.count == 1)
        #expect(results[0].brokenAnchor == "BETA")
        #expect(results[0].fixedAnchor == "beta")
        #expect(updated.contains("[Alpha](#alpha)"))
        #expect(updated.contains("[Beta](#beta)"))
    }

    @Test("Handles CJK headings — re-slugify from link text")
    func cjkHeadingsReSlugify() {
        // Link text "インストール" re-slugifies to the valid slug.
        let content = """
            ## インストール

            See [インストール](#insutoru).
            """
        let (updated, results) = fixer.fix(content: content)
        #expect(results.count == 1)
        #expect(results[0].fixedAnchor == "インストール")
        #expect(updated.contains("[インストール](#インストール)"))
    }

    @Test("CJK heading with unrelated link text — could not fix")
    func cjkCouldNotFix() {
        let content = """
            ## インストール

            See [click here](#insutoru).
            """
        let (_, results) = fixer.fix(content: content)
        #expect(results.count == 1)
        #expect(results[0].fixedAnchor == nil)
    }

    @Test("Re-slugify fixes punctuation in anchor")
    func punctuationInAnchor() {
        let content = """
            ## What's New

            See [What's New](#what's-new).
            """
        let (updated, results) = fixer.fix(content: content)
        #expect(results.count == 1)
        #expect(results[0].fixedAnchor == "whats-new")
        #expect(updated.contains("[What's New](#whats-new)"))
    }

    @Test("Handles document with no headings")
    func noHeadings() {
        let content = """
            Some text with a [link](#nowhere).
            """
        let (_, results) = fixer.fix(content: content)
        #expect(results.count == 1)
        #expect(results[0].fixedAnchor == nil)
    }

    @Test("Does not touch external links")
    func externalLinks() {
        let content = """
            ## Hello

            See [example](https://example.com) and [Hello](#hello).
            """
        let (updated, results) = fixer.fix(content: content)
        #expect(results.isEmpty)
        #expect(updated == content)
    }

    @Test("Handles duplicate headings with numbered slugs")
    func duplicateHeadings() {
        let content = """
            ## Setup

            ## Setup

            Link to [first](#setup) and [second](#setup-1) and [broken](#setup-3).
            """
        let (_, results) = fixer.fix(content: content)
        // #setup and #setup-1 are valid; #setup-3 is broken
        #expect(results.count == 1)
        #expect(results[0].brokenAnchor == "setup-3")
        // "setup-3" is close to "setup-1" (distance 1), should fix
        #expect(results[0].fixedAnchor == "setup-1")
    }
}

@Suite("Levenshtein distance")
struct LevenshteinTests {
    let fixer = AnchorLinkFixer()

    @Test("Equal strings have distance 0")
    func equal() {
        #expect(fixer.levenshteinDistance("abc", "abc") == 0)
    }

    @Test("Single insertion")
    func insertion() {
        #expect(fixer.levenshteinDistance("abc", "abcd") == 1)
    }

    @Test("Single deletion")
    func deletion() {
        #expect(fixer.levenshteinDistance("abcd", "abc") == 1)
    }

    @Test("Single substitution")
    func substitution() {
        #expect(fixer.levenshteinDistance("abc", "axc") == 1)
    }

    @Test("Empty strings")
    func empty() {
        #expect(fixer.levenshteinDistance("", "") == 0)
        #expect(fixer.levenshteinDistance("abc", "") == 3)
        #expect(fixer.levenshteinDistance("", "abc") == 3)
    }

    @Test("Completely different")
    func completelyDifferent() {
        #expect(fixer.levenshteinDistance("abc", "xyz") == 3)
    }
}
