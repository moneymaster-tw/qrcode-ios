
import Foundation
import UIKit

public struct QRCode {
    public var url: URL
    public var correctionLevel: CorrectionLevel
    public var size: CGSize
    public var color: Color
    public var overlay: Overlay?
    
    public init(
        url: URL,
        correctionLevel: CorrectionLevel = .H,
        size: CGSize = CGSize(width: 300, height: 300),
        color: Color = Color(foreground: .black, background: .white),
        overlay: Overlay? = nil
    ) {
        self.url = url
        self.correctionLevel = correctionLevel
        self.size = size
        self.color = color
        self.overlay = overlay
    }
}
 
#if canImport(UIKit)
extension QRCode {
    /// The scale `image()` renders at: the highest display scale of current iPhones,
    /// so the image is sharp on every device whether it is shown on screen or saved.
    public static let defaultScale: CGFloat = 3

    /// Renders the QR code at `QRCode.defaultScale`.
    ///
    /// The returned image is `size` points large, so it can replace earlier
    /// versions' output as is.
    public func image() -> UIImage? {
        image(scale: Self.defaultScale)
    }

    /// Renders the QR code `size` points large at the given scale, i.e. with
    /// `size × scale` pixels.
    ///
    /// Modules are drawn with whole-pixel edges, all the same width, so they stay
    /// crisp. When `size × scale` is not a multiple of the module count, the pixels
    /// left over widen the quiet zone (filled with the background color). The
    /// overlay is drawn by UIKit at full pixel resolution, honouring its image
    /// orientation, from any kind of `UIImage`.
    ///
    /// - Parameter scale: Pixels per point. Pass a view's
    ///   `traitCollection.displayScale` to match its screen exactly.
    /// - Returns: `nil` if `scale` or `size` is not positive, or the QR code cannot
    ///   be generated.
    public func image(scale: CGFloat) -> UIImage? {
        guard scale > 0, scale.isFinite,
              size.width > 0, size.width.isFinite,
              size.height > 0, size.height.isFinite,
              let modules = ModuleMatrix(url: url, correctionLevel: correctionLevel) else {
            return nil
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        if #available(iOS 12.0, *) {
            format.preferredRange = .standard
        } else {
            format.prefersExtendedRange = false
        }
        let bounds = CGRect(origin: .zero, size: size)

        return UIGraphicsImageRenderer(bounds: bounds, format: format).image { context in
            let cgContext = context.cgContext

            color.background.setFill()
            cgContext.fill(bounds)

            cgContext.saveGState()
            cgContext.scaleBy(x: 1 / scale, y: 1 / scale)
            cgContext.setShouldAntialias(false)
            color.foreground.setFill()
            cgContext.fill(Self.darkModuleRects(
                of: modules,
                inPixelSize: CGSize(width: size.width * scale, height: size.height * scale)))
            cgContext.restoreGState()

            if let overlay = overlay {
                cgContext.interpolationQuality = .high
                overlay.image.draw(in: Self.overlayRect(proportion: overlay.sizeProportion, in: bounds))
            }
        }
    }

    /// The rects of the dark modules in pixels, top-left origin, one rect per
    /// horizontal run of dark modules.
    private static func darkModuleRects(of modules: ModuleMatrix, inPixelSize pixelSize: CGSize) -> [CGRect] {
        let horizontal = moduleLayout(count: modules.width, pixels: pixelSize.width)
        let vertical = moduleLayout(count: modules.height, pixels: pixelSize.height)

        var rects = [CGRect]()
        for y in 0..<modules.height {
            var x = 0
            while x < modules.width {
                guard modules[x, y] else { x += 1; continue }
                let runStart = x
                while x < modules.width && modules[x, y] { x += 1 }
                rects.append(CGRect(
                    x: horizontal.origin + CGFloat(runStart) * horizontal.length,
                    y: vertical.origin + CGFloat(y) * vertical.length,
                    width: CGFloat(x - runStart) * horizontal.length,
                    height: vertical.length))
            }
        }
        return rects
    }

    /// Module length and the offset that centres the modules, along one axis.
    /// Whole pixels when there is room for at least one pixel per module.
    private static func moduleLayout(count: Int, pixels: CGFloat) -> (origin: CGFloat, length: CGFloat) {
        let wholePixels = (pixels / CGFloat(count)).rounded(.down)
        guard wholePixels >= 1 else { return (0, pixels / CGFloat(count)) }
        let leftover = pixels.rounded(.down) - wholePixels * CGFloat(count)
        return ((leftover / 2).rounded(.down), wholePixels)
    }

    private static func overlayRect(proportion: CGFloat, in bounds: CGRect) -> CGRect {
        let factor = min(1, max(0, proportion))
        let overlaySize = CGSize(width: bounds.width * factor, height: bounds.height * factor)
        return CGRect(
            x: bounds.midX - overlaySize.width / 2,
            y: bounds.midY - overlaySize.height / 2,
            width: overlaySize.width,
            height: overlaySize.height)
    }
}
#endif
