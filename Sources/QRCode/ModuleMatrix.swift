
import CoreImage
import CoreGraphics

/// The modules of a QR code symbol, one entry per module, including the quiet zone
/// that `CIQRCodeGenerator` adds around the symbol.
struct ModuleMatrix {
    let width: Int
    let height: Int
    private let darkModules: [Bool]

    private static let context = CIContext()

    init?(url: URL, correctionLevel: CorrectionLevel) {
        // A new filter per call: CIFilter instances are not safe to share between threads.
        guard let generator = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        generator.setValue(Data(url.absoluteString.utf8), forKey: "inputMessage")
        generator.setValue(correctionLevel.rawValue, forKey: "inputCorrectionLevel")

        // The generator outputs one pixel per module, dark modules black on white.
        guard let output = generator.outputImage,
              let modulesImage = Self.context.createCGImage(output, from: output.extent),
              let bitmap = CGContext(
                data: nil,
                width: modulesImage.width,
                height: modulesImage.height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceGray(),
                bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
            return nil
        }

        let width = modulesImage.width
        let height = modulesImage.height
        bitmap.interpolationQuality = .none
        bitmap.draw(modulesImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let data = bitmap.data else { return nil }

        // Bitmap memory starts with the top row.
        let bytes = data.bindMemory(to: UInt8.self, capacity: bitmap.bytesPerRow * height)
        var darkModules = [Bool]()
        darkModules.reserveCapacity(width * height)
        for y in 0..<height {
            for x in 0..<width {
                darkModules.append(bytes[y * bitmap.bytesPerRow + x] < 128)
            }
        }

        self.width = width
        self.height = height
        self.darkModules = darkModules
    }

    /// Whether the module at the given column and row (top-left origin) is dark.
    subscript(x: Int, y: Int) -> Bool {
        darkModules[y * width + x]
    }
}
