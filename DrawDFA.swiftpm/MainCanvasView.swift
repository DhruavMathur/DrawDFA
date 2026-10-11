import SwiftUI

struct MainCanvasView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var vm: MachineViewModel
    @State private var showingSymbolAlert = false
    @State private var pendingTransitionStart: UUID?
    @State private var pendingTransitionEnd: UUID?
    @State private var transitionSymbolParam: String = "0"
    
    
    @State private var isDrawModeEnabled = false
    @State private var showingInfoSheet = false
    @State private var showingSavedSolutionsSheet = false
    
    var onLoadSavedSolution: ((SavedDFASolution) -> Void)? = nil
    
    init(vm: MachineViewModel, onLoadSavedSolution: ((SavedDFASolution) -> Void)? = nil) {
        self.vm = vm
        self.onLoadSavedSolution = onLoadSavedSolution
    }
    
    var body: some View {
        ZStack {
            // MARK: - Background Dynamic Colors
            backgroundGlow
            
            // MARK: - The Canvas Board
            boardArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(white: 0.1).opacity(0.1))
                .onTapGesture { location in
                    guard vm.simulationStatus != .running else { return }
                    withAnimation(.spring()) {
                        vm.addNode(at: location)
                    }
                }
            
            // MARK: - Top Dashboard
            VStack {
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                    
                    Text("Draw DFA")
                        .font(.title2.bold())
                    Spacer()
                    
                    Button(action: {
                        showingSavedSolutionsSheet = true
                    }) {
                        Image(systemName: "bookmark")
                            .font(.title2)
                    }
                    .padding(.trailing, 5)
                    
                    Button(action: {
                        showingInfoSheet = true
                    }) {
                        Image(systemName: "info.circle")
                            .font(.title2)
                    }
                    .padding(.trailing, 5)
                    
                    Toggle(isOn: $isDrawModeEnabled) {
                        Image(systemName: "pencil.and.outline")
                        Text("Draw Mode")
                    }
                    .toggleStyle(.button)
                    .tint(.orange)
                    .padding(.trailing, 10)
                    
                    Button("Load Demo: Ends in '01'") {
                        vm.loadDemo()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                }
                .padding()
                .background(.ultraThinMaterial)
                
                Spacer()
                
                // MARK: - Bottom Controls
                HStack(spacing: 15) {
                    Toggle(isOn: $vm.enforceStrictDFA) {
                        Image(systemName: "checkmark.seal.fill")
                        Text("Strict DFA")
                    }
                    .toggleStyle(.button)
                    .tint(.orange)
                    .padding(.trailing, 10)
                    
                    TextField("Enter string (leave blank for ε)", text: $vm.testString)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                        .frame(maxWidth: 350)
                        
                    Button(action: {
                        Task {
                            await vm.playSimulation()
                        }
                    }) {
                        Image(systemName: "play.fill")
                        Text("Play Simulation")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(vm.simulationStatus == .running)
                    
                    Button(action: {
                        vm.resetSimulation()
                    }) {
                        Image(systemName: "stop.fill")
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
                .font(.title3)
                .controlSize(.large)
                .padding()
                .background(.ultraThinMaterial)
            }
        }
        .alert("Add Transition", isPresented: $showingSymbolAlert) {
            TextField("Symbols (e.g. 0, 1)", text: $transitionSymbolParam)
                .keyboardType(.numbersAndPunctuation)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
            Button("Add") {
                if let start = pendingTransitionStart, let end = pendingTransitionEnd {
                    let chars: [Character] = transitionSymbolParam.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ",", with: "").map { $0 }
                    if !chars.isEmpty {
                        withAnimation {
                            vm.addTransition(from: start, to: end, symbols: chars)
                        }
                    }
                }
                pendingTransitionStart = nil
                pendingTransitionEnd = nil
            }
            Button("Cancel", role: .cancel) {
                pendingTransitionStart = nil
                pendingTransitionEnd = nil
            }
        } message: {
            Text("Enter the input symbol for this path.")
        }
        .sheet(isPresented: $showingInfoSheet) {
            HelpInstructionsView()
        }
        .sheet(isPresented: $showingSavedSolutionsSheet) {
            SavedSolutionsView(onLoadSolution: onLoadSavedSolution)
        }
    }
    
    // MARK: - Subviews
    
    private var boardArea: some View {
        ZStack {
            
            ForEach(vm.transitions) { transition in
                TransitionEdgeView(transition: transition, vm: vm)
            }
            
            
            if let startNodeID = vm.drawStartNodeID,
               let startNode = vm.nodes.first(where: { $0.id == startNodeID }),
               let currentLoc = vm.currentDragLocation {
                Path { path in
                    path.move(to: startNode.position)
                    path.addLine(to: currentLoc)
                }
                .stroke(Color.gray.opacity(0.5), style: StrokeStyle(lineWidth: 3, dash: [10]))
            }
            
            
            ForEach(vm.nodes) { node in
                StateNodeView(node: node, vm: vm, isDrawMode: isDrawModeEnabled, onDrawEdge: { startID, endID in
                    self.pendingTransitionStart = startID
                    self.pendingTransitionEnd = endID
                    self.transitionSymbolParam = "0"
                    self.showingSymbolAlert = true
                })
            }
            
            
            if vm.simulationStatus == .running {
                VStack {
                    Spacer()
                    Text("Reading: \(vm.remainingInputString)")
                        .font(.headline)
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(.bottom, 120)
                }
            } else if case .failure(let reason) = vm.simulationStatus {
                VStack {
                    Spacer()
                    Text("Crashed: \(reason)")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red.opacity(0.8))
                        .clipShape(Capsule())
                        .padding(.bottom, 120)
                }
            } else if let toast = vm.toastMessage {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red.opacity(0.9))
                        .clipShape(Capsule())
                        .shadow(radius: 10)
                        .padding(.bottom, 120)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
    }
    
    private var backgroundGlow: some View {
        Group {
            if vm.simulationStatus == .success {
                Color.green.opacity(0.3).ignoresSafeArea()
            } else if case .failure = vm.simulationStatus {
                Color.red.opacity(0.3).ignoresSafeArea()
            } else {
                Color.clear
            }
        }
        .animation(.easeInOut(duration: 0.5), value: vm.simulationStatus)
    }
}

