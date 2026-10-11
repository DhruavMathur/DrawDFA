import SwiftUI


struct StateNode: Identifiable, Equatable, Codable {
    let id: UUID
    var name: String
    var position: CGPoint
    var isStartState: Bool
    var isAcceptingState: Bool
    
    init(id: UUID = UUID(), name: String, position: CGPoint, isStartState: Bool = false, isAcceptingState: Bool = false) {
        self.id = id
        self.name = name
        self.position = position
        self.isStartState = isStartState
        self.isAcceptingState = isAcceptingState
    }
}


struct Transition: Identifiable, Equatable, Codable {
    let id: UUID
    var fromNodeID: UUID
    var toNodeID: UUID
    var symbols: [Character]
    
    init(id: UUID = UUID(), fromNodeID: UUID, toNodeID: UUID, symbols: [Character]) {
        self.id = id
        self.fromNodeID = fromNodeID
        self.toNodeID = toNodeID
        self.symbols = symbols
    }
    
    enum CodingKeys: String, CodingKey {
        case id, fromNodeID, toNodeID, symbolStrings
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        fromNodeID = try container.decode(UUID.self, forKey: .fromNodeID)
        toNodeID = try container.decode(UUID.self, forKey: .toNodeID)
        let strings = try container.decode([String].self, forKey: .symbolStrings)
        symbols = strings.compactMap { $0.first }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(fromNodeID, forKey: .fromNodeID)
        try container.encode(toNodeID, forKey: .toNodeID)
        try container.encode(symbols.map { String($0) }, forKey: .symbolStrings)
    }
}

struct SavedDFASolution: Identifiable, Codable, Equatable {
    var id: UUID
    var level: DFALevel
    var nodes: [StateNode]
    var transitions: [Transition]
    var completedAt: Date
    
    init(id: UUID = UUID(), level: DFALevel, nodes: [StateNode], transitions: [Transition], completedAt: Date = Date()) {
        self.id = id
        self.level = level
        self.nodes = nodes
        self.transitions = transitions
        self.completedAt = completedAt
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: completedAt)
    }
}


enum SimulationStatus: Equatable {
    case idle
    case running
    case success
    case failure(reason: String)
}


struct SimulationStep {
    let activeNodeID: UUID
    let activeTransitionID: UUID?
    let remainingInput: String
    let currentIndex: Int
}

struct DFALevel: Codable, Equatable, Identifiable {
    var id: Int
    var title: String
    var ruleDescription: String
    var passingStrings: [String]
    var failingStrings: [String]
    var regexPattern: String?
    
    init(id: Int, title: String, ruleDescription: String, passingStrings: [String], failingStrings: [String], regexPattern: String? = nil) {
        self.id = id
        self.title = title
        self.ruleDescription = ruleDescription
        self.passingStrings = passingStrings
        self.failingStrings = failingStrings
        self.regexPattern = regexPattern
    }
}

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, *)
@Generable
struct AIDFALevel {
    @Guide(description: "A short, catchy title for the question")
    var title: String
    
    @Guide(description: "A simple, mathematically rigorous rule for binary strings (e.g., 'must contain 101', 'ends with 01')")
    var ruleDescription: String
    
    @Guide(description: "A standard regular expression anchored with ^ and $ matching all binary strings over {0,1} that satisfy the rule. E.g. '^[01]*01$' for ends with 01, or '^[01]*11[01]*$' for contains 11.")
    var regexPattern: String
    
    @Guide(description: "Before generating the strings, write out a brief step-by-step proof explaining exactly why your chosen passing strings mathematically satisfy the rule, and why your failing strings fail.")
    var stepByStepProof: String
    
    @Guide(description: "3 unique binary strings that 100% satisfy the rule. Double-check these carefully against the regex.", .count(3))
    var passingStrings: [String]
    
    @Guide(description: "3 unique binary strings that absolutely DO NOT satisfy the rule. Double-check these carefully against the regex.", .count(3))
    var failingStrings: [String]
    
    func toDFALevel(id: Int) -> DFALevel {
        return DFALevel(
            id: id,
            title: title,
            ruleDescription: ruleDescription,
            passingStrings: passingStrings,
            failingStrings: failingStrings,
            regexPattern: regexPattern
        )
    }
}
#endif
