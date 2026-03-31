// MARK: - Test Runner

var passed = 0
var failed = 0

func check(_ condition: Bool, _ msg: String, line: Int = #line) {
    if condition {
        passed += 1
        print("  ✅ \(msg)")
    } else {
        failed += 1
        print("  ❌ \(msg)  (line \(line))")
    }
}

func group(_ name: String, _ block: () -> Void) {
    print("\n\(name)")
    block()
}

// MARK: - Helpers

/// Add trailing spaces to each line (codepoint-based, for ASCII-heavy tests)
func pad(_ text: String, width: Int = 131) -> String {
    text.components(separatedBy: "\n").map { line in
        let len = line.count
        return len < width ? line + String(repeating: " ", count: width - len) : line
    }.joined(separator: "\n")
}

/// Add varied trailing spaces per line (simulates real terminal variance)
func addTrailing(_ lines: [String], counts: [Int]) -> String {
    zip(lines, counts).map { line, n in
        line + String(repeating: " ", count: n)
    }.joined(separator: "\n")
}

// MARK: - Path A: Trailing Padding

group("A1: Standard output — trailing + leading cleaned") {
    let input = pad("""
    ⏺ Project Status — Summary

      ■ Done
      1. Upload — file select
      2. Analysis — auto split
      3. Moderation — filtering
      4. Generation — output
      5. Progress — streaming
    """)
    let result = cleanClaudeOutput(input)
    check(result != nil, "detected")
    if let r = result {
        check(!r.contains("  ■"), "leading stripped")
        let hasTrailing = r.components(separatedBy: "\n").contains { $0.hasSuffix("   ") }
        check(!hasTrailing, "trailing stripped")
    }
}

group("A2: No ⏺, middle copy") {
    let input = pad("  3. Three\n  4. Four\n  5. Five\n  6. Six\n  7. Seven\n  8. Eight")
    let result = cleanClaudeOutput(input)
    check(result != nil, "detected without ⏺")
    if let r = result { check(r.hasPrefix("3."), "leading stripped") }
}

group("A3: Minimum 3 padded lines") {
    let input = pad("  ■ Done\n  1. Upload\n  2. Analysis")
    check(cleanClaudeOutput(input) != nil, "3-line minimum")
}

group("A4: Non-uniform trailing widths (CJK real case)") {
    // Simulates real terminal: CJK lines have fewer trailing spaces than ASCII lines
    // but all lines HAVE trailing spaces
    let input = addTrailing([
        "⏺ 프로젝트 현황",
        "  ■ 완료 (13/18)",
        "  1. 업로드 — 파일 선택",
        "  2. 분석 — AI 자동 분할",
        "  3. 모더레이션 — 필터링",
        "  4. 생성 — 정리본",
    ], counts: [98, 115, 28, 84, 40, 80])
    let result = cleanClaudeOutput(input)
    check(result != nil, "CJK with varied trailing detected")
    if let r = result {
        check(!r.hasSuffix(" "), "trailing stripped")
    }
}

group("A5: All-space blank lines → empty") {
    let blank = String(repeating: " ", count: 80)
    let input = [
        "⏺ Title" + String(repeating: " ", count: 73),
        blank,
        "  ■ Section" + String(repeating: " ", count: 69),
        "  1. Item" + String(repeating: " ", count: 71),
        blank,
        "  2. Item" + String(repeating: " ", count: 71),
    ].joined(separator: "\n")
    let result = cleanClaudeOutput(input)
    check(result != nil, "detected")
    if let r = result {
        check(r.components(separatedBy: "\n").filter({ $0.isEmpty }).count >= 2, "blank lines cleaned")
    }
}

// MARK: - Path B: Leading 2-Space

group("B1: Claude response text — leading 2-space only") {
    let input = "⏺ Build complete.\n\n  ~/project/\n  - One\n  - Two\n  - Three\n  - Four\n  - Five"
    let result = cleanClaudeOutput(input)
    check(result != nil, "detected via leading 2-space")
    if let r = result {
        check(!r.contains("  ~/"), "leading stripped")
        check(r.contains("⏺"), "⏺ preserved")
    }
}

group("B2: No ⏺, leading 2-space only") {
    let input = "  - First\n  - Second\n  - Third\n  - Fourth\n  - Fifth"
    let result = cleanClaudeOutput(input)
    check(result != nil, "detected without ⏺")
    if let r = result { check(r.hasPrefix("- First"), "leading stripped") }
}

group("B3: Below 4-line threshold") {
    check(cleanClaudeOutput("  - One\n  - Two\n  - Three") == nil, "rejected")
}

group("B4: Mixed-depth code rejected") {
    let input = "function hello() {\n  console.log(\"hi\");\n  if (true) {\n    return 42;\n  }\n}"
    check(cleanClaudeOutput(input) == nil, "code rejected")
}

group("B5: Below 60% ratio") {
    let input = "Title\nAnother\nThird\n  - One\n  - Two\n  - Three\n  - Four\nFooter\nMore\nEnd"
    check(cleanClaudeOutput(input) == nil, "40% rejected")
}

// MARK: - Negatives

group("N1: Plain text") {
    check(cleanClaudeOutput("Hello world\nNormal text\nNo patterns\nJust content") == nil, "plain text")
}

group("N2: ⏺ alone") {
    check(cleanClaudeOutput("⏺ Title\nFirst line\nSecond line\nThird line") == nil, "⏺ alone not enough")
}

group("N3: Too short") {
    check(cleanClaudeOutput("") == nil, "empty")
    check(cleanClaudeOutput("one line") == nil, "1 line")
    check(cleanClaudeOutput("one\ntwo") == nil, "2 lines")
}

group("N4: Markdown") {
    check(cleanClaudeOutput("# Title\n\nParagraph.\n\n- One\n- Two\n- Three\n\n## Next") == nil, "markdown")
}

// MARK: - Edge Cases

group("E1: Below both thresholds") {
    let input = "⏺ Title  \n  Line one \n  Line two  \n  Line three "
    check(cleanClaudeOutput(input) == nil, "below both paths")
}

group("E2: Some lines unpadded, but enough ratio") {
    let w = 100
    let input = [
        "⏺ Title" + String(repeating: " ", count: w - 7),
        String(repeating: " ", count: w),
        "  Line one" + String(repeating: " ", count: w - 10),
        "  Short",
        "  Line three" + String(repeating: " ", count: w - 12),
        "  Line four" + String(repeating: " ", count: w - 11),
        "  Line five" + String(repeating: " ", count: w - 11),
    ].joined(separator: "\n")
    let result = cleanClaudeOutput(input)
    check(result != nil, "partial padding detected")
    if let r = result { check(r.contains("Short"), "unpadded line preserved") }
}

// MARK: - Results

print("\n" + String(repeating: "─", count: 40))
print("Results: \(passed) passed, \(failed) failed")
if failed > 0 {
    print("⚠️  SOME TESTS FAILED")
    exit(1)
} else {
    print("✅ ALL TESTS PASSED")
    exit(0)
}
