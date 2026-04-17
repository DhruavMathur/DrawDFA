import SwiftUI

struct GameOverlayView: View {
    @StateObject private var gameManager: GameManager
    @StateObject private var vm = MachineViewModel() 
    @State private var isOverlayExpanded: Bool
    
    init(initialMode: GameMode = .campaign) {
        let manager = GameManager()
        manager.currentMode = initialMode
        
        switch initialMode {
        case .blankCanvas:
            _isOverlayExpanded = State(initialValue: false)
        case .campaign, .endlessAI:
            _isOverlayExpanded = State(initialValue: true)
        }
        
        _gameManager = StateObject(wrappedValue: manager)
    }
    
    
    private var allTestsEvaluated: Bool {
        guard !gameManager.testResults.isEmpty else { return false }
        return !gameManager.testResults.values.contains(.pending)
    }
    
    private var allTestsPassed: Bool {
        return allTestsEvaluated && gameManager.testResults.values.allSatisfy { $0 == .passed }
    }
    
    var body: some View {
        ZStack {
            
            MainCanvasView(vm: vm)
                .zIndex(0)
            
            
            if let liveResult = gameManager.currentLiveTestResult {
                VStack {
                    HStack {
                        Image(systemName: liveResult.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                        Text("\(liveResult.string) - \(liveResult.passed ? "Passed" : "Failed")")
                    }
                    .font(.title2.bold())
                    .padding()
                    .background(liveResult.passed ? Color.green : Color.red)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                    .shadow(radius: 10)
                    .padding(.top, 220)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    
                    Spacer()
                }
                .zIndex(2)
            }
            
            if !isOverlayExpanded, let level = gameManager.currentLevel, gameManager.currentMode != .blankCanvas {
                VStack {
                    HStack {
                        
                        Text(level.ruleDescription)
                            .font(.headline)
                            .padding()
                            .background(Color(UIColor.systemBackground).opacity(0.9))
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                            .shadow(radius: 5)
                        
                        Spacer()
                        
                        
                        if gameManager.currentMode == .campaign {
                            Button(action: {
                                withAnimation {
                                    gameManager.drawSolution(into: vm)
                                }
                            }) {
                                HStack {
                                    Image(systemName: "pencil.and.outline")
                                    Text("Auto-Draw DFA")
                                }
                                .font(.headline)
                                .padding()
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                                .shadow(radius: 5)
                            }
                        }
                        
                        
                        if gameManager.currentMode == .endlessAI {
                            Button(action: {
                                Task {
                                    vm.resetSimulation()
                                    vm.nodes.removeAll()
                                    vm.transitions.removeAll()
                                    await gameManager.generateNextAILevel()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "forward.end.fill")
                                    Text("Skip Question")
                                }
                                .font(.headline)
                                .padding()
                                .background(Color.purple)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                                .shadow(radius: 5)
                            }
                        }
                        
                        
                        Button(action: {
                            withAnimation(.spring()) {
                                isOverlayExpanded = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "questionmark.circle.fill")
                                Text("Show Question")
                            }
                            .font(.headline)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                            .shadow(radius: 5)
                        }
                    }
                    .padding()
                    .padding(.top, 80)
                    Spacer()
                }
                .zIndex(1)
            }
            
            
            if isOverlayExpanded, let level = gameManager.currentLevel, gameManager.currentMode != .blankCanvas {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .zIndex(2)
                    .onTapGesture {
                        withAnimation(.spring()) {
                            isOverlayExpanded = false
                        }
                    }
                
                VStack(spacing: 20) {
                    HStack {
                        Text(level.title)
                            .font(.title2.bold())
                        Spacer()
                        Button(action: {
                            withAnimation(.spring()) {
                                isOverlayExpanded = false
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Text(level.ruleDescription)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 10)
                        
                    if gameManager.currentMode == .endlessAI {
                        HStack {
                            Image(systemName: "wand.and.stars")
                            Text(gameManager.wasGeneratedByAI ? "Generated by Apple Intelligence" : "Fallback Mock Generator")
                        }
                        .font(.caption.bold())
                        .foregroundColor(gameManager.wasGeneratedByAI ? .purple : .orange)
                        .padding(.top, -10)
                        .padding(.bottom, 5)
                    }
                    
                    Divider()
                    
                    
                    HStack(spacing: 40) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Must Accept:")
                                .font(.subheadline.bold())
                                .foregroundColor(.green)
                            ForEach(level.passingStrings, id: \.self) { str in
                                TestStringRow(string: str, result: gameManager.testResults[str] ?? .pending)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Must Reject:")
                                .font(.subheadline.bold())
                                .foregroundColor(.red)
                            ForEach(level.failingStrings, id: \.self) { str in
                                TestStringRow(string: str, result: gameManager.testResults[str] ?? .pending)
                            }
                        }
                    }
                    
                    Divider()
                    
                    
                    if gameManager.isLiveTesting {
                        Button(action: {}) {
                            HStack {
                                ProgressView()
                                    .tint(.white)
                                Text("Evaluating...")
                            }
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                        }
                        .disabled(true)
                    } else if allTestsPassed {
                        Button(action: {
                            withAnimation {
                                if gameManager.currentMode == .campaign {
                                    gameManager.loadCampaignLevel(index: gameManager.campaignIndex + 1)
                                } else {
                                    Task {
                                        await gameManager.generateNextAILevel()
                                    }
                                }
                                vm.resetSimulation()
                                vm.nodes.removeAll()
                                vm.transitions.removeAll()
                                gameManager.resetTests()
                                isOverlayExpanded = false
                            }
                        }) {
                            HStack {
                                Image(systemName: "arrow.right.circle.fill")
                                Text("Next Level")
                            }
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                        }
                    } else {
                        Button(action: {
                            withAnimation {
                                isOverlayExpanded = false
                            }
                            
                            Task {
                                let _ = await gameManager.runTestsSequentially(vm: vm)
                                
                                
                                try? await Task.sleep(nanoseconds: 800_000_000)
                                await MainActor.run {
                                    withAnimation(.spring()) {
                                        isOverlayExpanded = true
                                    }
                                }
                            }
                        }) {
                            HStack {
                                Image(systemName: allTestsEvaluated ? "arrow.clockwise.circle.fill" : "play.circle.fill")
                                Text(allTestsEvaluated ? "Try Again" : "Evaluate DFA")
                            }
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(allTestsEvaluated ? Color.orange : Color.blue)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                        }
                    }
                }
                .padding(30)
                .background(Color(UIColor.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 25))
                .shadow(radius: 20)
                .padding(40)
                .zIndex(3)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear {
            vm.resetSimulation()
            vm.nodes.removeAll()
            vm.transitions.removeAll()
            gameManager.resetTests()
            
            if gameManager.currentMode == .endlessAI {
                Task {
                    await gameManager.generateNextAILevel()
                }
            } else if gameManager.currentMode == .campaign {
                gameManager.loadCampaignLevel(index: 0)
            }
        }
        .environmentObject(gameManager)
    }
}

struct TestStringRow: View {
    let string: String
    let result: TestResult
    
    var body: some View {
        HStack {
            Text(string.isEmpty ? "ε (Empty)" : string)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.gray.opacity(0.2))
                .clipShape(Capsule())
            
            Spacer()
            
            switch result {
            case .pending:
                Image(systemName: "circle.dashed")
                    .foregroundColor(.gray)
            case .passed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .failed:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
        }
        .frame(width: 150)
    }
}