// MARK: - Help Instructions View
struct HelpInstructionsView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Canvas Controls")) {
                    InstructionRow(icon: "plus.circle", title: "Add a Node", desc: "Tap anywhere on the empty gray canvas to create a new State Node.")
                    InstructionRow(icon: "hand.tap", title: "Select Start/Accept", desc: "Tap a node once to set it as the START state. Double-tap to toggle it as an ACCEPTING state.")
                    InstructionRow(icon: "arrow.up.and.down.and.arrow.left.and.right", title: "Move Nodes", desc: "Turn OFF Draw Mode, then drag any node to move it freely around the board.")
                }
                
                Section(header: Text("Transitions")) {
                    InstructionRow(icon: "pencil.and.outline", title: "Draw a Transition", desc: "Turn ON Draw Mode, then drag from one node to another to draw a connecting edge.")
                    InstructionRow(icon: "arrow.triangle.2.circlepath", title: "Self-Loop", desc: "Turn ON Draw Mode, and drag from a node slightly outwards and back onto itself.")
                    InstructionRow(icon: "text.cursor", title: "Multiple Symbols", desc: "When prompted to add symbols for a transition, you can type multiple characters (e.g. '0,1') to accept either character along that path.")
                }
                
                Section(header: Text("Editing")) {
                    InstructionRow(icon: "contextualmenu.and.cursorarrow", title: "Delete Elements", desc: "Long-press any Node or Transition arrow to open the Context Menu and delete it.")
                }
            }
            .navigationTitle("How to Play")
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
        }
    }
}

