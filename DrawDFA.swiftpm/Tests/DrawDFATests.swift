import XCTest
import SwiftUI
@testable import AppModule

final class AutomatonEngineTests: XCTestCase {
    
    /// Test that an empty string (ε) correctly accepts if the start node is accepting
    func testEmptyStringOnAcceptingStartNode() {
        let q0 = StateNode(name: "q0", position: .zero, isStartState: true, isAcceptingState: true)
        let nodes = [q0]
        let transitions: [Transition] = []
        
        let (steps, status) = AutomatonEngine.generateSteps(for: "", nodes: nodes, transitions: transitions)
        
        XCTAssertEqual(status, .success)
        XCTAssertEqual(steps.count, 1)
        XCTAssertEqual(steps.first?.activeNodeID, q0.id)
    }
    
    /// Test that an empty string (ε) correctly fails if the start node is non-accepting
    func testEmptyStringOnNonAcceptingStartNode() {
        let q0 = StateNode(name: "q0", position: .zero, isStartState: true, isAcceptingState: false)
        let nodes = [q0]
        let transitions: [Transition] = []
        
        let (_, status) = AutomatonEngine.generateSteps(for: "", nodes: nodes, transitions: transitions)
        
        if case .failure(let reason) = status {
            XCTAssertTrue(reason.contains("non-accepting"))
        } else {
            XCTFail("Expected failure on non-accepting start state for empty string")
        }
    }
    
    /// Test standard binary string evaluation on an "Ends in 01" DFA
    func testEndsIn01DFA() {
        let q0 = StateNode(name: "q0", position: .zero, isStartState: true, isAcceptingState: false)
        let q1 = StateNode(name: "q1", position: .zero, isStartState: false, isAcceptingState: false)
        let q2 = StateNode(name: "q2", position: .zero, isStartState: false, isAcceptingState: true)
        let nodes = [q0, q1, q2]
        
        let transitions = [
            Transition(fromNodeID: q0.id, toNodeID: q0.id, symbols: ["1"]),
            Transition(fromNodeID: q0.id, toNodeID: q1.id, symbols: ["0"]),
            Transition(fromNodeID: q1.id, toNodeID: q1.id, symbols: ["0"]),
            Transition(fromNodeID: q1.id, toNodeID: q2.id, symbols: ["1"]),
            Transition(fromNodeID: q2.id, toNodeID: q1.id, symbols: ["0"]),
            Transition(fromNodeID: q2.id, toNodeID: q0.id, symbols: ["1"])
        ]
        
        // Passing strings
        XCTAssertTrue(AutomatonEngine.evaluate(input: "01", nodes: nodes, transitions: transitions))
        XCTAssertTrue(AutomatonEngine.evaluate(input: "101", nodes: nodes, transitions: transitions))
        XCTAssertTrue(AutomatonEngine.evaluate(input: "00001", nodes: nodes, transitions: transitions))
        
        // Failing strings
        XCTAssertFalse(AutomatonEngine.evaluate(input: "10", nodes: nodes, transitions: transitions))
        XCTAssertFalse(AutomatonEngine.evaluate(input: "010", nodes: nodes, transitions: transitions))
        XCTAssertFalse(AutomatonEngine.evaluate(input: "111", nodes: nodes, transitions: transitions))
        XCTAssertFalse(AutomatonEngine.evaluate(input: "", nodes: nodes, transitions: transitions))
    }
    
    /// Test non-determinism detection (multiple transitions for symbol '0')
    func testNonDeterminismFailure() {
        let q0 = StateNode(name: "q0", position: .zero, isStartState: true, isAcceptingState: false)
        let q1 = StateNode(name: "q1", position: .zero, isStartState: false, isAcceptingState: true)
        let q2 = StateNode(name: "q2", position: .zero, isStartState: false, isAcceptingState: true)
        let nodes = [q0, q1, q2]
        
        // Two transitions for '0' from q0
        let transitions = [
            Transition(fromNodeID: q0.id, toNodeID: q1.id, symbols: ["0"]),
            Transition(fromNodeID: q0.id, toNodeID: q2.id, symbols: ["0"])
        ]
        
        let (_, status) = AutomatonEngine.generateSteps(for: "0", nodes: nodes, transitions: transitions)
        
        if case .failure(let reason) = status {
            XCTAssertTrue(reason.contains("Multiple transitions"))
        } else {
            XCTFail("Expected non-determinism failure")
        }
    }
}

