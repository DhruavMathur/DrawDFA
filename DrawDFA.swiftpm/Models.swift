import SwiftUI


struct StateNode: Identifiable, Equatable {
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


struct Transition: Identifiable, Equatable {
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
