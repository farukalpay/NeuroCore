import Foundation

enum NeuroUtils {
    // Inverse Hilbert Curve Logic (XY -> d)
    // Matches the shader logic for consistency.
    // N must be a power of 2. For our 'infinite' canvas concept, we used N=65536 in shader.
    // Inverse Hilbert Curve Logic (XY -> d)
    // Matches the shader logic for consistency.
    static func xy2d(n: UInt64, x: UInt64, y: UInt64) -> UInt64 {
        var rx: Int64 = 0
        var ry: Int64 = 0
        var s: Int64 = Int64(n / 2)
        var d: Int64 = 0
        var tx = Int64(x)
        var ty = Int64(y)
        
        while s > 0 {
            rx = (tx & s) > 0 ? 1 : 0
            ry = (ty & s) > 0 ? 1 : 0
            
            // Safe calculation for d addition
            // d += s * s * ((3 * rx) ^ ry)
            let weighting = (3 * rx) ^ ry
            d += s * s * weighting
            
            rot(n: s, x: &tx, y: &ty, rx: rx, ry: ry)
            s /= 2
        }
        return UInt64(max(0, d))
    }
    
    static func rot(n: Int64, x: inout Int64, y: inout Int64, rx: Int64, ry: Int64) {
        if ry == 0 {
            if rx == 1 {
                x = n - 1 - x
                y = n - 1 - y
            }
            // Swap x and y
            let t = x
            x = y
            y = t
        }
    }
    
    // Calculate Shannon Entropy for a byte array
    static func calculateEntropy(data: Data) -> Double {
        if data.isEmpty { return 0.0 }
        
        var counts = [Int](repeating: 0, count: 256)
        for byte in data {
            counts[Int(byte)] += 1
        }
        
        var entropy: Double = 0.0
        let total = Double(data.count)
        
        for count in counts {
            if count > 0 {
                let p = Double(count) / total
                entropy -= p * log2(p)
            }
        }
        
        return entropy
    }
    
    // Format data as Hex Dump
    // 00000000  12 34 56 78 90 AB CD EF  12 34 56 78 90 AB CD EF  |.4Vx......4Vx...|
    static func hexDump(data: Data, startOffset: Int) -> String {
        var output = ""
        let bytesPerLine = 16
        let lines = (data.count + bytesPerLine - 1) / bytesPerLine
        
        for i in 0..<lines {
            let offset = i * bytesPerLine
            let end = min(offset + bytesPerLine, data.count)
            let chunk = data[offset..<end]
            
            // Address
            output += String(format: "%08X  ", startOffset + offset)
            
            // Hex Bytes
            var hexString = ""
            for (index, byte) in chunk.enumerated() {
                hexString += String(format: "%02X ", byte)
                if index == 7 { hexString += " " }
            }
            // Padding if incomplete line
            let remainingBytes = bytesPerLine - chunk.count
            if remainingBytes > 0 {
                hexString += String(repeating: "   ", count: remainingBytes)
                if chunk.count <= 8 { hexString += " " }
            }
            output += hexString + " |"
            
            // ASCII
            var asciiString = ""
            for byte in chunk {
                if byte >= 32 && byte <= 126 {
                    asciiString += String(UnicodeScalar(byte))
                } else {
                    asciiString += "."
                }
            }
            output += asciiString + "|\n"
        }
        return output
    }
    // Identify File Type via Magic Bytes
    static func identifyFileType(data: Data) -> String {
        if data.count < 4 { return "Unknown Data" }
        
        // Helper to check prefix
        func hasPrefix(_ bytes: [UInt8]) -> Bool {
            if data.count < bytes.count { return false }
            for (i, b) in bytes.enumerated() {
                if data[i] != b { return false }
            }
            return true
        }
        
        // Signatures
        if hasPrefix([0x4D, 0x5A]) { return "Windows PE (EXE/DLL)" }
        if hasPrefix([0x7F, 0x45, 0x4C, 0x46]) { return "ELF Binary" }
        if hasPrefix([0xFE, 0xED, 0xFA, 0xCE]) || hasPrefix([0xCE, 0xFA, 0xED, 0xFE]) || hasPrefix([0xCA, 0xFE, 0xBA, 0xBE]) { return "Mach-O Binary" }
        if hasPrefix([0x25, 0x50, 0x44, 0x46]) { return "PDF Document" }
        if hasPrefix([0x50, 0x4B, 0x03, 0x04]) { return "ZIP Archive / Office" }
        if hasPrefix([0x89, 0x50, 0x4E, 0x47]) { return "PNG Image" }
        if hasPrefix([0xFF, 0xD8, 0xFF]) { return "JPEG Image" }
        if hasPrefix([0x52, 0x61, 0x72, 0x21]) { return "RAR Archive" }
        if hasPrefix([0x1F, 0x8B]) { return "GZIP Archive" }
        
        return "Unknown Binary"
    }
    
    // Extract first printable ASCII string (len > 4) in chunk
    static func extractASCII(data: Data) -> String? {
        var currentString = ""
        for byte in data {
            if byte >= 32 && byte <= 126 {
                currentString.append(Character(UnicodeScalar(byte)))
            } else {
                if currentString.count > 4 {
                    return currentString
                }
                currentString = ""
            }
        }
        return currentString.count > 4 ? currentString : nil
    }
}
