# NeuroCore

NeuroCore is a high-performance, native macOS utility designed for structural binary analysis and visualization. By leveraging Metal Compute Shaders, the application performs real-time mapping of raw binary data onto a Hilbert Curve, enabling rapid visual identification of file structures, entropy distribution, and data anomalies.

If you find this tool useful for reverse engineering or security research, please consider starring the repository.

//..

## Overview

Traditional hex editors provide a linear view of data, which makes spotting large-scale patterns or structural irregularities difficult. NeuroCore addresses this by projecting binary data into a 2D space using a Hilbert Space-Filling Curve. This transformation preserves data locality, meaning bytes adjacent in the linear stream remain adjacent in the 2D visualization.

The rendering pipeline is fully accelerated via the GPU, utilizing custom Metal kernels to compute Shannon Entropy and pixel color values on-the-fly. This architecture allows for the smooth visualization of arbitrarily large files without the memory overhead associated with generating static textures.

## Key Features

* **Hardware-Accelerated Rendering:** Utilizes Metal Compute Shaders (MSL) to offload heavy entropy calculations and coordinate mapping to the GPU, ensuring 60fps performance even with large datasets.
* **Hilbert Curve Mapping:** Transforms linear data into a 2D topography that preserves locality, making structural boundaries visually distinct.
* **Entropy-Based Visualization:** Applies a sliding window heuristic to calculate local entropy, color-coding data segments to identify content type:
    * **Red:** High Entropy (Encrypted data, compressed archives, high-randomness sequences).
    * **Blue/Green:** Low to Mid Entropy (Machine code, plain text, headers, structured data).
    * **Black:** Zero blocks (Null padding).
* **Zero-Allocation Navigation:** Implements a "Virtual Window" technique within the shader pipeline. Offsets are calculated dynamically, allowing users to pan and zoom through gigabytes of data instantly without buffering the entire file into VRAM.

## Technical Architecture

NeuroCore is built as a native macOS application using Swift 5.5+ and direct Metal API calls.

* **Language:** Swift
* **UI Framework:** SwiftUI (with `NSViewRepresentable` bridging).
* **Graphics API:** Metal (Compute & Graphics Pipelines).
* **Core Modules:**
    * `Renderer.swift`: Manages the `MTLDevice`, command queues, pipeline state objects (PSO), and direct memory buffers.
    * `ShaderSource.swift`: Contains the embedded Metal Shading Language kernel responsible for the parallel computation of the Hilbert mapping and entropy levels.
    * `ContentView.swift`: Handles the view hierarchy and user input events.

## Installation and Build

This project relies on standard macOS frameworks and does not require external package managers. You can build the application directly from the source using the Swift compiler.

**Prerequisites:**
* macOS 12.0 or later (Apple Silicon recommended for optimal shader performance).
* Xcode Command Line Tools installed.

**Build Command:**

Execute the following command in the project root to compile the source files and link the required frameworks (SwiftUI, Metal, MetalKit, AppKit, Foundation):

```bash
swiftc NeuroCoreApp.swift ContentView.swift Renderer.swift ShaderSource.swift Utils.swift -o NeuroCore -sdk $(xcrun --show-sdk-path) -target arm64-apple-macos12.0 -framework SwiftUI -framework Metal -framework MetalKit -framework AppKit -framework Foundation

```

**Run:**

```bash
./NeuroCore

```

## Usage

**1. Data Ingestion**
Drag and drop any binary file (executables, disk images, archives, etc.) directly onto the application window. The visualization will update immediately.

**2. Navigation**

* **Pan:** Use the scroll wheel or trackpad to traverse the file structure.
* **Zoom:** Hold the `Option` key while scrolling to adjust the zoom level (bytes per pixel).

//screenshot of drag and drop interaction or zooming detail

## Use Cases

* **Reverse Engineering:** Quickly locate specific sections within a binary, such as encrypted payloads hidden within a wrapper or `.text` code sections.
* **Malware Analysis:** visually identify packed or obfuscated regions which typically manifest as high-entropy blocks distinct from standard compiled code.
* **Forensics & Steganography:** Detect anomalies or appended data at the end of files (EOF) that disrupt the expected visual pattern.
* **Data Validation:** Verify the uniformity of random number generators or the effectiveness of compression algorithms visually.

## License

All rights reserved. No commercial use allowed.
