import SwiftUI

@MainActor
class MachineViewModel: ObservableObject {
    @Published var nodes: [StateNode] = []
    @Published var transitions: [Transition] = []
    
    
    @Published var simulationStatus: SimulationStatus = .idle
    @Published var currentActiveNodeID: UUID?
    @Published var currentActiveTransitionID: UUID?
    @Published var remainingInputString: String = ""
    @Published var testString: String = ""
    
    
    private var nodeCounter = 0
    
    
    @Published var drawStartNodeID: UUID?
    @Published var currentDragLocation: CGPoint?
    
    init() {
        
    }
    
    func addNode(at position: CGPoint) {
        let newNode = StateNode(
            name: "q\(nodeCounter)",
            position: position,
            isStartState: nodes.isEmpty,
            isAcceptingState: false
        )
        nodes.append(newNode)
        nodeCounter += 1
    }
    
    func toggleAcceptingState(for nodeID: UUID) {
        guard let index = nodes.firstIndex(where: { $0.id == nodeID }) else { return }
        nodes[index].isAcceptingState.toggle()
    }
    
    func setStartState(to nodeID: UUID) {
        for i in 0..<nodes.count {
            nodes[i].isStartState = (nodes[i].id == nodeID)
        }
    }
    
    func deleteNode(id: UUID) {
        
        transitions.removeAll(where: { $0.fromNodeID == id || $0.toNodeID == id })
        
        
        nodes.removeAll(where: { $0.id == id })
        
        
        if !nodes.isEmpty && !nodes.contains(where: { $0.isStartState }) {
            nodes[0].isStartState = true
        }
        
        
        resetSimulation()
    }
    
    func deleteTransition(id: UUID) {
        transitions.removeAll(where: { $0.id == id })
        resetSimulation()
    }
    
    func moveNode(id: UUID, to position: CGPoint) {
        guard let index = nodes.firstIndex(where: { $0.id == id }) else { return }
        nodes[index].position = position
    }
    
    func addTransition(from start: UUID, to end: UUID, symbols: [Character]) {
        
        
        let uniqueSymbols = Array(Set(symbols)).sorted()
        
        for sym in uniqueSymbols {
            
            for i in (0..<transitions.count).reversed() {
                if transitions[i].fromNodeID == start {
                    transitions[i].symbols.removeAll(where: { $0 == sym })
                    
                    if transitions[i].symbols.isEmpty {
                        transitions.remove(at: i)
                    }
                }
            }
        }
        
        guard !uniqueSymbols.isEmpty else { return }
        
        
        if let existingIndex = transitions.firstIndex(where: { $0.fromNodeID == start && $0.toNodeID == end }) {
            transitions[existingIndex].symbols.append(contentsOf: uniqueSymbols)
            transitions[existingIndex].symbols = Array(Set(transitions[existingIndex].symbols)).sorted()
        } else {
            let transition = Transition(fromNodeID: start, toNodeID: end, symbols: uniqueSymbols)
            transitions.append(transition)
        }
    }
    
    func loadDemo() {
        nodes.removeAll()
        transitions.removeAll()
        nodeCounter = 0
        
        
        let q0 = StateNode(name: "q0", position: CGPoint(x: 200, y: 300), isStartState: true, isAcceptingState: false)
        let q1 = StateNode(name: "q1", position: CGPoint(x: 400, y: 300), isStartState: false, isAcceptingState: false)
        let q2 = StateNode(name: "q2", position: CGPoint(x: 600, y: 300), isStartState: false, isAcceptingState: true)
        
        nodes = [q0, q1, q2]
        nodeCounter = 3
        
        
        transitions.append(Transition(fromNodeID: q0.id, toNodeID: q0.id, symbols: ["1"]))
        transitions.append(Transition(fromNodeID: q0.id, toNodeID: q1.id, symbols: ["0"]))
        
        transitions.append(Transition(fromNodeID: q1.id, toNodeID: q1.id, symbols: ["0"]))
        transitions.append(Transition(fromNodeID: q1.id, toNodeID: q2.id, symbols: ["1"]))
        
        
        transitions.append(Transition(fromNodeID: q2.id, toNodeID: q1.id, symbols: ["0"]))
        transitions.append(Transition(fromNodeID: q2.id, toNodeID: q0.id, symbols: ["1"]))
        
        testString = "1101"
        resetSimulation()
    }
    
    func resetSimulation() {
        simulationStatus = .idle
        currentActiveNodeID = nil
        currentActiveTransitionID = nil
        remainingInputString = ""
    }
    
    func playSimulation() async {
        guard simulationStatus != .running else { return }
        guard !testString.isEmpty else { return }
        
        resetSimulation()
        simulationStatus = .running
        remainingInputString = testString
        
        struct EngineResult {
            let steps: [SimulationStep]
            let status: SimulationStatus
        }
        
        
        let input = testString
        let currentNodes = nodes
        let currentTransitions = transitions
        
        let result = await Task.detached {
            let (steps, status) = AutomatonEngine.generateSteps(
                for: input,
                nodes: currentNodes,
                transitions: currentTransitions
            )
            return EngineResult(steps: steps, status: status)
        }.value
        
        
        for step in result.steps {
            
            guard simulationStatus == .running else { return } 
            
            withAnimation(.easeInOut(duration: 0.3)) {
                self.currentActiveNodeID = step.activeNodeID
                self.currentActiveTransitionID = step.activeTransitionID
                self.remainingInputString = step.remainingInput
            }
            
            
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        
        
        if simulationStatus == .running {
            withAnimation(.spring()) {
                simulationStatus = result.status
                self.currentActiveTransitionID = nil 
            }
        }
    }
}
