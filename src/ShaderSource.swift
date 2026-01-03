import Foundation

struct ShaderSource {
    static let code = """
    #include <metal_stdlib>
    using namespace metal;
    
    struct Uniforms {
        float2 viewSize;     // Size of the Metal view in pixels
        float2 offset;       // Pan offset
        float zoom;          // Zoom level
        uint windowSize;
        uint _padding;
        uint _padding2;      // Explicit padding to reach 32 bytes alignment for ulong
        ulong fileSize;       
        ulong dimension;      // Hilbert Dimension N 
    };
    
    // Rotate/Flip a quadrant
    void rot(ulong n, thread ulong &x, thread ulong &y, ulong rx, ulong ry) {
        if (ry == 0) {
            if (rx == 1) {
                x = n - 1 - x;
                y = n - 1 - y;
            }
            ulong t = x; x = y; y = t;
        }
    }
    
    // Convert (x,y) to d (distance along curve)
    // Uses ulong (64-bit) to support d > 4,294,967,295 (4GB)
    ulong xy2d(ulong n, ulong x, ulong y) {
        ulong rx, ry, s, d = 0;
        for (s = n / 2; s > 0; s /= 2) {
            rx = (x & s) > 0;
            ry = (y & s) > 0;
            d += s * s * ((3 * rx) ^ ry);
            rot(s, x, y, rx, ry); // Pass 's' as the sub-quadrant size logic
        }
        return d;
    }
    
    // Forensic Analysis Color Mapping
    float3 analyze_bytes(device const uchar *data, uint fileSize, ulong index) {
        if (index >= fileSize) return float3(0.05, 0.05, 0.05);
        
        uint window = 64; 
        // Ensure we don't read past buffer
        ulong end = index + window;
        if (end > fileSize) end = fileSize;
        
        uint count = uint(end - index);
        if (count == 0) return float3(0.05, 0.05, 0.05);
        
        uint textChars = 0;
        uint highBits = 0;
        uint nulls = 0;
        uint variation = 0;
        
        for (uint i = 0; i < count; i++) {
            uchar b = data[index + i];
            if (b >= 32 && b <= 126) textChars++;
            if (b > 127) highBits++;
            if (b == 0) nulls++;
            if (i > 0) {
                int diff = (int)b - (int)data[index + i - 1];
                variation += abs(diff);
            }
        }
        
        float pText = float(textChars) / float(count);
        float pHigh = float(highBits) / float(count);
        float pNull = float(nulls) / float(count);
        float avgVar = float(variation) / float(count); 
        float entropy = avgVar / 128.0; 
        
        // --- Forensic Color Legend ---
        
        // 1. Padding / Zeroes -> Deep Blue / Black
        if (pNull > 0.9) {
            return float3(0.0, 0.0, 0.2 + 0.3 * pNull);
        }
        
        // 3. High Entropy / Encryption -> Red / Orange
        if (entropy > 0.5 && pHigh > 0.25) {
            // Vary red based on intensity
            return float3(1.0, 0.0, 0.0);
        }

        // 2. ASCII Text -> Cyan tint, but keep entropy structure
        if (pText > 0.85) {
             // Use entropy to drive brightness/saturation so we see structure
             return float3(0.0, 0.8 * entropy + 0.2, 0.8 * entropy + 0.2);
        }
        
        // 4. Code / Machine Instructions -> Green spectrum
        // Often has moderate entropy but specific structure
        return float3(0.0, 0.5 + 0.5 * entropy, 0.0);
    }
    
    kernel void neuroCoreShader(
        texture2d<float, access::write> outTexture [[texture(0)]],
        device const uchar *fileData [[buffer(0)]],
        constant Uniforms &uniforms [[buffer(1)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= outTexture.get_width() || gid.y >= outTexture.get_height()) {
            return;
        }
        
        // View Transform
        // Screen Pixel -> World Coordinate
        float2 uv = float2(gid) / uniforms.zoom + uniforms.offset;
        
        // OOB check
        if (uv.x < 0 || uv.y < 0) {
            outTexture.write(float4(0.05, 0.05, 0.05, 1), gid);
            return;
        }
        
        ulong x = ulong(uv.x);
        ulong y = ulong(uv.y);
        ulong n = ulong(uniforms.dimension);
        
        if (x >= n || y >= n) {
             outTexture.write(float4(0.05, 0.05, 0.05, 1), gid); 
             return;
        }
        
        ulong d = xy2d(n, x, y);
        
        // Check file bounds
        if (d < ulong(uniforms.fileSize)) {
            float3 c = analyze_bytes(fileData, uniforms.fileSize, d);
            outTexture.write(float4(c, 1.0), gid);
        } else {
            outTexture.write(float4(0.05, 0.05, 0.05, 1), gid);
        }
    }
    """
}
