import Foundation
func getCutOffIndexForTTSQueue(in input: String, isFirstChunk: Bool = false) -> Int {
    // Different limits for first vs subsequent chunks
    let maxCharLen = isFirstChunk ? 200 : 120  // Longer first chunk, shorter subsequent
    let minCharLen = isFirstChunk ? 120 : 35   // Higher minimum for first, lower for subsequent
    let limit = min(input.count, maxCharLen)
    
    if limit <= minCharLen {
        return limit - 1
    }
    
    let characters = Array(input.prefix(limit))
    let text = String(characters)
    
    // Search from ideal position (75% of max length) backwards for best break
    let idealPosition = min(Int(Double(maxCharLen) * 0.75), limit - 1)
    
    // Safety check: ensure idealPosition is not less than minCharLen to avoid invalid ranges
    let safeIdealPosition = max(idealPosition, minCharLen)
    
    // PRIORITY 0: Structured content breaks - section headers, list boundaries
    // Look for markdown headers like "**Blend 1:**" or "**Section:**"
    let headerPattern = "\\*\\*[^*]+\\*\\*"
    if let regex = try? NSRegularExpression(pattern: headerPattern, options: []) {
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
        for match in matches.reversed() {
            let endIndex = match.range.location + match.range.length
            if endIndex >= minCharLen && endIndex <= safeIdealPosition {
                // Check if there's a line break or colon after the header
                if endIndex < text.count {
                    let nextChar = text[text.index(text.startIndex, offsetBy: endIndex)]
                    if nextChar == "\n" || nextChar == ":" {
                        return endIndex + 1
                    }
                }
                return endIndex
            }
        }
    }
    
    // PRIORITY 0.5: Double line breaks (paragraph/section separators)
    if let range = text.range(of: "\n\n", options: [.backwards]) {
        let index = text.distance(from: text.startIndex, to: range.upperBound)
        if index >= minCharLen && index <= safeIdealPosition {
            return index
        }
    }
    
    // PRIORITY 0.7: End of bullet point lists (before section headers)
    // Look for pattern: "* item\n\n**" or "* item\n**"
    let bulletEndPattern = "\\*[^\n]+\n(?:\n)?\\*\\*"
    if let regex = try? NSRegularExpression(pattern: bulletEndPattern, options: []) {
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
        for match in matches.reversed() {
            let breakIndex = match.range.location + match.range.length - 2 // Before the "**"
            if breakIndex >= minCharLen && breakIndex <= safeIdealPosition {
                return breakIndex
            }
        }
    }
    
    // PRIORITY 0.8: Single line breaks before section headers
    if let range = text.range(of: "\n**", options: [.backwards]) {
        let index = text.distance(from: text.startIndex, to: range.lowerBound) + 1
        if index >= minCharLen && index <= safeIdealPosition {
            return index
        }
    }
    
    // PRIORITY 1: Strong sentence breaks (period, exclamation, question)
    let strongBreaks: Set<Character> = [".", "!", "?"]
    
    // PRIORITY 2: Clause breaks (comma, semicolon, colon)
    let clauseBreaks: Set<Character> = [",", ";", ":"]
    
    // PRIORITY 3: Natural pauses (dash, parentheses)
    let naturalPauses: Set<Character> = ["-", "—", "(", ")", "[", "]"]
    
    // PRIORITY 4: Conjunctions and connecting words (look for " and ", " or ", " but ", etc.)
    let conjunctions = [" and ", " or ", " but ", " so ", " yet ", " for ", " nor ", " because ", " since ", " while ", " although ", " however ", " therefore ", " moreover "]
    
    // Priority 1: Look for strong sentence breaks near ideal position
    for i in (minCharLen...safeIdealPosition).reversed() {
        let char = characters[i]
        if char == "." {
            let isPreviousDigit = i > 0 && characters[i - 1].isNumber
            let isNextDigit = i + 1 < characters.count && characters[i + 1].isNumber
            if !(isPreviousDigit && isNextDigit) {
                // Ensure we don't break on abbreviations like "Mr." or "etc."
                if i + 2 < characters.count && characters[i + 1] == " " && characters[i + 2].isUppercase {
                    return i + 1 // Include the space after period
                } else if i + 1 < characters.count && characters[i + 1] == " " {
                    return i + 1
                }
                return i
            }
        } else if strongBreaks.contains(char) {
            return i + 1 < characters.count && characters[i + 1] == " " ? i + 1 : i
        }
    }
    
    // Priority 2: Look for clause breaks
    for i in (minCharLen...safeIdealPosition).reversed() {
        let char = characters[i]
        if clauseBreaks.contains(char) {
            return i + 1 < characters.count && characters[i + 1] == " " ? i + 1 : i
        }
    }
    
    // Priority 3: Look for natural pauses
    for i in (minCharLen...safeIdealPosition).reversed() {
        let char = characters[i]
        if naturalPauses.contains(char) {
            return i
        }
    }
    
    // Priority 4: Look for conjunctions
    for conjunction in conjunctions {
        if let range = text.range(of: conjunction, options: [.backwards, .caseInsensitive]) {
            let index = text.distance(from: text.startIndex, to: range.lowerBound)
            if index >= minCharLen && index <= safeIdealPosition {
                return index
            }
        }
    }
    
    // Priority 5: Look for word boundaries (spaces) near ideal position
    for i in (minCharLen...safeIdealPosition).reversed() {
        if characters[i] == " " && i > 0 && !characters[i - 1].isWhitespace {
            return i
        }
    }
    
    // Priority 6: NEVER break in the middle of words - find ANY space, even below minCharLen
    // First try within the normal range
    for i in (minCharLen...limit - 1).reversed() {
        if characters[i] == " " {
            return i
        }
    }
    
    // If no space found in normal range, search backwards from minCharLen to find ANY space
    // This ensures we never cut in the middle of a word, even if it means a shorter chunk
    for i in (0..<minCharLen).reversed() {
        if characters[i] == " " {
            print("[Chunking] WARNING: Had to go below minCharLen to find space at index \(i)")
            return i
        }
    }
    
    // Absolute last resort: if somehow no spaces exist at all (very rare edge case)
    // Find the last character that's not alphanumeric to avoid breaking words
    for i in (0...limit - 1).reversed() {
        let char = characters[i]
        if !char.isLetter && !char.isNumber {
            print("[Chunking] WARNING: No spaces found, breaking at non-alphanumeric char at index \(i)")
            return i
        }
    }
    
    // Ultimate fallback - should almost never happen
    print("[Chunking] CRITICAL: No safe break points found, using limit - 1")
    return limit - 1
}
