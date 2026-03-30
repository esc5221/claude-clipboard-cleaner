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

func pad(_ text: String, width: Int = 131) -> String {
    text.components(separatedBy: "\n").map { line in
        let len = line.count
        return len < width ? line + String(repeating: " ", count: width - len) : line
    }.joined(separator: "\n")
}

func padJittered(_ text: String, width: Int = 131, delta: Int = 2) -> String {
    var i = 0
    return text.components(separatedBy: "\n").map { line in
        let offset = (i % 3 == 0) ? -delta : (i % 3 == 1) ? 0 : delta
        i += 1
        let target = width + offset
        let len = line.count
        return len < target ? line + String(repeating: " ", count: target - len) : line
    }.joined(separator: "\n")
}

// MARK: - Path A: Trailing Padding

group("A1: Standard output — detect + clean both trailing & leading") {
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
        check(!r.contains("  ■"), "leading 2-space removed")
        let hasTrailing = r.components(separatedBy: "\n").contains { $0.count - $0.reversed().drop(while: { $0 == " " }).count >= 10 }
        check(!hasTrailing, "trailing padding removed")
    }
}

group("A2: No ⏺, uniform padding — middle copy") {
    let input = pad("""
      3. Item three
      4. Item four
      5. Item five
      6. Item six
      7. Item seven
      8. Item eight
    """)
    let result = cleanClaudeOutput(input)
    check(result != nil, "detected without ⏺")
    if let r = result { check(r.hasPrefix("3."), "leading stripped") }
}

group("A3: Minimum 3 padded lines") {
    let input = pad("  ■ Done\n  1. Upload\n  2. Analysis")
    check(cleanClaudeOutput(input) != nil, "3-line minimum works")
}

group("A4: Different terminal width (80-col)") {
    let input = pad("⏺ Title\n\n  - One\n  - Two\n  - Three\n  - Four", width: 80)
    check(cleanClaudeOutput(input) != nil, "width-agnostic")
}

group("A5: Width jitter ±2") {
    let input = padJittered("⏺ Title\n\n  One\n  Two\n  Three\n  Four\n  Five", width: 131, delta: 2)
    check(cleanClaudeOutput(input) != nil, "tolerates jitter")
}

group("A6: All-space blank lines → empty lines") {
    let w = 131
    let blank = String(repeating: " ", count: w)
    let input = [
        "⏺ Title" + String(repeating: " ", count: w - 7),
        blank,
        "  ■ Section" + String(repeating: " ", count: w - 11),
        "  1. Item" + String(repeating: " ", count: w - 9),
        blank,
        "  2. Item" + String(repeating: " ", count: w - 9),
    ].joined(separator: "\n")
    let result = cleanClaudeOutput(input)
    check(result != nil, "detected")
    if let r = result {
        check(r.components(separatedBy: "\n").filter({ $0.isEmpty }).count >= 2, "blank lines cleaned")
    }
}

// MARK: - Path B: Leading 2-Space (no trailing padding)

group("B1: Claude response text — leading 2-space only") {
    let input = "⏺ Build complete.\n\n  ~/project/\n  - One\n  - Two\n  - Three\n  - Four\n  - Five"
    let result = cleanClaudeOutput(input)
    check(result != nil, "detected via leading 2-space")
    if let r = result {
        check(!r.contains("  ~/"), "leading stripped")
        check(r.contains("⏺"), "⏺ line preserved (0 leading)")
    }
}

group("B2: No ⏺, leading 2-space only — middle copy") {
    let input = "  - First\n  - Second\n  - Third\n  - Fourth\n  - Fifth"
    let result = cleanClaudeOutput(input)
    check(result != nil, "detected without ⏺")
    if let r = result { check(r.hasPrefix("- First"), "leading stripped") }
}

group("B3: Below 4-line threshold") {
    check(cleanClaudeOutput("  - One\n  - Two\n  - Three") == nil, "3 lines rejected")
}

group("B4: Mixed-depth code (2+4 space) rejected") {
    let input = "function hello() {\n  console.log(\"hi\");\n  if (true) {\n    return 42;\n  }\n}"
    check(cleanClaudeOutput(input) == nil, "code rejected")
}

group("B5: Below 60% ratio") {
    let input = "Title\nAnother\nThird\n  - One\n  - Two\n  - Three\n  - Four\nFooter\nMore\nEnd"
    check(cleanClaudeOutput(input) == nil, "40% ratio rejected")
}

// MARK: - Negatives

group("N1: Plain text") {
    check(cleanClaudeOutput("Hello world\nNormal text\nNo patterns\nJust content") == nil, "plain text")
}

group("N2: ⏺ alone, no padding or leading pattern") {
    check(cleanClaudeOutput("⏺ Title\nFirst line\nSecond line\nThird line") == nil, "⏺ alone not enough")
}

group("N3: Non-uniform trailing padding") {
    let input = [
        "Line one" + String(repeating: " ", count: 50),
        "Line two" + String(repeating: " ", count: 20),
        "Line three" + String(repeating: " ", count: 80),
        "Line four" + String(repeating: " ", count: 35),
        "Line five" + String(repeating: " ", count: 60),
    ].joined(separator: "\n")
    check(cleanClaudeOutput(input) == nil, "non-uniform rejected")
}

group("N4: Too short (empty / 1 / 2 lines)") {
    check(cleanClaudeOutput("") == nil, "empty")
    check(cleanClaudeOutput("one line") == nil, "1 line")
    check(cleanClaudeOutput("one\ntwo") == nil, "2 lines")
}

group("N5: Markdown") {
    check(cleanClaudeOutput("# Title\n\nParagraph.\n\n- One\n- Two\n- Three\n\n## Next") == nil, "markdown")
}

// MARK: - Edge Cases

group("E1: Below both thresholds") {
    let input = "⏺ Title  \n  Line one \n  Line two  \n  Line three "
    check(cleanClaudeOutput(input) == nil, "below both paths")
}

group("E2: Partial padding — some lines unpadded") {
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

group("E3: Unicode with padding") {
    let input = pad("  한글 라인 1\n  日本語 2\n  English 3\n  中文 4", width: 131)
    check(cleanClaudeOutput(input) != nil, "Unicode detected")
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
