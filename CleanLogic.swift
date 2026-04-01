import Foundation

// MARK: - Detection & Cleaning

/// Detect Claude Code output and clean it.
/// Two independent detection paths:
///   Path A: Many lines have trailing space padding → strip trailing + leading 2-space
///   Path B: Consistent leading 2-space pattern → strip leading 2-space only
func cleanClaudeOutput(_ text: String) -> String? {
    let lines = text.components(separatedBy: "\n")
    guard lines.count >= 3 else { return nil }

    let hasPadding = hasTrailingSpacePadding(lines)
    let hasLeading = hasLeadingTwoSpacePattern(lines)

    guard hasPadding || hasLeading else { return nil }

    // Path A: infer terminal width from padded line lengths (all same width)
    var terminalWidth: Int? = nil
    if hasPadding {
        let paddedLengths = lines.filter { !$0.isEmpty }.map { $0.count }
        if let maxLen = paddedLengths.max(), maxLen > 0 {
            terminalWidth = maxLen
        }
    }

    let cleaned = lines.map { line -> String in
        var s = line

        // Path A: strip trailing spaces
        if hasPadding {
            if let last = s.lastIndex(where: { $0 != " " }) {
                s = String(s[...last])
            } else if !s.isEmpty {
                s = ""
            }
        }

        // Both paths: strip leading 2 spaces
        if s.hasPrefix("  ") {
            s = String(s.dropFirst(2))
        }

        return s
    }.joined(separator: "\n")

    let unwrapped = unwrapParagraphLines(cleaned, terminalWidth: terminalWidth)

    return unwrapped != text ? unwrapped : nil
}

// MARK: - Path A: Trailing Space Padding

/// 50%+ of non-empty lines have ≥3 trailing spaces.
/// Normal text never has this — unique to terminal copy.
func hasTrailingSpacePadding(_ lines: [String]) -> Bool {
    var paddedCount = 0
    var nonEmptyCount = 0

    for line in lines {
        guard !line.isEmpty else { continue }
        nonEmptyCount += 1

        if let lastNonSpace = line.lastIndex(where: { $0 != " " }) {
            let trailingSpaces = line.distance(from: lastNonSpace, to: line.endIndex) - 1
            if trailingSpaces >= 3 {
                paddedCount += 1
            }
        } else {
            // All-space line
            paddedCount += 1
        }
    }

    guard paddedCount >= 3 else { return false }
    return Double(paddedCount) / Double(max(nonEmptyCount, 1)) >= 0.5
}

// MARK: - Post-Processing: Paragraph Unwrapping

/// Terminal display width of a string, counting CJK characters as 2 columns.
func displayWidth(_ s: String) -> Int {
    var w = 0
    for scalar in s.unicodeScalars {
        let v = scalar.value
        // CJK Unified Ideographs, Hangul Syllables, CJK Compatibility,
        // Fullwidth Forms, CJK Ext-A/B, Katakana/Hiragana, CJK Symbols
        if (0x1100...0x115F).contains(v)   // Hangul Jamo
            || (0x2E80...0x303E).contains(v)  // CJK Radicals, Kangxi, CJK Symbols
            || (0x3041...0x33BF).contains(v)  // Hiragana, Katakana, CJK Compat
            || (0x3400...0x4DBF).contains(v)  // CJK Ext-A
            || (0x4E00...0x9FFF).contains(v)  // CJK Unified Ideographs
            || (0xA960...0xA97F).contains(v)  // Hangul Jamo Ext-A
            || (0xAC00...0xD7AF).contains(v)  // Hangul Syllables
            || (0xF900...0xFAFF).contains(v)  // CJK Compat Ideographs
            || (0xFE30...0xFE4F).contains(v)  // CJK Compat Forms
            || (0xFF01...0xFF60).contains(v)  // Fullwidth Forms
            || (0xFFE0...0xFFE6).contains(v)  // Fullwidth Signs
            || (0x20000...0x2FA1F).contains(v) // CJK Ext-B + Compat Supplement
        {
            w += 2
        } else {
            w += 1
        }
    }
    return w
}

/// Join terminal-wrapped lines back into paragraphs.
/// Uses display width (CJK=2) to determine if a line was terminal-wrapped.
/// When terminal width is known (from Path A padding), uses that as threshold.
/// Otherwise falls back to display width ≥ 60.
func unwrapParagraphLines(_ text: String, terminalWidth: Int? = nil) -> String {
    let lines = text.components(separatedBy: "\n")
    guard lines.count >= 2 else { return text }

    // Threshold: if terminal width is known, a wrapped line's display width
    // should be near (terminalWidth - leading indent). After stripping the
    // 2-space indent, text area ≈ terminalWidth - 2. Lines wrap when they
    // fill ~50%+ of that area.
    let threshold = terminalWidth.map { max(($0 - 2) / 2, 40) } ?? 60

    var result: [String] = []
    var inCodeBlock = false

    for line in lines {
        // Track fenced code blocks
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("```") {
            inCodeBlock = !inCodeBlock
            result.append(line)
            continue
        }

        if inCodeBlock {
            result.append(line)
            continue
        }

        let shouldJoin = !result.isEmpty
            && !result.last!.isEmpty
            && !line.isEmpty
            && displayWidth(result.last!) >= threshold
            && !isStructuralLine(line)

        if shouldJoin {
            result[result.count - 1] += " " + line
        } else {
            result.append(line)
        }
    }

    return result.joined(separator: "\n")
}

/// Lines that represent structural elements and should never be joined.
func isStructuralLine(_ line: String) -> Bool {
    let t = line.trimmingCharacters(in: .whitespaces)
    if t.isEmpty { return false }
    if t.hasPrefix("#") { return true }
    if t.hasPrefix("- ") || t.hasPrefix("* ") || t.hasPrefix("+ ") { return true }
    if t.hasPrefix("> ") { return true }
    if t.hasPrefix("⏺") || t.hasPrefix("■") { return true }
    if t.hasPrefix("|") { return true }
    if t.hasPrefix("```") { return true }
    // Numbered list: "1. " or "1) "
    if let dot = t.firstIndex(of: "."), dot > t.startIndex,
       t[t.startIndex..<dot].allSatisfy({ $0.isNumber }),
       t.index(after: dot) < t.endIndex, t[t.index(after: dot)] == " " {
        return true
    }
    if let paren = t.firstIndex(of: ")"), paren > t.startIndex,
       t[t.startIndex..<paren].allSatisfy({ $0.isNumber }),
       t.index(after: paren) < t.endIndex, t[t.index(after: paren)] == " " {
        return true
    }
    return false
}

// MARK: - Path B: Leading 2-Space Pattern

/// 60%+ of non-empty lines have exactly 2 leading spaces (not 3+).
func hasLeadingTwoSpacePattern(_ lines: [String]) -> Bool {
    var twoSpaceCount = 0
    var nonEmptyCount = 0

    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { continue }
        nonEmptyCount += 1

        if line.hasPrefix("  ") && !line.hasPrefix("   ") {
            twoSpaceCount += 1
        }
    }

    guard twoSpaceCount >= 4 else { return false }
    return Double(twoSpaceCount) / Double(max(nonEmptyCount, 1)) >= 0.6
}
