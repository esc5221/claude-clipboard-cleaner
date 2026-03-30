import Foundation

// MARK: - Detection & Cleaning (testable, no AppKit dependency)

/// Detect Claude Code output and clean it.
/// Two independent detection paths:
///   Path A: Uniform trailing space padding → strip trailing + leading 2-space
///   Path B: Consistent leading 2-space pattern → strip leading 2-space only
func cleanClaudeOutput(_ text: String) -> String? {
    let lines = text.components(separatedBy: "\n")
    guard lines.count >= 3 else { return nil }

    let hasPadding = hasUniformTrailingPadding(lines)
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

    return cleaned != text ? cleaned : nil
}

// MARK: - Path A: Trailing Space Padding

/// Lines padded with trailing spaces to a UNIFORM total width.
/// Unique to terminal copy — normal text never has this pattern.
///
/// Conditions (AND):
///   1. 3+ lines have trailing space padding (≥3 spaces)
///   2. 70%+ of those padded lines share the same total width (±3 chars)
///   3. Padded lines are ≥40% of all non-empty lines
func hasUniformTrailingPadding(_ lines: [String]) -> Bool {
    var paddedLengths: [Int] = []
    var totalNonEmpty = 0

    for line in lines {
        guard !line.isEmpty else { continue }

        if let lastNonSpace = line.lastIndex(where: { $0 != " " }) {
            let contentLen = line.distance(from: line.startIndex, to: lastNonSpace) + 1
            let trailingSpaces = line.count - contentLen
            totalNonEmpty += 1
            if trailingSpaces >= 3 {
                paddedLengths.append(line.count)
            }
        } else {
            paddedLengths.append(line.count)
        }
    }

    guard paddedLengths.count >= 3 else { return false }

    let sorted = paddedLengths.sorted()
    let median = sorted[sorted.count / 2]
    let uniformCount = paddedLengths.filter { abs($0 - median) <= 3 }.count
    let uniformRatio = Double(uniformCount) / Double(paddedLengths.count)
    guard uniformRatio >= 0.7 else { return false }

    let paddingRatio = Double(paddedLengths.count) / Double(max(totalNonEmpty, 1))
    guard paddingRatio >= 0.4 else { return false }

    return true
}

// MARK: - Path B: Leading 2-Space Pattern

/// Consistent leading 2-space indentation without trailing padding.
/// Claude responses render content with 2-space indent.
///
/// Conditions (AND):
///   1. 4+ lines have exactly 2 leading spaces (not 3+)
///   2. 60%+ of non-empty lines have exactly 2 leading spaces
func hasLeadingTwoSpacePattern(_ lines: [String]) -> Bool {
    var twoSpaceCount = 0
    var nonEmptyCount = 0

    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { continue }
        nonEmptyCount += 1

        // Exactly 2 leading spaces (not 3+)
        if line.hasPrefix("  ") && !line.hasPrefix("   ") {
            twoSpaceCount += 1
        }
    }

    guard twoSpaceCount >= 4 else { return false }
    let ratio = Double(twoSpaceCount) / Double(max(nonEmptyCount, 1))
    return ratio >= 0.6
}
