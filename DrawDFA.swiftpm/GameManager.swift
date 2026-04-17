import SwiftUI
import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

enum GameMode: String, CaseIterable {
    case campaign = "Campaign Mode"
    case endlessAI = "Endless AI Mode"
    case blankCanvas = "Blank Canvas"
}

enum TestResult {
    case passed
    case failed
    case pending
}

@MainActor
class GameManager: ObservableObject {
    @Published var currentMode: GameMode = .campaign
    @Published var currentLevel: DFALevel?
    @Published var testResults: [String: TestResult] = [:]
    
    @Published var campaignIndex = 0
    @Published var isGeneratingAILevel = false
    @Published var wasGeneratedByAI = false
    
    @Published var isLiveTesting = false
    @Published var currentLiveTestResult: (string: String, passed: Bool)? = nil
    
    private let campaignLevels: [DFALevel] = [
        DFALevel(
            id: 0,
            title: "Level 1: The Basics (Ends in '01')",
            ruleDescription: "Draw a DFA that accepts strings ending in '01'.",
            passingStrings: ["01", "101", "001"],
            failingStrings: ["0", "11", "10"]
        ),
        DFALevel(
            id: 1,
            title: "Level 2: Target Lock (Contains '11')",
            ruleDescription: "Draw a DFA that accepts strings containing '11'.",
            passingStrings: ["11", "011", "110"],
            failingStrings: ["101", "000", "10"]
        ),
        DFALevel(
            id: 2,
            title: "Level 3: Exact Match ('101')",
            ruleDescription: "Draw a DFA that exclusively accepts the exact string '101'.",
            passingStrings: ["101"],
            failingStrings: ["10", "1010", "111"]
        )
    ]
    
    init() {
        loadCampaignLevel(index: 0)
    }
    
    func loadCampaignLevel(index: Int) {
        guard index >= 0 && index < campaignLevels.count else { return }
        campaignIndex = index
        self.currentLevel = campaignLevels[index]
        resetTests()
    }
    
    func switchMode(to newMode: GameMode) {
        currentMode = newMode
        resetTests()
        
        switch newMode {
        case .campaign:
            loadCampaignLevel(index: 0)
        case .endlessAI:
            Task {
                await generateNextAILevel()
            }
        case .blankCanvas:
            currentLevel = nil
        }
    }
    
