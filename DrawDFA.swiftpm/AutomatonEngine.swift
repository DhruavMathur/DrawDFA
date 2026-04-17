import Foundation


struct AutomatonEngine {
    

    static func generateSteps(
        for input: String,
        nodes: [StateNode],
        transitions: [Transition]
    ) -> (steps: [SimulationStep], status: SimulationStatus) {
        
        guard let startNode = nodes.first(where: { $0.isStartState }) else {
            return ([], .failure(reason: "No Start State defined."))
        }
        
        var currentSteps: [SimulationStep] = []
        var currentNodeID = startNode.id
        
        // Initial state before reading any input
        currentSteps.append(SimulationStep(
            activeNodeID: currentNodeID,
            activeTransitionID: nil,
            remainingInput: input,
            currentIndex: 0
        ))
        
        let characters = Array(input)
        
        for (index, char) in characters.enumerated() {
            // Find a valid transition from the current node with the current symbol
            let validTransitions = transitions.filter { $0.fromNodeID == currentNodeID && $0.symbols.contains(char) }
            
            guard let nextTransition = validTransitions.first else {
                return (currentSteps, .failure(reason: "No valid transition for '\(char)' from current state."))
            }
            
            // Deterministic check: DFA can only have one transition per symbol
            if validTransitions.count > 1 {
                return (currentSteps, .failure(reason: "Non-Deterministic! Multiple transitions for '\(char)'."))
            }
            
            currentNodeID = nextTransition.toNodeID
            
            currentSteps.append(SimulationStep(
                activeNodeID: currentNodeID,
                activeTransitionID: nextTransition.id,
                remainingInput: String(characters[(index + 1)...]),
                currentIndex: index + 1
            ))
        }
        
        // Check final state
        if let finalNode = nodes.first(where: { $0.id == currentNodeID }), finalNode.isAcceptingState {
            return (currentSteps, .success)
        } else {
            return (currentSteps, .failure(reason: "Machine finished on a non-accepting state."))
        }
    }
    
    static func evaluate(
        input: String,
        nodes: [StateNode],
        transitions: [Transition]
    ) -> Bool {
        guard let startNode = nodes.first(where: { $0.isStartState }) else { return false }
        
        var currentNodeID = startNode.id
        
        for char in input {
            let validTransitions = transitions.filter { $0.fromNodeID == currentNodeID && $0.symbols.contains(char) }
            
            guard validTransitions.count == 1, let nextTransition = validTransitions.first else {
                return false
            }
            
            currentNodeID = nextTransition.toNodeID
        }
        
        return nodes.first(where: { $0.id == currentNodeID })?.isAcceptingState ?? false
    }
}
