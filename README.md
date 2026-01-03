# NeuroCore

<p align="center">
  <strong>High-Performance Structural Binary Analysis and Visualization Utility</strong>
</p>

---

## Abstract

NeuroCore is a native macOS utility engineered for the structural analysis of binary data through high-velocity visualization. By leveraging General-Purpose Computing on Graphics Processing Units (GPGPU) via Metal Compute Shaders, the application maps raw binary streams onto a Hilbert Space-Filling Curve in real-time. This projection facilitates the rapid identification of file taxonomy, entropy distribution, and cryptographic anomalies, addressing the limitations of linear hexadecimal representation.

## Introduction

Traditional hex editors present binary data in a linear, offset-based format, which obscures macro-scale structural patterns and data density. NeuroCore addresses this heuristic gap by projecting linear data into a two-dimensional topological space.

The core projection relies on the **Hilbert Curve**, a continuous fractal space-filling curve. This mathematical transformation preserves **spatial locality**: data points that are adjacent in the linear memory stream remain strictly adjacent in the 2D visualization. This property allows analysts to visually parse the structural composition of a file—distinguishing between machine code, structured text, bitmaps, and high-entropy blocks—without parsing the file header.

## Technical Architecture

NeuroCore is architected as a high-performance native application, bypassing intermediate abstraction layers to interact directly with the GPU.

* **Language:** Swift 5.5+ (Strict Concurrency)
* **Graphics Pipeline:** Metal API (Compute & Render Command Encoders)
* **Interface:** SwiftUI with `NSViewRepresentable` bridging for metal layers.

### Rendering Pipeline
The rendering engine utilizes a custom Metal Shading Language (MSL) kernel to execute parallel computation of Shannon Entropy and coordinate mapping.
1.  **Ingestion:** Raw binary data is streamed into `MTLBuffer` objects.
2.  **Compute:** The GPU executes a sliding-window entropy calculation across the buffer.
3.  **Mapping:** Linear offsets are transformed into $(x, y)$ coordinates using bitwise Hilbert mapping algorithms.
4.  **Rasterization:** Pixel fragments are colored dynamically based on local entropy variance, achieving 60fps performance on arbitrarily large datasets without VRAM thrashing.

---

## Visual Data Analysis and Interpretation

The following case studies demonstrate NeuroCore's efficacy in distinguishing file structures through entropy visualization.

<br>

<p align="center">
  <img src="https://github.com/farukalpay/NeuroCore/blob/main/img/img1.png?raw=true" alt="JSON Data Structure Analysis" width="100%">
  <br>
  <em>Figure 1: Visualization of a 17.7 MB Unidentified Binary (Identified as Hierarchical JSON)</em>
</p>

### Case Study I: Low-Entropy Hierarchical Data
**Subject:** 17.7 MB file classified as "Unknown" by the operating system.

* **Entropy Signature (Low/Mid):** The visualization is dominated by the **green/teal spectrum**, indicative of an entropy score of $\approx 2.0 - 4.0$. Unlike encrypted blobs, this spectrum denotes high redundancy and predictability within the data stream.
* **Topological Features:** The distinct geometric segmentation and "blocky" artifacts along the Hilbert Curve are characteristic of **pretty-printed text**. Solid regions represent recurring byte sequences (e.g., whitespace indentation, repeated keys), while scattered variations represent value changes.
* **Conclusion:** The visual topography confirms the file is a **non-compressed, hierarchical text structure** (JSON dataset) rather than a compiled executable, nullifying the need for initial hex inspection.

<br>
<hr>
<br>

<p align="center">
  <img src="https://github.com/farukalpay/NeuroCore/blob/main/img/img2.png?raw=true" alt="Compressed Binary Analysis" width="100%">
  <br>
  <em>Figure 2: Visualization of a 192 MB Apple Disk Image (.dmg)</em>
</p>

### Case Study II: High-Entropy Compressed Archives
**Subject:** 192 MB `.dmg` volume.

* **Entropy Signature (High):** The saturation of **red pixel data** signifies maximum entropy ($\approx 7.5 - 8.0$ bits per byte). While visually interpreted as "noise," this stochastic distribution indicates the effective elimination of data redundancy.
* **Texture Uniformity:** The visualization lacks the geometric "islands" seen in Figure 1. Compression algorithms (e.g., LZFSE, zlib) distribute byte values uniformly to maximize storage efficiency, resulting in a field of high variance.
* **Conclusion:** This visual density is the distinct signature of **packed executables, encrypted volumes, or compressed archives**. In a forensic context, observing this signature in a file purporting to be a standard document would immediately suggest steganographic payload injection or encryption.

---

## Key Features

* **Hardware-Accelerated Compute:** Offloads entropy heuristics and coordinate transformation to the GPU via Metal Compute Shaders, ensuring real-time navigation.
* **Hilbert Locality Preservation:** Transforms linear streams into 2D topography while maintaining neighbor relationships, making structural boundaries visually explicit.
* **Entropy-Based Colorimetry:**
    * **Red:** High Entropy (Encryption, Compression, RNG output).
    * **Blue/Green:** Low-Mid Entropy (x86/ARM64 machine code, Text, Headers).
    * **Black:** Null Space (Zero padding/allocation).
* **Virtual Windowing:** Implements a zero-allocation navigation system. Offsets are calculated dynamically within the shader, allowing immediate traversal of gigabyte-scale files without pre-buffering full datasets into VRAM.

## Use Cases

1.  **Reverse Engineering:** Rapid localization of `.text` sections, embedded resources, or encrypted payloads within binary wrappers.
2.  **Malware Analysis:** Visual identification of packers and obfuscation layers, which manifest as high-entropy anomalies distinct from standard compiled logic.
3.  **Digital Forensics:** Detection of appended data (EOF overlays) or steganographic modifications that disrupt expected file structure patterns.
4.  **Cryptographic Validation:** Visual verification of Random Number Generator (RNG) uniformity and compression algorithm efficiency.

## Installation and Build

This project utilizes the native macOS toolchain and requires no external package managers.

**Prerequisites:**
* macOS 12.0 (Monterey) or higher.
* Apple Silicon (M1/M2/M3) architecture recommended for optimal shader throughput.
* Xcode Command Line Tools.

**Compilation:**

Execute the following command in the project root to invoke the Swift compiler and link required frameworks (`SwiftUI`, `Metal`, `MetalKit`, `AppKit`, `Foundation`):

```bash
swiftc NeuroCoreApp.swift ContentView.swift Renderer.swift ShaderSource.swift Utils.swift \
-o NeuroCore \
-sdk $(xcrun --show-sdk-path) \
-target arm64-apple-macos12.0 \
-framework SwiftUI \
-framework Metal \
-framework MetalKit \
-framework AppKit \
-framework Foundation

```

**Execution:**

```bash
./NeuroCore

```

## Usage

1. **Data Ingestion:** Drag and drop any binary target directly onto the visualization viewport. Rendering is instantaneous.
2. **Navigation:**
* **Pan:** Two-finger scroll (trackpad) or scroll wheel.
* **Zoom:** Hold `Option` + Scroll to adjust the byte-per-pixel density.



## License

**All rights reserved.**
Unauthorized commercial use, redistribution, or modification is strictly prohibited.
