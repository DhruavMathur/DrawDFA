import Foundation
import SwiftUI

@MainActor
class SolutionStorageManager: ObservableObject {
    static let shared = SolutionStorageManager()
    
    @Published var savedSolutions: [SavedDFASolution] = []
    
    private let fileName = "saved_dfa_solutions.json"
    
    private var fileURL: URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent(fileName)
    }
    
    init() {
        loadSolutions()
    }
    
    /// Loads all solutions from local sandbox JSON storage
    func loadSolutions() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            self.savedSolutions = []
            return
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try JSONDecoder().decode([SavedDFASolution].self, from: data)
            self.savedSolutions = decoded
        } catch {
            print("Failed to load saved DFA solutions: \(error.localizedDescription)")
            self.savedSolutions = []
        }
    }
    
    /// Saves a new solution or overwrites the existing one for the same level so only one copy is kept
    func saveOrUpdate(level: DFALevel, nodes: [StateNode], transitions: [Transition]) {
        // Look for existing solution for this level
        if let existingIndex = savedSolutions.firstIndex(where: {
            $0.level.id == level.id || ($0.level.title == level.title && $0.level.ruleDescription == level.ruleDescription)
        }) {
            // Overwrite existing solution with latest diagram & timestamp
            savedSolutions[existingIndex].nodes = nodes
            savedSolutions[existingIndex].transitions = transitions
            savedSolutions[existingIndex].level = level
            savedSolutions[existingIndex].completedAt = Date()
            print("💾 Updated existing saved solution for: \(level.title)")
        } else {
            // Insert new solution at the beginning
            let newSolution = SavedDFASolution(
                level: level,
                nodes: nodes,
                transitions: transitions,
                completedAt: Date()
            )
            savedSolutions.insert(newSolution, at: 0)
            print("💾 Saved new solution for: \(level.title)")
        }
        
        persistToDisk()
    }
    
    /// Deletes a solution by ID
    func deleteSolution(id: UUID) {
        savedSolutions.removeAll { $0.id == id }
        persistToDisk()
    }
    
    /// Deletes solutions at specific index set (for SwiftUI List .onDelete)
    func deleteSolutions(at offsets: IndexSet) {
        savedSolutions.remove(atOffsets: offsets)
        persistToDisk()
    }
    
    /// Writes current array to JSON file
    private func persistToDisk() {
        do {
            let data = try JSONEncoder().encode(savedSolutions)
            try data.write(to: fileURL, options: [.atomicWrite, .completeFileProtection])
        } catch {
            print("Failed to persist saved DFA solutions: \(error.localizedDescription)")
        }
    }
}