final class StrictDFAValidationTests: XCTestCase {
    
    @MainActor
    func testCompleteDFAMachineValidation() {
        let vm = MachineViewModel()
        let q0 = StateNode(name: "q0", position: .zero, isStartState: true, isAcceptingState: false)
        let q1 = StateNode(name: "q1", position: .zero, isStartState: false, isAcceptingState: true)
        vm.nodes = [q0, q1]
        
        // Complete transitions: q0 has 0 and 1, q1 has 0 and 1
        vm.transitions = [
            Transition(fromNodeID: q0.id, toNodeID: q1.id, symbols: ["0"]),
            Transition(fromNodeID: q0.id, toNodeID: q0.id, symbols: ["1"]),
            Transition(fromNodeID: q1.id, toNodeID: q1.id, symbols: ["0", "1"])
        ]
        
        XCTAssertTrue(vm.validateDFAMachine())
        XCTAssertNil(vm.toastMessage)
    }
    
    @MainActor
    func testIncompleteDFAMachineValidation() {
        let vm = MachineViewModel()
        let q0 = StateNode(name: "q0", position: .zero, isStartState: true, isAcceptingState: false)
        vm.nodes = [q0]
        
        // Missing '1' transition
        vm.transitions = [
            Transition(fromNodeID: q0.id, toNodeID: q0.id, symbols: ["0"])
        ]
        
        XCTAssertFalse(vm.validateDFAMachine())
        XCTAssertNotNil(vm.toastMessage)
        XCTAssertTrue(vm.toastMessage?.contains("missing a transition for '1'") ?? false)
    }
}

final class DFAPuzzleValidatorTests: XCTestCase {
    
    func testPermissibleRules() {
        // Valid regular language descriptions
        XCTAssertTrue(DFAPuzzleValidator.isPermissibleDFARule(rule: "Strings starting with 1"))
        XCTAssertTrue(DFAPuzzleValidator.isPermissibleDFARule(rule: "Even number of 1s"))
        XCTAssertTrue(DFAPuzzleValidator.isPermissibleDFARule(rule: "Contains 010"))
        
        // Non-regular language descriptions (forbidden)
        XCTAssertFalse(DFAPuzzleValidator.isPermissibleDFARule(rule: "Equal number of 0s and 1s"))
        XCTAssertFalse(DFAPuzzleValidator.isPermissibleDFARule(rule: "Same count of 0 and 1"))
        XCTAssertFalse(DFAPuzzleValidator.isPermissibleDFARule(rule: "Palindrome strings"))
    }
    
    func testRegexEvaluationAndSynthesis() {
        let regex = "^1[01]*$" // Starts with 1
        let candidatePassing = ["1", "10", "101"]
        let candidateFailing = ["0", "01", ""]
        
        let (passing, failing, isValid) = DFAPuzzleValidator.validateAndSynthesize(
            regexPattern: regex,
            candidatePassing: candidatePassing,
            candidateFailing: candidateFailing
        )
        
        XCTAssertTrue(isValid)
        XCTAssertEqual(passing, candidatePassing)
        XCTAssertEqual(failing, candidateFailing)
    }
}

final class GameManagerBufferTests: XCTestCase {
    
    @MainActor
    func testBufferInitializationAndPopping() async {
        let gameManager = GameManager()
        
        // Create mock levels
        let level1 = DFALevel(id: 1, title: "L1", ruleDescription: "R1", passingStrings: ["1"], failingStrings: ["0"], regexPattern: "^1$")
        let level2 = DFALevel(id: 2, title: "L2", ruleDescription: "R2", passingStrings: ["0"], failingStrings: ["1"], regexPattern: "^0$")
        
        gameManager.bufferedLevels = [level1, level2]
        
        // Present next level
        await gameManager.presentNextAILevel()
        
        // Current level should be popped level1
        XCTAssertEqual(gameManager.currentLevel?.id, 1)
        XCTAssertEqual(gameManager.bufferedLevels.count, 1)
        XCTAssertEqual(gameManager.bufferedLevels.first?.id, 2)
    }
}
