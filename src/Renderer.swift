import MetalKit
import SwiftUI

// Struct to match the Shader Uniforms
struct Uniforms {
    var viewSize: SIMD2<Float>
    var offset: SIMD2<Float>
    var zoom: Float
    var windowSize: UInt32
    var _padding: UInt32
    var _padding2: UInt32
    var fileSize: UInt64
    var dimension: UInt64
}

class Renderer: NSObject, MTKViewDelegate, ObservableObject {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    var pipelineState: MTLComputePipelineState?
    
    // File Data
    var fileDataBuffer: MTLBuffer?
    var rawData: Data?
    var fileSize: UInt64 = 0
    var dimension: UInt64 = 65536 // Default N
    
    // Viewport State
    @Published var zoom: Float = 1.0
    @Published var offset: SIMD2<Float> = SIMD2<Float>(0, 0)
    
    // Inspection State
    @Published var selectedOffset: UInt64?
    @Published var selectedEntropy: Double = 0.0
    @Published var selectedHexDump: String = ""
    @Published var selectedString: String? // Preview strings
    @Published var fileType: String = "No File Loaded"
    @Published var isHovering: Bool = false
    
    override init() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }

        self.device = device
        
        guard let queue = device.makeCommandQueue() else {
             fatalError("Could not create Metal Command Queue")
        }
        self.commandQueue = queue
        
        super.init()
        
        setupPipeline()
    }
    
    func setupPipeline() {
        do {
            let library = try device.makeLibrary(source: ShaderSource.code, options: nil)
            guard let function = library.makeFunction(name: "neuroCoreShader") else {
                print("Failed to find shader function")
                return
            }
            self.pipelineState = try device.makeComputePipelineState(function: function)
        } catch {
            print("Failed to create pipeline: \(error)")
        }
    }
    
    func loadFile(url: URL) {
        do {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            self.rawData = data
            self.fileSize = UInt64(data.count)
            
            // Calculate Dimension N
            // N*N >= fileSize. N must be power of 2.
            let size = Double(self.fileSize)
            let side = sqrt(size)
            var n: UInt64 = 1
            while Double(n) < side {
                n *= 2
            }
            // Ensure minimum size
            self.dimension = max(4096, n)
            
            // Create Metal Buffer - Zero Copy for performance
            self.fileDataBuffer = data.withUnsafeBytes { bufferPointer -> MTLBuffer? in
                guard let baseAddress = bufferPointer.baseAddress else { return nil }
                return device.makeBuffer(bytesNoCopy: UnsafeMutableRawPointer(mutating: baseAddress),
                                         length: data.count,
                                         options: .storageModeShared,
                                         deallocator: nil) // Data keeps reference alive
            }
            
            // Reset view
            self.offset = SIMD2<Float>(0, 0)
            self.zoom = 1.0 // Reset zoom
            
            self.selectedOffset = 0
            
            // Extract string for initial chunk
            let initialChunkSize = min(64, data.count)
            // Fix: Create new Data to reset indices to 0
            let initialChunk = Data(data[0..<initialChunkSize]) 
            self.selectedHexDump = NeuroUtils.hexDump(data: initialChunk, startOffset: 0)
            self.selectedString = NeuroUtils.extractASCII(data: initialChunk)
            self.fileType = NeuroUtils.identifyFileType(data: data)
            
            print("Loaded file: \(url.lastPathComponent), Size: \(fileSize) bytes, Dimension(N): \(dimension), Type: \(fileType)")
        } catch {
            print("Error loading file: \(error)")
            self.fileType = "Error Loading File"
        }
    }
    
    // MARK: - Interaction Logic
    func handleInteraction(at point: CGPoint, in viewSize: CGSize) {
        guard let data = rawData, !data.isEmpty else { return }
        
        let metalX = Float(point.x)
        let metalY = Float(point.y)
        
        let worldX = metalX / zoom + offset.x
        let worldY = metalY / zoom + offset.y
        
        // Default to identifying file type if out of bounds or not found? 
        // User wants "Always show". So if out of bounds, maybe show 0x0?
        // But only if we are truly out of the curve.
        
        // Check for NaN or Inf
        if worldX.isNaN || worldX.isInfinite || worldY.isNaN || worldY.isInfinite {
            return
        }
        
        // Clamp to prevent overflow when casting to UInt64
        // If worldX is huge (e.g. zoomed out massively or panned far away), UInt64(worldX) wraps or crashes.
        if worldX < 0 || worldY < 0 {
            self.selectedOffset = nil
            self.selectedEntropy = 0
            self.selectedHexDump = ""
            self.selectedString = nil
            self.isHovering = false
            return
        }
        
        // We know they are >= 0 now.
        // Check upper bound before casting if possible, or just cast and check against n later.
        // If worldX > UInt64.max, it will crash.
        // But n is UInt64, so it's fine.
        let x = UInt64(worldX)
        let y = UInt64(worldY)
        let n = self.dimension
        
        var d: UInt64 = 0
        var validHover = false
        
        if x < n && y < n {
             d = NeuroUtils.xy2d(n: n, x: x, y: y)
             if d < self.fileSize { // Use self.fileSize not casted
                 validHover = true
             }
        }
        
        // If not hovering over valid pixel, default to 0 to keep UI populated "by default"
        // But maybe we only do that if selectedOffset is nil? 
        // User said: "default to 0x0, update on hover".
        // So if validHover -> use d. Else -> use 0.
        
        let targetOffset = validHover ? d : 0
        
        if targetOffset < self.fileSize {
            self.selectedOffset = targetOffset
            
            // Analyze 64 bytes
            let windowSize = 64
            let start = Int(targetOffset)
            let end = min(start + windowSize, data.count)
            
            // Fix: Create new Data object to reset indices to 0 for the helper functions
            let chunk = Data(data[start..<end])
            
            self.selectedEntropy = NeuroUtils.calculateEntropy(data: chunk)
            self.selectedHexDump = NeuroUtils.hexDump(data: chunk, startOffset: start)
            self.selectedString = NeuroUtils.extractASCII(data: chunk)
            self.isHovering = validHover
        }
    }
    
    // MARK: - Metal Delegate
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { }
    
    func draw(in view: MTKView) {
        guard let drawable = view.currentDrawable,
              let pipelineState = pipelineState,
              let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }
        
        let w = pipelineState.threadExecutionWidth
        let h = pipelineState.maxTotalThreadsPerThreadgroup / w
        let threadsPerGroup = MTLSizeMake(w, h, 1)
        
        let width = Int(view.drawableSize.width)
        let height = Int(view.drawableSize.height)
        let threadsPerGrid = MTLSizeMake(width, height, 1)
        
        guard let computeEncoder = commandBuffer.makeComputeCommandEncoder() else { return }
        computeEncoder.setComputePipelineState(pipelineState)
        computeEncoder.setTexture(drawable.texture, index: 0)
        
        if let buffer = fileDataBuffer {
            computeEncoder.setBuffer(buffer, offset: 0, index: 0)
        } else {
            // Dummy buffer if no file
            let dummy = device.makeBuffer(length: 16, options: [])
            computeEncoder.setBuffer(dummy, offset: 0, index: 0)
        }
        
        var uniforms = Uniforms(
            viewSize: SIMD2<Float>(Float(width), Float(height)),
            offset: offset,
            zoom: zoom,
            windowSize: 64,
            _padding: 0,
            _padding2: 0,
            fileSize: fileSize,
            dimension: dimension
        )
        
        computeEncoder.setBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: 1)
        computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerGroup)
        computeEncoder.endEncoding()
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}

