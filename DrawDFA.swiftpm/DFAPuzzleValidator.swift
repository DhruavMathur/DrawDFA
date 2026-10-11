import Foundation

struct DFAPuzzleValidator {
    
    /// Normalizes regex pattern (removes backticks/slashes and anchors to entire string)
    static func normalizePattern(_ pattern: String) -> String {
        var clean = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.hasPrefix("`") && clean.hasSuffix("`") {
            clean = String(clean.dropFirst().dropLast())
        }
        if clean.hasPrefix("/") && clean.hasSuffix("/") {
            clean = String(clean.dropFirst().dropLast())
        }
        clean = clean.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.hasPrefix("^") { clean = "^" + clean }
        if !clean.hasSuffix("$") { clean = clean + "$" }
        return clean
    }
    
    /// Checks if a string satisfies a regex pattern. Returns nil if the pattern fails compilation.
    static func evaluateRegex(pattern: String, input: String) -> Bool? {
        let normalized = normalizePattern(pattern)
        guard let regex = try? NSRegularExpression(pattern: normalized) else {
            return nil
        }
        let range = NSRange(location: 0, length: (input as NSString).length)
        return regex.firstMatch(in: input, options: [], range: range) != nil
    }
    
    /// Detects known mathematically impossible (non-regular) rules that cannot be recognized by a DFA
    static func isPermissibleDFARule(rule: String) -> Bool {
        let lower = rule.lowercased()
        let forbidden = [
            "equal number",
            "same number of",
            "equal 0",
            "equal 1",
            "equal '0",
            "equal '1",
            "same count",
            "equal count",
            "palindrome",
            "balanced brackets",
            "0^n",
            "1^n"
        ]
        for term in forbidden {
            if lower.contains(term) {
                return false
            }
        }
        return true
    }
    
    /// Validates and synthesizes guaranteed consistent test strings.
    /// Filters candidate passing and failing strings against the regex.
    /// If fewer than `targetCount` strings exist for either set, synthesizes strings via BFS.
    static func validateAndSynthesize(
        regexPattern: String?,
        candidatePassing: [String],
        candidateFailing: [String],
        targetCount: Int = 3
    ) -> (passing: [String], failing: [String], isValidRegex: Bool) {
        guard let pattern = regexPattern, !pattern.isEmpty else {
            return (candidatePassing, candidateFailing, false)
        }
        
        let normalized = normalizePattern(pattern)
        guard let regex = try? NSRegularExpression(pattern: normalized) else {
            return (candidatePassing, candidateFailing, false)
        }
        
        func matches(_ s: String) -> Bool {
            let range = NSRange(location: 0, length: (s as NSString).length)
            return regex.firstMatch(in: s, options: [], range: range) != nil
        }
        
        // Sanitize candidates to binary characters only
        func sanitize(_ s: String) -> String {
            return s.trimmingCharacters(in: .whitespacesAndNewlines).filter { $0 == "0" || $0 == "1" }
        }
        
        var validPassing: [String] = []
        for s in candidatePassing {
            let clean = sanitize(s)
            if matches(clean) && !validPassing.contains(clean) {
                validPassing.append(clean)
            }
        }
        
        var validFailing: [String] = []
        for s in candidateFailing {
            let clean = sanitize(s)
            if !matches(clean) && !validFailing.contains(clean) {
                validFailing.append(clean)
            }
        }
        
        // BFS candidates pool over binary strings of lengths 1 to 5 (prioritize non-empty, then empty)
        let bfsPool: [String] = [
            "0", "1",
            "00", "01", "10", "11",
            "000", "001", "010", "011", "100", "101", "110", "111",
            "0000", "0001", "0010", "0011", "0100", "0101", "0110", "0111",
            "1000", "1001", "1010", "1011", "1100", "1101", "1110", "1111",
            ""
        ]
        
        // Synthesize missing passing strings
        if validPassing.count < targetCount {
            for candidate in bfsPool {
                if validPassing.count >= targetCount { break }
                if matches(candidate) && !validPassing.contains(candidate) && !validFailing.contains(candidate) {
                    validPassing.append(candidate)
                }
            }
        }
        
        // Synthesize missing failing strings
        if validFailing.count < targetCount {
            for candidate in bfsPool {
                if validFailing.count >= targetCount { break }
                if !matches(candidate) && !validFailing.contains(candidate) && !validPassing.contains(candidate) {
                    validFailing.append(candidate)
                }
            }
        }
        
        return (validPassing, validFailing, true)
    }
}
