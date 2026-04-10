import Testing
@testable import MarkdownToCLib

@Suite("HeadingExtractor")
struct HeadingExtractorTests {
    @Test("Extracts ATX headings")
    func atxHeadings() {
        let source = """
            # Title
            ## Section 1
            ### Subsection
            ## Section 2
            """
        let headings = extractHeadings(from: source)
        #expect(headings.count == 4)
        #expect(headings[0] == HeadingEntry(level: 1, text: "Title"))
        #expect(headings[1] == HeadingEntry(level: 2, text: "Section 1"))
        #expect(headings[2] == HeadingEntry(level: 3, text: "Subsection"))
        #expect(headings[3] == HeadingEntry(level: 2, text: "Section 2"))
    }

    @Test("Ignores headings inside code blocks")
    func codeBlocks() {
        let source = """
            # Real Heading

            ```
            # This is inside a code block
            ## Also inside
            ```

            ## Another Real Heading
            """
        let headings = extractHeadings(from: source)
        #expect(headings.count == 2)
        #expect(headings[0].text == "Real Heading")
        #expect(headings[1].text == "Another Real Heading")
    }

    @Test("Strips inline formatting from heading text")
    func inlineFormatting() {
        let source = """
            # **Bold** heading
            ## A *italic* section
            ### Using `code` spans
            #### A [link](http://example.com) here
            """
        let headings = extractHeadings(from: source)
        #expect(headings[0].text == "Bold heading")
        #expect(headings[1].text == "A italic section")
        #expect(headings[2].text == "Using `code` spans")
        #expect(headings[3].text == "A link here")
    }
}

@Suite("ToCGenerator")
struct ToCGeneratorTests {
    @Test("Generates basic ToC")
    func basicToC() {
        let headings = [
            HeadingEntry(level: 1, text: "Title"),
            HeadingEntry(level: 2, text: "Section 1"),
            HeadingEntry(level: 3, text: "Subsection"),
            HeadingEntry(level: 2, text: "Section 2"),
        ]
        let generator = ToCGenerator()
        let toc = generator.generate(headings: headings)

        let expected = """
            - [Title](#title)
              - [Section 1](#section-1)
                - [Subsection](#subsection)
              - [Section 2](#section-2)
            """
        #expect(toc == expected)
    }

    @Test("Respects minLevel and maxLevel")
    func levelFiltering() {
        let headings = [
            HeadingEntry(level: 1, text: "Title"),
            HeadingEntry(level: 2, text: "Section"),
            HeadingEntry(level: 3, text: "Sub"),
            HeadingEntry(level: 4, text: "Deep"),
        ]
        let generator = ToCGenerator()
        let config = ToCConfig(minLevel: 2, maxLevel: 3)
        let toc = generator.generate(headings: headings, config: config)

        let expected = """
            - [Section](#section)
              - [Sub](#sub)
            """
        #expect(toc == expected)
    }

    @Test("Handles duplicate headings")
    func duplicateHeadings() {
        let headings = [
            HeadingEntry(level: 2, text: "Setup"),
            HeadingEntry(level: 2, text: "Setup"),
            HeadingEntry(level: 2, text: "Setup"),
        ]
        let generator = ToCGenerator()
        let toc = generator.generate(headings: headings)

        let expected = """
            - [Setup](#setup)
            - [Setup](#setup-1)
            - [Setup](#setup-2)
            """
        #expect(toc == expected)
    }

    @Test("Returns nil for empty headings")
    func emptyHeadings() {
        let generator = ToCGenerator()
        #expect(generator.generate(headings: []) == nil)
    }
}

@Suite("ToCInserter")
struct ToCInserterTests {
    @Test("Returns nil when no markers exist")
    func noMarkers() {
        let content = """
            # My Document

            Some intro text.

            ## First Section
            """
        let inserter = ToCInserter()
        let result = inserter.insert(into: content, toc: "- [First Section](#first-section)")
        #expect(result == nil)
    }

    @Test("Replaces existing ToC markers")
    func replaceExistingToC() {
        let content = """
            # Title

            <!-- START ToC -->

            old toc content

            <!-- END ToC -->

            ## Section
            """
        let inserter = ToCInserter()
        let result = inserter.insert(into: content, toc: "- [Section](#section)")!

        #expect(!result.contains("old toc content"))
        #expect(result.contains("- [Section](#section)"))
    }

    @Test("Case-insensitive marker detection")
    func caseInsensitive() {
        let inserter = ToCInserter()
        #expect(inserter.hasMarkers(in: "<!-- START toc -->\n<!-- END toc -->"))
        #expect(inserter.hasMarkers(in: "<!-- START ToC -->\n<!-- END ToC -->"))
        #expect(inserter.hasMarkers(in: "<!-- start TOC -->\n<!-- end TOC -->"))
    }

    @Test("hasMarkers detection")
    func hasMarkers() {
        let inserter = ToCInserter()
        #expect(!inserter.hasMarkers(in: "# Hello\n"))
        #expect(inserter.hasMarkers(in: "<!-- START ToC -->\n<!-- END ToC -->"))
    }
}

@Suite("End-to-end integration")
struct EndToEndTests {
    @Test("Full pipeline: parse -> extract -> generate -> insert")
    func fullPipeline() {
        let source = """
            # My Project

            <!-- START ToC -->
            <!-- END ToC -->

            Introduction paragraph.

            ## Installation

            Install instructions.

            ## Usage

            ### Basic Usage

            Basic examples.

            ### Advanced Usage

            Advanced examples.

            ## Contributing
            """

        let headings = extractHeadings(from: source)
        let generator = ToCGenerator()
        let config = ToCConfig(minLevel: 2, maxLevel: 3)
        let toc = generator.generate(headings: headings, config: config)!
        let inserter = ToCInserter()
        let result = inserter.insert(into: source, toc: toc)!

        #expect(result.contains("- [Installation](#installation)"))
        #expect(result.contains("- [Usage](#usage)"))
        #expect(result.contains("  - [Basic Usage](#basic-usage)"))
        #expect(result.contains("  - [Advanced Usage](#advanced-usage)"))
        #expect(result.contains("- [Contributing](#contributing)"))
        // H1 should NOT be in ToC (minLevel=2)
        #expect(!result.contains("[My Project]"))
    }

    @Test("CJK headings produce correct anchors")
    func cjkHeadings() {
        let source = """
            # プロジェクト

            ## インストール

            ## 使い方
            """

        let headings = extractHeadings(from: source)
        let generator = ToCGenerator()
        let toc = generator.generate(headings: headings)!

        #expect(toc.contains("[プロジェクト](#プロジェクト)"))
        #expect(toc.contains("[インストール](#インストール)"))
        #expect(toc.contains("[使い方](#使い方)"))
    }
}
