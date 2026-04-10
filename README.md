# markdown-toc
GitHub-compatible Markdown ToC generator and broken anchor link auto-fixer.

A Swift CLI tool for Markdown heading management:

1. **ToC generation** -- Insert a GitHub-compatible table of contents between markers
2. **Anchor link fixing** -- Detect and auto-fix broken internal anchor links (`[text](#slug)`)

Slug generation follows GitHub's exact algorithm, including CJK, Cyrillic, emoji removal, and duplicate-heading counters.

## Installation

```bash
swift build -c release
cp .build/release/markdown-toc /usr/local/bin/
```

## Usage

### Generate Table of Contents

Add markers to your Markdown file:

```markdown
# My Project

<!-- START ToC -->
<!-- END ToC -->

## Installation
## Usage
### Basic Usage
### Advanced Usage
## Contributing
```

Then run:

```bash
markdown-toc README.md
```

The tool inserts (or updates) a linked ToC between the markers:

```markdown
<!-- START ToC -->

- [Installation](#installation)
- [Usage](#usage)
  - [Basic Usage](#basic-usage)
  - [Advanced Usage](#advanced-usage)
- [Contributing](#contributing)

<!-- END ToC -->
```

### Fix Broken Anchor Links

```bash
markdown-toc README.md --fix-anchors
```

This runs ToC generation **and** scans all internal anchor links (`[text](#anchor)`) for broken references. The auto-fix algorithm uses three strategies:

1. **Case normalization** -- `#Getting-Started` → `#getting-started`
2. **Re-slugify from link text** -- `[What's New](#what's-new)` → `#whats-new`
3. **Levenshtein distance** -- `#instalation` → `#installation` (typo correction)

Output:

```
"README.md": Detected broken link #instalation → Fixed to #installation
"README.md": Detected broken link #Getting-Started → Fixed to #getting-started
"README.md": Detected broken link #totally-wrong → Could not fix
```

Links that are too far from any valid heading are reported as "Could not fix" and left unchanged.

### Options

```
USAGE: markdown-toc <files> ... [--minlevel <minlevel>] [--maxlevel <maxlevel>] [--stdout] [--fix-anchors]

ARGUMENTS:
  <files>               Markdown file paths or directories to process.

OPTIONS:
  --minlevel <minlevel> Minimum heading level to include (default: 1)
  --maxlevel <maxlevel> Maximum heading level to include (default: 6)
  --stdout              Print result to stdout instead of modifying files.
  --fix-anchors         Also check and fix broken internal anchor links.
```

### Process a directory

```bash
markdown-toc docs/
```

Recursively finds all `.md` and `.markdown` files.

### Preview without writing

```bash
markdown-toc README.md --stdout
```

### Filter heading levels

```bash
markdown-toc README.md --minlevel 2 --maxlevel 3
```
## Requirements

- Swift 6.2+
- macOS 13+
