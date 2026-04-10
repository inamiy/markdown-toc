import Testing
@testable import MarkdownToCLib

@Suite("GitHubSlugger")
struct GitHubSluggerTests {
    @Test("Basic ASCII headings")
    func basicASCII() {
        #expect(GitHubSlugger.slugify("Hello World") == "hello-world")
        #expect(GitHubSlugger.slugify("Installation") == "installation")
        #expect(GitHubSlugger.slugify("Getting Started") == "getting-started")
    }

    @Test("Preserves hyphens and underscores")
    func hyphensAndUnderscores() {
        #expect(GitHubSlugger.slugify("my-variable") == "my-variable")
        #expect(GitHubSlugger.slugify("my_variable") == "my_variable")
        #expect(GitHubSlugger.slugify("foo-bar_baz") == "foo-bar_baz")
    }

    @Test("Removes punctuation")
    func punctuation() {
        #expect(GitHubSlugger.slugify("Hello, World!") == "hello-world")
        #expect(GitHubSlugger.slugify("What's New?") == "whats-new")
        #expect(GitHubSlugger.slugify("foo.bar") == "foobar")
        #expect(GitHubSlugger.slugify("(parentheses)") == "parentheses")
        #expect(GitHubSlugger.slugify("a/b/c") == "abc")
    }

    @Test("Removes symbols")
    func symbols() {
        #expect(GitHubSlugger.slugify("Price: $100") == "price-100")
        #expect(GitHubSlugger.slugify("a + b = c") == "a--b--c")
        #expect(GitHubSlugger.slugify("100%") == "100")
    }

    @Test("CJK characters preserved")
    func cjk() {
        #expect(GitHubSlugger.slugify("日本語テスト") == "日本語テスト")
        #expect(GitHubSlugger.slugify("Hello 世界") == "hello-世界")
        #expect(GitHubSlugger.slugify("中文标题") == "中文标题")
    }

    @Test("Cyrillic characters preserved")
    func cyrillic() {
        #expect(GitHubSlugger.slugify("Привет мир") == "привет-мир")
    }

    @Test("Emoji removed")
    func emoji() {
        #expect(GitHubSlugger.slugify("😄 emoji") == "-emoji")
        #expect(GitHubSlugger.slugify("Hello 🌍 World") == "hello--world")
    }

    @Test("Duplicate heading tracking")
    func duplicates() {
        var slugger = GitHubSlugger()
        #expect(slugger.slug("Foo") == "foo")
        #expect(slugger.slug("Foo") == "foo-1")
        #expect(slugger.slug("Foo") == "foo-2")
        #expect(slugger.slug("Bar") == "bar")
        #expect(slugger.slug("Bar") == "bar-1")
    }

    @Test("Reset clears occurrences")
    func reset() {
        var slugger = GitHubSlugger()
        #expect(slugger.slug("Foo") == "foo")
        #expect(slugger.slug("Foo") == "foo-1")
        slugger.reset()
        #expect(slugger.slug("Foo") == "foo")
    }

    @Test("Backticks/code in heading text")
    func codeInHeading() {
        #expect(GitHubSlugger.slugify("Using forEach") == "using-foreach")
        #expect(GitHubSlugger.slugify("The map function") == "the-map-function")
    }

    @Test("Numbers preserved")
    func numbers() {
        #expect(GitHubSlugger.slugify("Step 1") == "step-1")
        #expect(GitHubSlugger.slugify("Chapter 42: The Answer") == "chapter-42-the-answer")
    }

    @Test("Mixed case lowered")
    func mixedCase() {
        #expect(GitHubSlugger.slugify("CamelCase") == "camelcase")
        #expect(GitHubSlugger.slugify("HTTPSConnection") == "httpsconnection")
    }

    @Test("Empty and whitespace")
    func emptyAndWhitespace() {
        #expect(GitHubSlugger.slugify("") == "")
        #expect(GitHubSlugger.slugify("   ") == "---")
    }

    // Real-world cases from typing-rules-ja.md, verified against GitHub HTML.

    @Test("Greek letters preserved")
    func greekLetters() {
        #expect(GitHubSlugger.slugify("Capability (@κ)") == "capability-κ")
        #expect(GitHubSlugger.slugify("2.2 Region (ρ)") == "22-region-ρ")
        #expect(GitHubSlugger.slugify("関数型 Annotation (@φ = @σ @ι)") == "関数型-annotation-φ--σ-ι")
    }

    @Test("Subscript/superscript numbers removed")
    func subscriptNumbers() {
        // ₁ (U+2081) and ₂ (U+2082) are .otherNumber — GitHub removes them.
        #expect(GitHubSlugger.slugify("2.4 Region Merge (ρ₁ ⊔ ρ₂)") == "24-region-merge-ρ--ρ")
        #expect(GitHubSlugger.slugify("ρ₁ ⊔ ρ₂") == "ρ--ρ")
    }

    @Test("Arrow and math symbols removed")
    func mathSymbols() {
        // → (U+2192) is .mathSymbol, ⊔ (U+2294) is .mathSymbol
        #expect(GitHubSlugger.slugify("Capability → Region 変換 (toRegion(@κ))") == "capability--region-変換-toregionκ")
    }

    @Test("At-sign removed, backtick content preserved")
    func atSignAndBackticks() {
        // Heading text after inline code stripping: @ι から capability @κ への変換 (toCapability)
        #expect(GitHubSlugger.slugify("@ι から capability @κ への変換 (toCapability)") == "ι-から-capability-κ-への変換-tocapability")
        #expect(GitHubSlugger.slugify("@Sendable capture 制約 (isAllSendable)") == "sendable-capture-制約-isallsendable")
    }

    @Test("Square brackets removed")
    func squareBrackets() {
        // [sending] の定義
        #expect(GitHubSlugger.slugify("[sending] の定義") == "sending-の定義")
    }

    @Test("Curly braces in Task headings")
    func curlyBraces() {
        // Task { ... } / Task.detached { ... } 本体
        #expect(GitHubSlugger.slugify("Task { ... } / Task.detached { ... } 本体") == "task-----taskdetached----本体")
    }

    @Test("Slash and colon removed")
    func slashAndColon() {
        #expect(GitHubSlugger.slugify("Isolation Subtyping / Coercion (isoSubtyping, isoCoercion)") == "isolation-subtyping--coercion-isosubtyping-isocoercion")
        #expect(GitHubSlugger.slugify("3. 同期・非同期境界 (Sync/Async Boundaries)") == "3-同期非同期境界-syncasync-boundaries")
    }

    @Test("Middle dot (・) removed")
    func middleDot() {
        // 中黒 ・ (U+30FB) is .otherPunctuation
        #expect(GitHubSlugger.slugify("同期・非同期境界") == "同期非同期境界")
    }

    @Test("@isolated(any) heading")
    func isolatedAny() {
        #expect(GitHubSlugger.slugify("5.6 @isolated(any)") == "56-isolatedany")
    }

    @Test("Complex mixed Japanese-English with symbols")
    func complexMixed() {
        #expect(GitHubSlugger.slugify("2.3 Region Access (accessible(@κ))") == "23-region-access-accessibleκ")
        #expect(GitHubSlugger.slugify("Capture 可否 (capturable(@κ))") == "capture-可否-capturableκ")
        #expect(GitHubSlugger.slugify("Actor-instance isolation の実効 capability (effectiveClosureCapability)") == "actor-instance-isolation-の実効-capability-effectiveclosurecapability")
    }
}
