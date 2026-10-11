import SwiftUI

struct SavedSolutionsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var storage = SolutionStorageManager.shared
    
    // Optional closures or references to load into an active game session
    var onLoadSolution: ((SavedDFASolution) -> Void)? = nil
    
    var body: some View {
        NavigationStack {
            Group {
                if storage.savedSolutions.isEmpty {
                    emptyStateView
                } else {
                    solutionsListView
                }
            }
            .navigationTitle("Saved Solutions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "bookmark.slash")
                .font(.system(size: 70))
                .foregroundColor(.secondary)
            
            Text("No Saved Solutions Yet")
                .font(.title2.bold())
            
            Text("When you successfully solve any puzzle (Campaign or Endless AI), your completed DFA diagrams will be automatically archived here!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var solutionsListView: some View {
        List {
            ForEach(storage.savedSolutions) { solution in
                SolutionCardRow(solution: solution) {
                    onLoadSolution?(solution)
                    dismiss()
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            .onDelete { offsets in
                storage.deleteSolutions(at: offsets)
            }
        }
        .listStyle(.plain)
    }
}

struct SolutionCardRow: View {
    let solution: SavedDFASolution
    let onLoad: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Title & Timestamp
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(solution.level.title)
                        .font(.title3.bold())
                        .foregroundColor(.primary)
                    
                    Text("Solved on \(solution.formattedDate)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Diagram Stats Pills
                HStack(spacing: 6) {
                    Label("\(solution.nodes.count)", systemImage: "circle.circle.fill")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.15))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                    
                    Label("\(solution.transitions.count)", systemImage: "arrow.right")
                        .font(.caption2.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.15))
                        .foregroundColor(.orange)
                        .clipShape(Capsule())
                }
            }
            
            // Rule Description
            Text(solution.level.ruleDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            // Passing Test Strings Preview
            if !solution.level.passingStrings.isEmpty {
                HStack(spacing: 8) {
                    Text("Accepted:")
                        .font(.caption.bold())
                        .foregroundColor(.green)
                    
                    ForEach(solution.level.passingStrings.prefix(3), id: \.self) { sample in
                        Text(sample.isEmpty ? "ε" : sample)
                            .font(.caption.monospaced())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .foregroundColor(.green)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
            
            Divider()
            
            // Action Button: Load into Canvas
            Button(action: onLoad) {
                HStack {
                    Image(systemName: "arrow.up.forward.app.fill")
                    Text("Load Diagram onto Canvas")
                }
                .font(.subheadline.bold())
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.indigo)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 5, x: 0, y: 2)
        .padding(.vertical, 4)
    }
}