struct InstructionRow: View {
    let icon: String
    let title: String
    let desc: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                Text(desc)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 5)
    }
}

// MARK: - StateNode View
struct StateNodeView: View {
    let node: StateNode
    @ObservedObject var vm: MachineViewModel
    let isDrawMode: Bool
    let onDrawEdge: (UUID, UUID) -> Void
    
    var isActive: Bool {
        vm.currentActiveNodeID == node.id
    }
    
    var body: some View {
        ZStack {
            
            if node.isStartState {
                HStack(spacing: 0) {
                    Text("START")
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.primary)
                        .foregroundColor(Color(UIColor.systemBackground))
                        .clipShape(Capsule())
                    
                    Rectangle()
                        .fill(Color.primary)
                        .frame(width: 15, height: 4)
                    
                    Image(systemName: "arrowtriangle.right.fill")
                        .resizable()
                        .frame(width: 14, height: 16)
                        .foregroundColor(.primary)
                }
                .offset(x: -75)
            }
            
            Circle()
                .fill(isActive ? Color.yellow : Color.blue)
                .frame(width: 60, height: 60)
                .shadow(color: isActive ? .yellow : .clear, radius: 10)
            
            if node.isAcceptingState {
                Circle()
                    .stroke(Color.primary, lineWidth: 2)
                    .frame(width: 70, height: 70)
            }
            
            Text(node.name)
                .font(.headline)
                .foregroundColor(.white)
        }
        .position(node.position)
        .onTapGesture(count: 2) {
            guard vm.simulationStatus != .running else { return }
            vm.toggleAcceptingState(for: node.id)
        }
        .onTapGesture {
            guard vm.simulationStatus != .running else { return }
            vm.setStartState(to: node.id)
        }
        .gesture(
            DragGesture(minimumDistance: 10)
                .onChanged { value in
                    guard vm.simulationStatus != .running else { return }
                    if isDrawMode {
                        vm.drawStartNodeID = node.id
                        vm.currentDragLocation = value.location
                    } else {
                        
                        vm.moveNode(id: node.id, to: value.location)
                    }
                }
                .onEnded { value in
                    guard vm.simulationStatus != .running else { return }
                    if isDrawMode {
                        
                        if let targetNode = vm.nodes.first(where: { distance($0.position, value.location) < 50 }) {
                            onDrawEdge(node.id, targetNode.id)
                        }
                        vm.drawStartNodeID = nil
                        vm.currentDragLocation = nil
                    }
                }
        )
        .contextMenu {
            Button(role: .destructive) {
                withAnimation {
                    vm.deleteNode(id: node.id)
                }
            } label: {
                Label("Delete Node", systemImage: "trash")
            }
            
            Button {
                vm.toggleAcceptingState(for: node.id)
            } label: {
                Label(node.isAcceptingState ? "Make Normal" : "Make Accepting", systemImage: node.isAcceptingState ? "minus.circle" : "checkmark.circle")
            }
            
            Button {
                vm.setStartState(to: node.id)
            } label: {
                Label("Set as Start State", systemImage: "arrowshape.turn.up.left")
            }
        }
    }
    
    private func distance(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        return hypot(p1.x - p2.x, p1.y - p2.y)
    }
}

// MARK: - TransitionEdge View
struct TransitionEdgeView: View {
    let transition: Transition
    @ObservedObject var vm: MachineViewModel
    
    var isActiveGroup: Bool {
        vm.currentActiveTransitionID == transition.id
    }
    