    func generateNextAILevel() async {
        isGeneratingAILevel = true
        resetTests()
        currentLevel = nil
        
        defer { isGeneratingAILevel = false }
        
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            guard SystemLanguageModel.default.availability == .available else {
                print("SystemLanguageModel not available.")
                loadFallbackAILevel()
                return
            }
            
            do {
                let session = LanguageModelSession {
                    "You are an expert puzzle game designer creating Deterministic Finite Automaton (DFA) logic puzzles."
                    "The DFA processes binary strings using only '0' and '1'."
                    "Generate structurally sound and logically correct puzzles."
                }
                
                let response = try await session.respond(
                    to: "Generate a new, unique DFA logic puzzle.",
                    generating: AIDFALevel.self
                )
                
                let aiLevel = response.content
                
                let newLevel = aiLevel.toDFALevel(id: Int.random(in: 1000...9000))
                
                self.currentLevel = newLevel
                self.wasGeneratedByAI = true
            } catch {
                print("AI Generation Failed: \(error.localizedDescription)")
                loadFallbackAILevel()
            }
        } else {
            print("FoundationModels requires iOS 26.0 or newer.")
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            loadFallbackAILevel()
        }
        #else
        print("FoundationModels framework unavailable. Using mock AI generation.")
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        loadFallbackAILevel()
        #endif
    }
    
    private func loadFallbackAILevel() {
        let mockLevels = [
            DFALevel(
                id: 99,
                title: "Mock AI: Even 1s",
                ruleDescription: "Draw a DFA that accepts strings with an even number of 1s.",
                passingStrings: ["11", "00", "0101"],
                failingStrings: ["1", "111", "01"]
            ),
            DFALevel(
                id: 100,
                title: "Mock AI: Starts with 1",
                ruleDescription: "Draw a DFA that accepts strings starting with '1'.",
                passingStrings: ["1", "10", "110"],
                failingStrings: ["0", "01", "011"]
            ),
            DFALevel(
                id: 101,
                title: "Mock AI: Odd 0s",
                ruleDescription: "Draw a DFA that accepts strings with an odd number of 0s.",
                passingStrings: ["0", "101", "000"],
                failingStrings: ["11", "00", "1001"]
            ),
            DFALevel(
                id: 102,
                title: "Mock AI: No 11",
                ruleDescription: "Draw a DFA that accepts strings that DO NOT contain '11'.",
                passingStrings: ["10", "010", "000"],
                failingStrings: ["11", "0110", "111"]
            ),
            DFALevel(
                id: 103,
                title: "Mock AI: Length > 2",
                ruleDescription: "Draw a DFA that accepts strings strictly longer than 2 characters.",
                passingStrings: ["000", "1010", "111"],
                failingStrings: ["0", "11", ""]
            )
        ]
        
        self.currentLevel = mockLevels.randomElement()!
        self.wasGeneratedByAI = false
    }
    
    func drawSolution(into vm: MachineViewModel) {
        guard let level = currentLevel else { return }
        vm.nodes.removeAll()
        vm.transitions.removeAll()
        
        switch level.id {
        case 0:
            let q0 = StateNode(name: "q0", position: CGPoint(x: 200, y: 450), isStartState: true, isAcceptingState: false)
            let q1 = StateNode(name: "q1", position: CGPoint(x: 400, y: 450), isStartState: false, isAcceptingState: false)
            let q2 = StateNode(name: "q2", position: CGPoint(x: 600, y: 450), isStartState: false, isAcceptingState: true)
            vm.nodes = [q0, q1, q2]
            vm.transitions = [
                Transition(fromNodeID: q0.id, toNodeID: q0.id, symbols: ["1"]),
                Transition(fromNodeID: q0.id, toNodeID: q1.id, symbols: ["0"]),
                Transition(fromNodeID: q1.id, toNodeID: q1.id, symbols: ["0"]),
                Transition(fromNodeID: q1.id, toNodeID: q2.id, symbols: ["1"]),
                Transition(fromNodeID: q2.id, toNodeID: q1.id, symbols: ["0"]),
                Transition(fromNodeID: q2.id, toNodeID: q0.id, symbols: ["1"])
            ]
        case 1:
            let q0 = StateNode(name: "q0", position: CGPoint(x: 200, y: 450), isStartState: true, isAcceptingState: false)
            let q1 = StateNode(name: "q1", position: CGPoint(x: 400, y: 450), isStartState: false, isAcceptingState: false)
            let q2 = StateNode(name: "q2", position: CGPoint(x: 600, y: 450), isStartState: false, isAcceptingState: true)
            vm.nodes = [q0, q1, q2]
            vm.transitions = [
                Transition(fromNodeID: q0.id, toNodeID: q0.id, symbols: ["0"]),
                Transition(fromNodeID: q0.id, toNodeID: q1.id, symbols: ["1"]),
                Transition(fromNodeID: q1.id, toNodeID: q0.id, symbols: ["0"]),
                Transition(fromNodeID: q1.id, toNodeID: q2.id, symbols: ["1"]),
                Transition(fromNodeID: q2.id, toNodeID: q2.id, symbols: ["0", "1"])
            ]
        case 2:
            let q0 = StateNode(name: "q0", position: CGPoint(x: 150, y: 450), isStartState: true, isAcceptingState: false)
            let q1 = StateNode(name: "q1", position: CGPoint(x: 300, y: 450), isStartState: false, isAcceptingState: false)
            let q2 = StateNode(name: "q2", position: CGPoint(x: 450, y: 450), isStartState: false, isAcceptingState: false)
            let q3 = StateNode(name: "q3", position: CGPoint(x: 600, y: 450), isStartState: false, isAcceptingState: true)
            let trap = StateNode(name: "trap", position: CGPoint(x: 375, y: 650), isStartState: false, isAcceptingState: false)
            vm.nodes = [q0, q1, q2, q3, trap]
            vm.transitions = [
                Transition(fromNodeID: q0.id, toNodeID: q1.id, symbols: ["1"]),
                Transition(fromNodeID: q1.id, toNodeID: q2.id, symbols: ["0"]),
                Transition(fromNodeID: q2.id, toNodeID: q3.id, symbols: ["1"]),
                Transition(fromNodeID: q0.id, toNodeID: trap.id, symbols: ["0"]),
                Transition(fromNodeID: q1.id, toNodeID: trap.id, symbols: ["1"]),
                Transition(fromNodeID: q2.id, toNodeID: trap.id, symbols: ["0"]),
                Transition(fromNodeID: q3.id, toNodeID: trap.id, symbols: ["0", "1"]),
                Transition(fromNodeID: trap.id, toNodeID: trap.id, symbols: ["0", "1"])
            ]
        default:
            let q0 = StateNode(name: "q0", position: CGPoint(x: 200, y: 450), isStartState: true, isAcceptingState: true)
            let q1 = StateNode(name: "q1", position: CGPoint(x: 500, y: 450), isStartState: false, isAcceptingState: false)
            vm.nodes = [q0, q1]
            vm.transitions = [
                Transition(fromNodeID: q0.id, toNodeID: q0.id, symbols: ["0"]),
                Transition(fromNodeID: q0.id, toNodeID: q1.id, symbols: ["1"]),
                Transition(fromNodeID: q1.id, toNodeID: q1.id, symbols: ["0"]),
                Transition(fromNodeID: q1.id, toNodeID: q0.id, symbols: ["1"])
            ]
        }
    }
    
    func resetTests() {
        testResults.removeAll()
        if let level = currentLevel {
            for string in level.passingStrings + level.failingStrings {
                testResults[string] = .pending
            }
        }
    }
    
    func runTests(nodes: [StateNode], transitions: [Transition]) {
        guard let level = currentLevel else { return }
        
        var newResults: [String: TestResult] = [:]
        
        for passing in level.passingStrings {
            let result = AutomatonEngine.evaluate(input: passing, nodes: nodes, transitions: transitions)
            newResults[passing] = result ? .passed : .failed
        }
        
        for failing in level.failingStrings {
            let result = AutomatonEngine.evaluate(input: failing, nodes: nodes, transitions: transitions)
            
            newResults[failing] = !result ? .passed : .failed
        }
        
        testResults = newResults
    }
    
    @MainActor
    func runTestsSequentially(vm: MachineViewModel) async -> Bool {
        guard let level = currentLevel else { return false }
        
        resetTests()
        isLiveTesting = true
        currentLiveTestResult = nil
        
        for passing in level.passingStrings {
            vm.testString = passing
            await vm.playSimulation()
            
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            let resultStatus = vm.simulationStatus
            let didPass = (resultStatus == .success)
            
            if didPass {
                testResults[passing] = .passed
            } else {
                testResults[passing] = .failed
            }
            
            currentLiveTestResult = (string: passing, passed: didPass)
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            currentLiveTestResult = nil
            vm.resetSimulation()
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        
        for failing in level.failingStrings {
            vm.testString = failing
            await vm.playSimulation()
            
            try? await Task.sleep(nanoseconds: 500_000_000)
            
            let resultStatus = vm.simulationStatus
            var didPass = false
            if case .failure = resultStatus {
                didPass = true
            }
            if didPass {
                testResults[failing] = .passed
            } else {
                testResults[failing] = .failed
            }
            
            currentLiveTestResult = (string: failing, passed: didPass)
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            currentLiveTestResult = nil
            vm.resetSimulation()
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        try? await Task.sleep(nanoseconds: 500_000_000)
        isLiveTesting = false
        return testResults.values.allSatisfy { $0 == .passed }
    }
}
