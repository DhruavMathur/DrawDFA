import Foundation
import SwiftUI

enum CloudProviderType: String, CaseIterable, Identifiable {
    case gemini = "Google Gemini"
    case openAI = "OpenAI Compatible"
    
    var id: String { rawValue }
}

struct CloudVerificationResult: Codable {
    var isRegularLanguage: Bool
    var refinedTitle: String
    var refinedRule: String
    var regexPattern: String
    var passingStrings: [String]
    var failingStrings: [String]
    var explanation: String?
}

@MainActor
class CloudLLMService: ObservableObject {
    static let shared = CloudLLMService()
    
    var isEnabled: Bool = true
    var providerType: CloudProviderType = .openAI
    var apiKey: String = ""
    var customEndpoint: String = "https://api.groq.com/openai/v1/chat/completions"
    var modelName: String = "openai/gpt-oss-20b"
    
    var isConfigured: Bool {
        return isEnabled && !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Sends proposed DFA question or generates a creative puzzle using the Cloud LLM
    func verifyAndGenerateTestCases(
        proposedTitle: String? = nil,
        proposedRule: String? = nil,
        categoryHint: String? = nil,
        recentTitles: [String] = []
    ) async throws -> CloudVerificationResult {
        guard isConfigured else {
            throw NSError(domain: "CloudLLMService", code: 400, userInfo: [NSLocalizedDescriptionKey: "API Key is not configured."])
        }
        
        let exclusionText = recentTitles.isEmpty ? "None" : recentTitles.map { "• \($0)" }.joined(separator: "\n")
        let categoryText = categoryHint ?? "Choose a random distinct category: Substring Exclusion, Modulo/Parity, Positional, Prefix/Suffix, or Bounds."
        
        let prompt: String
        if let title = proposedTitle, let rule = proposedRule {
            prompt = """
            You are a theoretical computer science professor and formal language expert specializing in Deterministic Finite Automata (DFA).
            The DFA alphabet is strictly binary: {0, 1}.
            
            A game designer proposed the following DFA puzzle:
            Title: "\(title)"
            Proposed Rule: "\(rule)"
            
            AVOID REPETITION:
            Do NOT generate anything similar to these recent puzzles:
            \(exclusionText)
            
            CRITICAL TASK:
            1. Check whether this rule defines a REGULAR language (solvable by a finite-state machine).
               - Reminder: Counting unbounded symbols (e.g. "equal 0s and 1s", "same count of 0 and 1"), palindromes, or 0^n 1^n are NOT regular languages.
               - If the rule is NOT regular, adapt it to the closest valid REGULAR language.
            2. Provide a mathematically exact regular expression 'regexPattern' over {0,1} anchored with ^ and $ matching the language.
            3. Provide 3 unique binary strings that 100% pass the rule and match the regex.
            4. Provide 3 unique binary strings that 100% fail the rule and do NOT match the regex.
            
            Return your answer as a JSON object with this exact schema:
            {
              "isRegularLanguage": boolean,
              "refinedTitle": "string",
              "refinedRule": "string (clear player-facing instruction)",
              "regexPattern": "string (e.g. ^[01]*01$)",
              "passingStrings": ["string", "string", "string"],
              "failingStrings": ["string", "string", "string"],
              "explanation": "string (brief note on how rule is regular and why test cases work)"
            }
            """
        } else {
            prompt = """
            You are a puzzle game designer and theoretical computer science professor creating Deterministic Finite Automaton (DFA) logic puzzles.
            The DFA alphabet is strictly binary: {0, 1}.
            
            GOAL:
            Design a FRESH, CREATIVE, and UNAMBIGUOUS DFA logic puzzle over {0, 1}.
            
            CATEGORY FOCUS:
            \(categoryText)
            
            STRICT EXCLUSION RULE:
            Do NOT generate any puzzle similar to these recent puzzles:
            \(exclusionText)
            You must explore a DIFFERENT concept or pattern!
            
            CRITICAL REQUIREMENTS:
            1. The rule MUST define a REGULAR language (solvable by a finite-state machine).
               - NEVER propose non-regular languages: no palindromes, no equal counts of 0 and 1, no unbounded counting.
            2. Provide a mathematically exact regular expression 'regexPattern' over {0,1} anchored with ^ and $ matching the language.
            3. Provide 3 unique binary strings that 100% pass the rule and match the regex.
            4. Provide 3 unique binary strings that 100% fail the rule and do NOT match the regex.
            
            Return your answer as a JSON object with this exact schema:
            {
              "isRegularLanguage": boolean,
              "refinedTitle": "string (catchy, descriptive name)",
              "refinedRule": "string (clear player-facing instruction)",
              "regexPattern": "string (anchored with ^ and $)",
              "passingStrings": ["string", "string", "string"],
              "failingStrings": ["string", "string", "string"],
              "explanation": "string (brief note on DFA states and why test cases work)"
            }
            """
        }
        
        switch providerType {
        case .gemini:
            return try await callGeminiAPI(prompt: prompt)
        case .openAI:
            return try await callOpenAIAPI(prompt: prompt)
        }
    }
    
    private func callGeminiAPI(prompt: String) async throws -> CloudVerificationResult {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveModel = modelName.isEmpty ? "gemini-2.5-flash" : modelName
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(effectiveModel):generateContent?key=\(key)") else {
            throw NSError(domain: "CloudLLMService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid Gemini URL."])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ],
            "generationConfig": [
                "responseMimeType": "application/json"
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "CloudLLMService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid server response."])
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw NSError(domain: "CloudLLMService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Gemini API Error: \(errorText)"])
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw NSError(domain: "CloudLLMService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to parse Gemini response structure."])
        }
        
        guard let resultData = text.data(using: .utf8) else {
            throw NSError(domain: "CloudLLMService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Empty Gemini text response."])
        }
        
        return try JSONDecoder().decode(CloudVerificationResult.self, from: resultData)
    }
    
    private func callOpenAIAPI(prompt: String) async throws -> CloudVerificationResult {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: customEndpoint) else {
            throw NSError(domain: "CloudLLMService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid Custom Endpoint URL."])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        
        let payload: [String: Any] = [
            "model": modelName.isEmpty ? "gpt-4o-mini" : modelName,
            "response_format": ["type": "json_object"],
            "temperature": 0.75,
            "messages": [
                [
                    "role": "system",
                    "content": "You are a theoretical computer science expert in automata theory. You return strict JSON matching the requested schema."
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "CloudLLMService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid server response."])
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw NSError(domain: "CloudLLMService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API Error: \(errorText)"])
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw NSError(domain: "CloudLLMService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to parse API response structure."])
        }
        
        guard let resultData = content.data(using: .utf8) else {
            throw NSError(domain: "CloudLLMService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Empty message content."])
        }
        
        print("====== CLOUD LLM RAW RESPONSE ======")
        print(content)
        print("====================================")
        
        return try JSONDecoder().decode(CloudVerificationResult.self, from: resultData)
    }
    
    /// Quick connection test
    func testConnection() async -> (success: Bool, message: String) {
        do {
            let result = try await verifyAndGenerateTestCases(
                proposedTitle: "Test Check",
                proposedRule: "Strings that end in 01"
            )
            return (true, "Connected! Rule: '\(result.refinedRule)', Regex: '\(result.regexPattern)'")
        } catch {
            return (false, error.localizedDescription)
        }
    }
}
