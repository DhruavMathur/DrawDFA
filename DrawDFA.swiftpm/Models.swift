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
}

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, *)
@Generable
struct AIDFALevel {
    @Guide(description: "A short, catchy title for the question")
    var title: String
    @Guide(description: "The exact question / rule the DFA must enforce")
    var ruleDescription: String
    @Guide(description: "3 binary strings that strictly pass the rule", .count(3))
    var passingStrings: [String]
    @Guide(description: "3 binary strings that strictly fail the rule", .count(3))
    var failingStrings: [String]
    
    func toDFALevel(id: Int) -> DFALevel {
        return DFALevel(
            id: id,
            title: title,
            ruleDescription: ruleDescription,
            passingStrings: passingStrings,
            failingStrings: failingStrings
        )
    }
}
#endif