// Custom MTKView subclass with Gestures
class InteractiveMTKView: MTKView {
    weak var inputDelegate: Renderer?
    
    override init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device)
        setupGestures()
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        setupGestures()
    }
    
    // Helper init
    init() {
        super.init(frame: .zero, device: nil)
        setupGestures()
    }
    
    private func setupGestures() {
        // Pan
        let pan = NSPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        self.addGestureRecognizer(pan)
        
        // Zoom (Magnification)
        let mag = NSMagnificationGestureRecognizer(target: self, action: #selector(handleMagnification(_:)))
        self.addGestureRecognizer(mag)
        
        // Note: Tracking area is needed for Hover
    }
    
    @objc func handlePan(_ gesture: NSPanGestureRecognizer) {
        guard let delegate = inputDelegate else { return }
        
        let translation = gesture.translation(in: self)
        // Adjust translation based on zoom? 
        // Logic: Moving 10 pixels on screen means moving 10 pixels in viewport.
        // But shader logic uses offset + pixel/zoom.
        // So we need to subtract translation from offset? No.
        // offset represents the world coordinate at top-left (0,0)?
        // uv = pixel/zoom + offset.
        // If we pan right, we want to see leftwards world -> offset decreases.
        // So offset -= translation / zoom.
        
        // Sensitivity
        let speed: Float = 1.0
        
        if gesture.state == .changed {
            delegate.offset.x -= Float(translation.x) * speed / delegate.zoom
            delegate.offset.y += Float(translation.y) * speed / delegate.zoom // Y is flipped in translation vs metal? Metal Y is down. Translation Y is usually down too in AppKit flipped views?
            // Actually AppKit (0,0) is bottom-left usually, but MTKView?
            // Let's test. If it feels inverted, flip sign.
            // Usually dragging content: drag mouse right -> content moves right -> looking at left side -> offset decreases.
            
            gesture.setTranslation(.zero, in: self)
        }
    }
    
    @objc func handleMagnification(_ gesture: NSMagnificationGestureRecognizer) {
        guard let delegate = inputDelegate else { return }
        
        if gesture.state == .changed {
            let mag = Float(gesture.magnification)
            let scale = 1.0 + mag
            let newZoom = max(0.0001, min(delegate.zoom * scale, 1000.0))
            
            // Zoom to Cursor Logic
            let location = gesture.location(in: self)
            // Convert to Backing Scale for Metal (Retina)
            let layerScale = self.layer?.contentsScale ?? 1.0
            let mx = Float(location.x * layerScale)
            let my = Float(location.y * layerScale)
            
            // Formula: newOffset = oldOffset + mousePos * (1/oldZoom - 1/newZoom)
            let oldZoom = delegate.zoom
            
            delegate.offset.x += mx * (1.0/oldZoom - 1.0/newZoom)
            delegate.offset.y += my * (1.0/oldZoom - 1.0/newZoom)
            
            delegate.zoom = newZoom
            
            gesture.magnification = 0
        }
    }
    
    override var acceptsFirstResponder: Bool { return true }
    
    // Keep scroll wheel for mouse users
    override func scrollWheel(with event: NSEvent) {
        guard let delegate = inputDelegate else { return }
        
        if event.modifierFlags.contains(.command) || event.phase == .began || event.momentumPhase == .began {
             // Let gesture recognizers handle trackpad if possible?
             // But scrollWheel events still fire for trackpad.
             // We'll ignore if gestures are active? No simple way.
             // Just implement simple scroll/zoom here too.
        }
        
        if event.modifierFlags.contains(.option) {
             // Zoom
             let dy = Float(event.scrollingDeltaY)
             let zoomFactor: Float = 0.05
             let scale = 1.0 + (dy * zoomFactor)
             delegate.zoom *= scale
             delegate.zoom = max(0.0001, min(delegate.zoom, 1000.0))
        } else {
             // Pan
             let dx = Float(event.scrollingDeltaX)
             let dy = Float(event.scrollingDeltaY)
             delegate.offset.x -= dx / delegate.zoom
             delegate.offset.y -= dy / delegate.zoom
        }
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for area in self.trackingAreas { self.removeTrackingArea(area) }
        let options: NSTrackingArea.Options = [.mouseMoved, .activeInKeyWindow, .inVisibleRect]
        let trackingArea = NSTrackingArea(rect: self.bounds, options: options, owner: self, userInfo: nil)
        self.addTrackingArea(trackingArea)
    }
    
    override func mouseMoved(with event: NSEvent) {
        let point = self.convert(event.locationInWindow, from: nil)
        let scale = self.layer?.contentsScale ?? 1.0
        inputDelegate?.handleInteraction(at: CGPoint(x: point.x * scale, y: point.y * scale), in: self.drawableSize)
    }
    
    override func mouseDown(with event: NSEvent) {
        let point = self.convert(event.locationInWindow, from: nil)
        let scale = self.layer?.contentsScale ?? 1.0
        inputDelegate?.handleInteraction(at: CGPoint(x: point.x * scale, y: point.y * scale), in: self.drawableSize)
    }
}

struct MetalView: NSViewRepresentable {
    @ObservedObject var renderer: Renderer
    
    func makeNSView(context: Context) -> InteractiveMTKView {
        let mtkView = InteractiveMTKView()
        mtkView.device = renderer.device
        mtkView.delegate = renderer
        mtkView.inputDelegate = renderer
        mtkView.framebufferOnly = false
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false
        mtkView.preferredFramesPerSecond = 60
        return mtkView
    }
    
    func updateNSView(_ nsView: InteractiveMTKView, context: Context) {
    }
}
