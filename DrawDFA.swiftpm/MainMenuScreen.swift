import SwiftUI

struct MainMenuScreen: View {
    @State private var navigateToGame = false
    @State private var selectedMode: GameMode = .campaign
    @State private var showingSavedSolutions = false
    @State private var solutionToLoad: SavedDFASolution? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemBackground).ignoresSafeArea()
                
                VStack(spacing: 35) {
                    VStack(spacing: 10) {
                        Image(systemName: "point.3.connected.trianglepath.dotted")
                            .font(.system(size: 80))
                            .foregroundColor(.indigo)
                        Text("Draw DFA")
                            .font(.largeTitle.bold())
                        
                        Text("Master Automata Theory")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 20)
                    
                    VStack(spacing: 16) {
                        MenuButton(
                            title: "Campaign Mode (Demo Mode)",
                            subtitle: "Play 3 handcrafted DFA puzzles",
                            icon: "flag.checkered",
                            color: .blue
                        ) {
                            solutionToLoad = nil
                            selectedMode = .campaign
                            navigateToGame = true
                        }
                        
                        MenuButton(
                            title: "Endless AI Mode",
                            subtitle: "Infinite generated puzzles",
                            icon: "infinity",
                            color: .purple
                        ) {
                            solutionToLoad = nil
                            selectedMode = .endlessAI
                            navigateToGame = true
                        }
                        
                        MenuButton(
                            title: "Blank Canvas",
                            subtitle: "Test your own machines freely",
                            icon: "square.dashed",
                            color: .orange
                        ) {
                            solutionToLoad = nil
                            selectedMode = .blankCanvas
                            navigateToGame = true
                        }
                        
                        MenuButton(
                            title: "Saved Solutions",
                            subtitle: "Review your past solved DFA diagrams",
                            icon: "bookmark.fill",
                            color: .teal
                        ) {
                            showingSavedSolutions = true
                        }
                    }
                    .padding(.horizontal, 40)
                }
            }
            .sheet(isPresented: $showingSavedSolutions) {
                SavedSolutionsView { solution in
                    self.solutionToLoad = solution
                    self.selectedMode = .campaign
                    self.navigateToGame = true
                }
            }
            .navigationDestination(isPresented: $navigateToGame) {
                GameOverlayView(initialMode: selectedMode, savedSolutionToLoad: solutionToLoad)
                    .navigationBarBackButtonHidden(true)
            }
        }
    }
}

struct MenuButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundColor(color)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
            .padding(20)
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        }
    }
}
