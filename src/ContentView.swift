import SwiftUI
import MetalKit

struct ContentView: View {
    @StateObject var renderer = Renderer()
    @State private var isDropTargeted = false
    @State private var showHelp = false
    
    var body: some View {
        HSplitView {
            // LEFT: Metal Canvas
            ZStack {
                Color(nsColor: .windowBackgroundColor) // Base background
                
                MetalView(renderer: renderer)
                    .frame(minWidth: 400, maxWidth: .infinity, minHeight: 400, maxHeight: .infinity)
                
                // Overlay: Drop Zone Indicator (Only when dragging)
                if isDropTargeted {
                    ZStack {
                        Color.black.opacity(0.6)
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 4, dash: [10]))
                            .frame(width: 300, height: 200)
                        
                        VStack(spacing: 16) {
                            Image(systemName: "arrow.down.doc.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.accentColor)
                            Text("DROP BINARY FILE")
                                .font(.system(size: 24, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                    }
                } else if renderer.fileSize == 0 {
                    // Empty State Hint
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundColor(.gray)
                        Text("Drag & Drop a file to begin analyzing")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                }
                
                // Quick HUD (Bottom Left)
                VStack {
                    Spacer()
                    HStack {
                        HStack(spacing: 12) {
                            HUDItem(icon: "magnifyingglass", value: String(format: "%.2fx", renderer.zoom))
                            HUDItem(icon: "arrow.up.and.down.and.arrow.left.and.right", value: String(format: "%.0f, %.0f", renderer.offset.x, renderer.offset.y))
                            if renderer.fileSize > 0 {
                                HUDItem(icon: "doc.fill", value: ByteCountFormatter.string(fromByteCount: Int64(renderer.fileSize), countStyle: .file))
                            }
                        }
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .cornerRadius(8)
                        .padding()
                        
                        Spacer()
                    }
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                providers.first?.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (urlData, error) in
                    if let data = urlData as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        DispatchQueue.main.async {
                            renderer.loadFile(url: url)
                        }
                    }
                }
                return true
            }
            
            // RIGHT: Inspector Sidebar
            InspectorView(renderer: renderer)
                .frame(minWidth: 300, maxWidth: 500)
        }
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button(action: {
                    withAnimation {
                        renderer.zoom = 1.0
                        renderer.offset = SIMD2<Float>(0, 0)
                    }
                }) {
                    Label("Reset View", systemImage: "arrow.counterclockwise")
                }
                .disabled(renderer.fileSize == 0)
                
                Button(action: { showHelp.toggle() }) {
                    Label("Help & Legend", systemImage: "questionmark.circle")
                }
                .popover(isPresented: $showHelp) {
                    HelpView()
                }
            }
        }
    }
}

struct HUDItem: View {
    let icon: String
    let value: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.primary)
        }
    }
}

struct HelpView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("NeuroCore Guide")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("CONTROLS").font(.caption).bold().foregroundColor(.secondary)
                ControlRow(icon: "hand.draw", text: "Pan with 2 fingers")
                ControlRow(icon: "plus.magnifyingglass", text: "Pinch to Zoom")
                ControlRow(icon: "cursorarrow.click", text: "Hover to Inspect Bytes")
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("COLOR LEGEND").font(.caption).bold().foregroundColor(.secondary)
                LegendRow(color: .red, label: "High Entropy / Encrypted")
                LegendRow(color: .green, label: "Code / Structured Data")
                LegendRow(color: .blue, label: "Nulls / Padding / Zeroes")
                LegendRow(color: .cyan, label: "ASCII Text")
            }
        }
        .padding()
        .frame(width: 300)
    }
}

struct ControlRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundColor(.accentColor)
            Text(text)
                .font(.system(.body, design: .monospaced))
        }
    }
}

struct InspectorView: View {
    @ObservedObject var renderer: Renderer
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("DATA INSPECTOR")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding()
            .background(Color.black.opacity(0.8))
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // 0. File Info
                    InspectorSection(title: "FILE INFO") {
                        InfoRow(label: "TYPE", value: renderer.fileType)
                        if renderer.fileSize > 0 {
                            InfoRow(label: "SIZE", value: ByteCountFormatter.string(fromByteCount: Int64(renderer.fileSize), countStyle: .file))
                        } else {
                            Text("NO FILE LOADED").font(.caption).foregroundColor(.gray)
                        }
                    }
                    
                    Divider()
                    
                    if renderer.fileSize > 0 {
                        // 1. Coordinates / Offset
                        InspectorSection(title: "CURSOR LOCATION") {
                            let offset = renderer.selectedOffset ?? 0
                            InfoRow(label: "OFFSET (HEX)", value: String(format: "0x%08X", offset))
                            InfoRow(label: "OFFSET (DEC)", value: "\(offset)")
                        }
                        
                        Divider()
                        
                        // 2. Analysis
                        InspectorSection(title: "ENTROPY ANALYSIS") {
                            HStack {
                                Text("ENTROPY")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.gray)
                                Spacer()
                                Text(String(format: "%.4f", renderer.selectedEntropy))
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.bold)
                                    .foregroundColor(entropyColor(renderer.selectedEntropy))
                            }
                            // Bar
                            GeometryReader { g in
                                ZStack(alignment: .leading) {
                                    Rectangle().fill(Color.gray.opacity(0.2))
                                    Rectangle()
                                        .fill(entropyColor(renderer.selectedEntropy))
                                        .frame(width: g.size.width * CGFloat(renderer.selectedEntropy / 8.0))
                                }
                            }
                            .frame(height: 6)
                            .cornerRadius(3)
                        }
                        
                        Divider()
                        
                        // 3. Hex Dump
                        InspectorSection(title: "HEX PREVIEW (64 Bytes)") {
                            Text(renderer.selectedHexDump)
                                .font(.system(size: 10, weight: .regular, design: .monospaced))
                                .padding(8)
                                .background(Color.black.opacity(0.6)) // Darker for contrast
                                .foregroundColor(.green) // Classic terminal feel
                                .cornerRadius(6)
                        }
                        
                        // 4. Strings
                        if let s = renderer.selectedString {
                            Divider()
                            InspectorSection(title: "STRING PREVIEW") {
                                Text(s)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.yellow)
                                    .lineLimit(3)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }
    
    func entropyColor(_ val: Double) -> Color {
        if val > 7.0 { return .red }
        if val > 4.0 { return .green }
        return .blue
    }
}

struct InspectorSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.secondary)
            content
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
        }
    }
}

struct LegendRow: View {
    let color: Color
    let label: String
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.primary)
        }
    }
}