    var body: some View {
        
        let _ = vm.nodes
        let _ = vm.transitions
        
        guard let startNode = vm.nodes.first(where: { $0.id == transition.fromNodeID }),
              let endNode = vm.nodes.first(where: { $0.id == transition.toNodeID }) else {
            return AnyView(EmptyView())
        }
        
        let isSelfLoop = (startNode.id == endNode.id)
        
        let edgesInSameDirection = vm.transitions.filter { $0.fromNodeID == startNode.id && $0.toNodeID == endNode.id }
        let edgesInOppositeDirection = vm.transitions.filter { $0.fromNodeID == endNode.id && $0.toNodeID == startNode.id }
        let hasOpposite = !edgesInOppositeDirection.isEmpty
        let myIndex = edgesInSameDirection.firstIndex(where: { $0.id == transition.id }) ?? 0
        
        var baseOffset: CGFloat = 0
        if hasOpposite { 
            baseOffset = 40 + CGFloat(myIndex) * 40
        } else {
            if myIndex == 0 {
                baseOffset = 0
            } else {
                let magnitude = CGFloat((myIndex + 1) / 2) * 50
                baseOffset = (myIndex % 2 == 1) ? magnitude : -magnitude
            }
        }
        
        let isBidirectional = baseOffset != 0
        
        var loopNx: CGFloat = 0
        var loopNy: CGFloat = -1
        
        if isSelfLoop {
            var angles: [CGFloat] = []
            var connectedNodeIDs = Set<UUID>()
            
            if startNode.isStartState {
                
                angles.append(.pi)
            }
            
            for t in vm.transitions {
                if t.fromNodeID == startNode.id, t.toNodeID != startNode.id { connectedNodeIDs.insert(t.toNodeID) }
                if t.toNodeID == startNode.id, t.fromNodeID != startNode.id { connectedNodeIDs.insert(t.fromNodeID) }
            }
            
            for otherID in connectedNodeIDs {
                if let otherNode = vm.nodes.first(where: { $0.id == otherID }) {
                    let dx = otherNode.position.x - startNode.position.x
                    let dy = otherNode.position.y - startNode.position.y
                    angles.append(atan2(dy, dx))
                }
            }
            
            var uniqueAngles: [CGFloat] = []
            for a in angles.sorted() {
                if uniqueAngles.isEmpty || abs(uniqueAngles.last! - a) > 0.01 {
                    uniqueAngles.append(a)
                }
            }
            
            if uniqueAngles.isEmpty {
                loopNx = 0
                loopNy = -1
            } else if uniqueAngles.count == 1 {
                let opposite = uniqueAngles[0] + .pi
                loopNx = cos(opposite)
                loopNy = sin(opposite)
            } else {
                var maxGap: CGFloat = 0
                var bestAngle: CGFloat = 0
                for i in 0..<uniqueAngles.count {
                    let a1 = uniqueAngles[i]
                    let a2 = uniqueAngles[(i + 1) % uniqueAngles.count]
                    var gap = a2 - a1
                    if gap <= 0 { gap += 2 * .pi }
                    if gap > maxGap + 0.01 {
                        maxGap = gap
                        bestAngle = a1 + gap / 2
                    }
                }
                loopNx = cos(bestAngle)
                loopNy = sin(bestAngle)
            }
        }
        
        return AnyView(
            ZStack {
                if isSelfLoop {
                    let dist: CGFloat = 45 + CGFloat(myIndex) * 20
                    let r: CGFloat = 25 + CGFloat(myIndex) * 5
                    let loopCenter = CGPoint(x: startNode.position.x + loopNx * dist, y: startNode.position.y + loopNy * dist)

                    // Draw a loop above the node
                    Path { path in
                        path.addArc(center: loopCenter, radius: r, startAngle: .degrees(0), endAngle: .degrees(360), clockwise: false)
                    }
                    .stroke(isActiveGroup ? Color.orange : Color.primary, lineWidth: isActiveGroup ? 4 : 2)
                    
                    // Arrowhead for self-loop 
                    let orientationAngle = atan2(loopNy, loopNx)
                    let arrowPointAngle = orientationAngle + .pi / 2
                    let arrowPoint = CGPoint(x: loopCenter.x + cos(arrowPointAngle) * r, y: loopCenter.y + sin(arrowPointAngle) * r)
                    let arrowAngle = arrowPointAngle + .pi / 2
                    
                    ArrowHead(angle: arrowAngle) 
                        .fill(isActiveGroup ? Color.orange : Color.primary)
                        .frame(width: 24, height: 24)
                        .position(arrowPoint)
                    
                    // Symbols Label
                    let combinedSymbols = transition.symbols.map { String($0) }.joined(separator: ", ")
                    let labelPos = CGPoint(x: startNode.position.x + loopNx * (dist + r + 15), y: startNode.position.y + loopNy * (dist + r + 15))
                    
                    Text(combinedSymbols)
                        .font(.caption.bold())
                        .padding(5)
                        .background(isActiveGroup ? Color.orange : Color(white: 0.2))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white, lineWidth: 1))
                        .position(labelPos)
                    
                } else {
                    let p1 = startNode.position
                    let p2 = endNode.position
                    
                    let dx = p2.x - p1.x
                    let dy = p2.y - p1.y
                    let length = hypot(dx, dy)
                    
                    if length > 0 {
                        let nx = dx / length
                        let ny = dy / length
                        
                        
                        let radius: CGFloat = 35
                        let startP = CGPoint(x: p1.x + nx * radius, y: p1.y + ny * radius)
                        let endP = CGPoint(x: p2.x - nx * radius, y: p2.y - ny * radius)
                        
                        
                        let midP = CGPoint(x: (startP.x + endP.x) / 2, y: (startP.y + endP.y) / 2)
                        
                        let controlP = CGPoint(x: midP.x - ny * baseOffset, y: midP.y + nx * baseOffset)
                        
                        Path { path in
                            path.move(to: startP)
                            if isBidirectional {
                                path.addQuadCurve(to: endP, control: controlP)
                            } else {
                                path.addLine(to: endP)
                            }
                        }
                        .stroke(isActiveGroup ? Color.orange : Color.primary, lineWidth: isActiveGroup ? 4 : 2)
                        
                        
                        let arrowAngle = isBidirectional ? atan2(endP.y - controlP.y, endP.x - controlP.x) : atan2(dy, dx)
                        ArrowHead(angle: arrowAngle)
                            .fill(isActiveGroup ? Color.orange : Color.primary)
                            .frame(width: 24, height: 24)
                            .position(endP)
                        
                        // Symbols Label
                        let labelPos = isBidirectional ? 
                            CGPoint(
                                x: 0.25 * startP.x + 0.5 * controlP.x + 0.25 * endP.x,
                                y: 0.25 * startP.y + 0.5 * controlP.y + 0.25 * endP.y
                            ) : midP
                        
                        let combinedSymbols = transition.symbols.map { String($0) }.joined(separator: ", ")
                        Text(combinedSymbols)
                            .font(.caption.bold())
                            .padding(5)
                            .background(isActiveGroup ? Color.orange : Color(white: 0.2))
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white, lineWidth: 1))
                            .position(labelPos)
                    }
                }
            }
            .contentShape(Rectangle())
            .contextMenu {
                Button("Delete Transition(s)", role: .destructive) {
                    withAnimation {
                        vm.deleteTransition(id: transition.id)
                    }
                }
            }
        )
    }
}

struct ArrowHead: Shape {
    var angle: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let size: CGFloat = 12
        
        path.move(to: .zero)
        
        path.addLine(to: CGPoint(x: -size, y: -size/1.5))
        
        path.addLine(to: CGPoint(x: -size, y: size/1.5))
        
        path.closeSubpath()
        
        let transform = CGAffineTransform(rotationAngle: angle)
        
        let offset = CGAffineTransform(translationX: rect.midX, y: rect.midY)
        return path.applying(transform).applying(offset)
    }
}
