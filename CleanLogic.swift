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

    let unwrapped = unwrapParagraphLines(cleaned)

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

/// Join terminal-wrapped lines back into paragraphs.
/// A line is joined to the previous when the previous line is long (≥60 chars,
/// suggesting it was wrapped by the terminal) and the current line is not a
/// structural element (list item, heading, code fence, etc.).
func unwrapParagraphLines(_ text: String) -> String {
    let lines = text.components(separatedBy: "\n")
    guard lines.count >= 2 else { return text }

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
            && result.last!.count >= 60
            && !isStructuralLine(line)
            && !isStructuralLine(result.last!)

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
