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
    static let shared = GameManager()
    
    @Published var currentMode: GameMode = .campaign
    @Published var currentLevel: DFALevel?
    @Published var testResults: [String: TestResult] = [:]
    
    @Published var campaignIndex = 0
    @Published var isGeneratingAILevel = false
    @Published var wasGeneratedByAI = false
    
    @Published var bufferedLevels: [DFALevel] = []
    let targetBufferSize = 2
    
    private var recentPuzzles: [String] = []
    
    private let puzzleCategories = [
        "Prefix / Suffix: A starting or ending sequence (e.g. ends in '010', starts with '00', ends in '11', starts and ends with the same symbol)",
        "Substring Exclusion: Must NOT contain a specific substring (e.g. does NOT contain '11', does NOT contain '00')",
        "Parity & Modulo: Parity or divisibility (e.g. odd number of 1s, even number of 0s, total length is even, count of 1s is a multiple of 3)",
        "Positional Constraint: A constraint on a fixed position (e.g. second symbol is '1', third symbol from end is '0')",
        "Count Bounds: An upper or lower bound on occurrences (e.g. contains at least two '0's, contains at most one '1', exactly two '1's)",
        "Alternation: Patterns of alternating symbols (e.g. strictly alternating 0s and 1s, no consecutive identical symbols)"
    ]
    
    @Published var isLiveTesting = false
    @Published var currentLiveTestResult: (string: String, passed: Bool)? = nil
    
    private let campaignLevels: [DFALevel] = [
        DFALevel(
            id: 0,
            title: "Level 1: The Basics (Ends in '01')",
            ruleDescription: "Draw a DFA that accepts strings ending in '01'.",
            passingStrings: ["01", "101", "001"],
            failingStrings: ["0", "11", "10"],
            regexPattern: "^[01]*01$"
        ),
        DFALevel(
            id: 1,
            title: "Level 2: Target Lock (Contains '11')",
            ruleDescription: "Draw a DFA that accepts strings containing '11'.",
            passingStrings: ["11", "011", "110"],
            failingStrings: ["101", "000", "10"],
            regexPattern: "^[01]*11[01]*$"
        ),
        DFALevel(
            id: 2,
            title: "Level 3: Exact Match ('101')",
            ruleDescription: "Draw a DFA that exclusively accepts the exact string '101'.",
            passingStrings: ["101"],
            failingStrings: ["10", "1010", "111"],
            regexPattern: "^101$"
        )
    ]
    
    private let campaignLevelsKey = "savedCampaignIndex"
    
    init() {
        let savedIndex = UserDefaults.standard.integer(forKey: campaignLevelsKey)
        let validIndex = (savedIndex >= 0 && savedIndex < campaignLevels.count) ? savedIndex : 0
        campaignIndex = validIndex
        loadCampaignLevel(index: validIndex)
        replenishBufferIfNeeded()
    }
    
    func loadCampaignLevel(index: Int) {
        let validIndex = (index >= 0 && index < campaignLevels.count) ? index : 0
        campaignIndex = validIndex
        UserDefaults.standard.set(validIndex, forKey: campaignLevelsKey)
        self.currentLevel = campaignLevels[validIndex]
        self.wasGeneratedByAI = false
        resetTests()
    }
    
    func switchMode(to newMode: GameMode) {
        currentMode = newMode
        resetTests()
        
        switch newMode {
        case .campaign:
            let savedIndex = UserDefaults.standard.integer(forKey: campaignLevelsKey)
            loadCampaignLevel(index: savedIndex)
        case .endlessAI:
            Task {
                await presentNextAILevel()
            }
        case .blankCanvas:
            currentLevel = nil
            wasGeneratedByAI = false
        }
    }
    
    private var activeReplenishTasks = 0
    
    func presentNextAILevel() async {
        resetTests()
        
        if let nextLevel = bufferedLevels.first {
            bufferedLevels.removeFirst()
            self.currentLevel = nextLevel
            self.wasGeneratedByAI = true
            self.isGeneratingAILevel = false
            print("✅ Displaying Level from buffer: \(nextLevel.title)")
        } else {
            isGeneratingAILevel = true
            self.currentLevel = await generateSingleLevel()
            self.wasGeneratedByAI = true
            isGeneratingAILevel = false
            print("✅ Displaying Level generated on-the-fly: \(self.currentLevel!.title)")
        }
        
        replenishBufferIfNeeded()
    }
    
    func replenishBufferIfNeeded() {
        let needed = targetBufferSize - bufferedLevels.count - activeReplenishTasks
        guard needed > 0 else { return }
        
        for _ in 0..<needed {
            activeReplenishTasks += 1
            Task {
                let level = await self.generateSingleLevel()
                await MainActor.run {
                    self.bufferedLevels.append(level)
                    self.activeReplenishTasks = max(0, self.activeReplenishTasks - 1)
                    print("📥 Buffered Level in background: \(level.title) (Queue size: \(self.bufferedLevels.count))")
                }
            }
        }
    }
    
    private func generateSingleLevel() async -> DFALevel {
        var draftTitle: String? = nil
        var draftRule: String? = nil
        var draftRegex: String? = nil
        var draftPassing: [String] = []
        var draftFailing: [String] = []

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            if SystemLanguageModel.default.availability == .available {
                do {
                    let session = LanguageModelSession {
                        "You are an expert puzzle game designer and theoretical computer scientist creating Deterministic Finite Automaton (DFA) logic puzzles."
                        "The DFA processes binary strings using only '0' and '1'."
                        "The rule MUST define a REGULAR language solvable by a finite state machine."
                        "Valid regular language types: ends with pattern (e.g. 'ends with 01'), starts with pattern (e.g. 'starts with 1'), contains or does not contain pattern (e.g. 'contains 11'), or parity count (e.g. 'even number of 1s')."
                        "DO NOT propose non-regular languages like 'equal number of 0s and 1s', 'same count of 0 and 1', or 'palindromes'. Those are impossible for a DFA."
                        "You MUST generate: 1) question title, 2) player-facing rule, 3) standard anchored regexPattern (^...$) over {0,1}, 4) step-by-step proof, 5) 3 passing strings matching regex, 6) 3 failing strings not matching regex."
                        "Example: Title: 'Ends in 01', Rule: 'Strings ending in 01', regexPattern: '^[01]*01$', Passing: ['01', '101', '001'], Failing: ['10', '010', '11']."
                    }
                    
                    let response = try await session.respond(
                        to: "Generate a new, simple, and unambiguous DFA logic puzzle with an anchored regexPattern and candidate test cases.",
                        generating: AIDFALevel.self
                    )
                    
                    let aiLevel = response.content
                    draftTitle = aiLevel.title
                    draftRule = aiLevel.ruleDescription
                    draftRegex = aiLevel.regexPattern
                    draftPassing = aiLevel.passingStrings
                    draftFailing = aiLevel.failingStrings
                } catch {
                    print("On-Device AI Draft Failed: \(error.localizedDescription)")
                }
            } else {
                print("SystemLanguageModel not currently available on device.")
            }
        }
        #endif

        // If on-device draft was obtained, check semantic guardrail for non-regular rules
        if let rule = draftRule, !DFAPuzzleValidator.isPermissibleDFARule(rule: rule) {
            print("Semantic guardrail caught non-regular rule: '\(rule)'. Adapting to parity...")
            draftTitle = "Parity Check: Even 1s"
            draftRule = "Draw a DFA that accepts strings containing an even number of 1s."
            draftRegex = "^0*(10*10*)*$"
            draftPassing = ["11", "00", "0101"]
            draftFailing = ["1", "111", "01"]
        }

        // Tier 2: If Cloud LLM Provider is configured, creatively generate or refine using the Cloud LLM
        if CloudLLMService.shared.isConfigured {
            let selectedCategory = puzzleCategories.randomElement()
            
            do {
                let cloudResult = try await CloudLLMService.shared.verifyAndGenerateTestCases(
                    proposedTitle: draftTitle,
                    proposedRule: draftRule,
                    categoryHint: selectedCategory,
                    recentTitles: recentPuzzles
                )
                
                draftTitle = cloudResult.refinedTitle
                draftRule = cloudResult.refinedRule
                draftRegex = cloudResult.regexPattern
                draftPassing = cloudResult.passingStrings
                draftFailing = cloudResult.failingStrings
            } catch {
                print("Cloud LLM Verification Error: \(error.localizedDescription)")
            }
        }

        // Final Tier: In-app deterministic validation & BFS synthesis
        if let title = draftTitle, let rule = draftRule, let regex = draftRegex {
            let (verifiedPassing, verifiedFailing, isValid) = DFAPuzzleValidator.validateAndSynthesize(
                regexPattern: regex,
                candidatePassing: draftPassing,
                candidateFailing: draftFailing
            )
            
            if isValid && !verifiedPassing.isEmpty && !verifiedFailing.isEmpty {
                // Record in recent history to prevent repetition
                self.recentPuzzles.append(title)
                if self.recentPuzzles.count > 6 {
                    self.recentPuzzles.removeFirst()
                }
                
                return DFALevel(
                    id: Int.random(in: 1000...9000),
                    title: title,
                    ruleDescription: rule,
                    passingStrings: verifiedPassing,
                    failingStrings: verifiedFailing,
                    regexPattern: regex
                )
            }
        }

        // Fallback if neither on-device nor cloud produced a valid verified level
        return getFallbackAILevel()
    }
    
    private func getFallbackAILevel() -> DFALevel {
        let mockLevels = [
            DFALevel(
                id: 99,
                title: "Mock AI: Even 1s",
                ruleDescription: "Draw a DFA that accepts strings with an even number of 1s.",
                passingStrings: ["11", "00", "0101"],
                failingStrings: ["1", "111", "01"],
                regexPattern: "^0*(10*10*)*$"
            ),
            DFALevel(
                id: 100,
                title: "Mock AI: Starts with 1",
                ruleDescription: "Draw a DFA that accepts strings starting with '1'.",
                passingStrings: ["1", "10", "110"],
                failingStrings: ["0", "01", "011"],
                regexPattern: "^1[01]*$"
            ),
            DFALevel(
                id: 101,
                title: "Mock AI: Odd 0s",
                ruleDescription: "Draw a DFA that accepts strings with an odd number of 0s.",
                passingStrings: ["0", "101", "000"],
                failingStrings: ["11", "00", "1001"],
                regexPattern: "^1*(01*01*)*01*$"
            ),
            DFALevel(
                id: 102,
                title: "Mock AI: No 11",
                ruleDescription: "Draw a DFA that accepts strings that DO NOT contain '11'.",
                passingStrings: ["10", "010", "000"],
                failingStrings: ["11", "0110", "111"],
                regexPattern: "^(0|10)*1?$"
            ),
            DFALevel(
                id: 103,
                title: "Mock AI: Length > 2",
                ruleDescription: "Draw a DFA that accepts strings strictly longer than 2 characters.",
                passingStrings: ["000", "1010", "111"],
                failingStrings: ["0", "11", ""],
                regexPattern: "^[01]{3,}$"
            )
        ]
        
        return mockLevels.randomElement()!
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
        
        let allPassed = !testResults.isEmpty && testResults.values.allSatisfy { $0 == .passed }
        if allPassed {
            SolutionStorageManager.shared.saveOrUpdate(level: level, nodes: vm.nodes, transitions: vm.transitions)
        }
        
        return allPassed
    }
    
    /// Loads a previously saved DFA solution onto the canvas and switches to that level
    func loadSavedSolution(_ solution: SavedDFASolution, into vm: MachineViewModel) {
        self.currentLevel = solution.level
        resetTests()
        
        vm.resetSimulation()
        vm.nodes = solution.nodes
        vm.transitions = solution.transitions
        print("📂 Loaded saved solution '\(solution.level.title)' onto canvas")
    }
}
