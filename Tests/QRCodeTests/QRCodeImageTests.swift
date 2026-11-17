//
//  QRCodeImageTests.swift
//

import XCTest
@testable import QRCode

final class QRCodeImageTests: XCTestCase {
    private let size = CGSize(width: 200, height: 200)
    private let overlayEdgeLength: CGFloat = 32
    private let scale: CGFloat = 3

    // MARK: - Size and scale

    func test_image_hasRequestedPointSizeAndScale() throws {
        let image = try XCTUnwrap(makeQRCode(overlay: solidOverlay()).image(scale: scale))

        XCTAssertEqual(image.size, size)
        XCTAssertEqual(image.scale, scale)
        XCTAssertEqual(image.cgImage?.width, Int(size.width * scale))
        XCTAssertEqual(image.cgImage?.height, Int(size.height * scale))
    }

    func test_imageWithoutScale_rendersAtDefaultScale() throws {
        let image = try XCTUnwrap(makeQRCode().image())

        XCTAssertEqual(QRCode.defaultScale, 3)
        XCTAssertEqual(image.size, size)
        XCTAssertEqual(image.scale, QRCode.defaultScale)
    }

    func test_image_returnsNilForInvalidScaleOrSize() {
        XCTAssertNil(makeQRCode().image(scale: 0))
        XCTAssertNil(makeQRCode().image(scale: -1))
        XCTAssertNil(makeQRCode().image(scale: .infinity))
        XCTAssertNil(makeQRCode(size: .zero).image(scale: scale))
        XCTAssertNil(makeQRCode(size: CGSize(width: 100, height: -1)).image(scale: scale))
    }

    // MARK: - Modules

    func test_image_withoutOverlay_hasOnlyForegroundAndBackgroundPixels() throws {
        let image = try XCTUnwrap(makeQRCode().image(scale: scale))

        XCTAssertEqual(try otherPixelCount(in: image, besides: [Self.black, Self.white]), 0)
    }

    func test_image_paintsModulesInGivenColors() throws {
        let qrCode = makeQRCode(color: Color(foreground: .blue, background: .yellow))
        let image = try XCTUnwrap(qrCode.image(scale: scale))
        let pixels = try RGBAPixels(image)

        XCTAssertEqual(try otherPixelCount(in: image, besides: [Self.blue, Self.yellow]), 0)
        XCTAssertEqual(pixels[0, 0], Self.yellow, "quiet zone")
        XCTAssertTrue(pixels.contains(Self.blue))
    }

    func test_image_keepsTransparentBackground() throws {
        let qrCode = makeQRCode(color: Color(foreground: .black, background: .clear))
        let pixels = try RGBAPixels(try XCTUnwrap(qrCode.image(scale: scale)))

        XCTAssertEqual(pixels[0, 0], Self.clear)
        XCTAssertTrue(pixels.contains(Self.black))
    }

    func test_image_drawsModulesOfEqualWholePixelWidth_whenSizeIsNotAMultipleOfModuleCount() throws {
        // 220 pt is the size the apps show; at 3x, 660 px is not a multiple of the module count.
        for scale: CGFloat in [1, 2, 3] {
            let qrCode = makeQRCode(size: CGSize(width: 220, height: 220))
            let pixels = try RGBAPixels(try XCTUnwrap(qrCode.image(scale: scale)))
            let moduleCount = try XCTUnwrap(ModuleMatrix(url: url, correctionLevel: .H)).width
            let modulePixels = pixels.width / moduleCount
            XCTAssertNotEqual(pixels.width % moduleCount, 0, "precondition at \(scale)x")

            for y in stride(from: 0, to: pixels.height, by: 7) {
                for run in pixels.runs(inRow: y).dropFirst().dropLast() {
                    XCTAssertEqual(run % modulePixels, 0, "run of \(run) px in row \(y) at \(scale)x")
                }
            }
        }
    }

    // MARK: - Overlay

    func test_image_drawsOverlayAtFullPixelResolution() throws {
        let image = try XCTUnwrap(makeQRCode(overlay: pixelStripedOverlay()).image(scale: scale))
        let pixels = try RGBAPixels(image)
        let centre = Int(size.width * scale) / 2

        XCTAssertEqual(pixels[centre, centre], Self.red, "column \(centre)")
        XCTAssertEqual(pixels[centre + 1, centre], Self.blue, "column \(centre + 1)")
    }

    func test_image_keepsModulesPureOutsideOverlay() throws {
        let image = try XCTUnwrap(makeQRCode(overlay: solidOverlay()).image(scale: scale))
        let overlayPixels = Int((size.width - overlayEdgeLength) / 2 * scale)
            ..< Int((size.width + overlayEdgeLength) / 2 * scale)

        let count = try otherPixelCount(in: image, besides: [Self.black, Self.white]) { x, y in
            overlayPixels.contains(x) && overlayPixels.contains(y)
        }
        XCTAssertEqual(count, 0)
    }

    func test_image_drawsOverlayInItsImageOrientation() throws {
        // Stored left half red, right half blue; `.right` displays it rotated 90° clockwise,
        // so it shows red on top and blue at the bottom.
        let stored = overlayImage { context, bounds in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: bounds.width / 2, height: bounds.height))
            UIColor.blue.setFill()
            context.fill(CGRect(x: bounds.width / 2, y: 0, width: bounds.width / 2, height: bounds.height))
        }
        let rotated = UIImage(cgImage: try XCTUnwrap(stored.cgImage), scale: scale, orientation: .right)

        let pixels = try RGBAPixels(try XCTUnwrap(makeQRCode(overlay: rotated).image(scale: scale)))
        let centre = Int(size.width * scale) / 2
        let quarter = Int(overlayEdgeLength * scale) / 4

        XCTAssertEqual(pixels[centre, centre - quarter], Self.red, "top")
        XCTAssertEqual(pixels[centre, centre + quarter], Self.blue, "bottom")
    }

    func test_image_drawsOverlayWithoutCGImage() throws {
        let ciImage = CIImage(color: CIColor(red: 1, green: 0, blue: 0))
            .cropped(to: CGRect(x: 0, y: 0, width: 10, height: 10))
        let overlay = UIImage(ciImage: ciImage)
        XCTAssertNil(overlay.cgImage, "precondition")

        let pixels = try RGBAPixels(try XCTUnwrap(makeQRCode(overlay: overlay).image(scale: scale)))
        let centre = Int(size.width * scale) / 2

        XCTAssertEqual(pixels[centre, centre], Self.red)
    }

    func test_image_clampsOverlaySizeProportion() throws {
        let covering = makeQRCode(overlay: solidOverlay(), proportion: 1.5)
        let coveringPixels = try RGBAPixels(try XCTUnwrap(covering.image(scale: scale)))
        XCTAssertEqual(coveringPixels[0, 0], Self.red)
        XCTAssertEqual(coveringPixels[coveringPixels.width - 1, coveringPixels.height - 1], Self.red)

        let hidden = makeQRCode(overlay: solidOverlay(), proportion: -0.5)
        let hiddenImage = try XCTUnwrap(hidden.image(scale: scale))
        XCTAssertEqual(try otherPixelCount(in: hiddenImage, besides: [Self.black, Self.white]), 0)
    }

    // MARK: - Decoding

    func test_image_decodesToURL() throws {
        let cases: [(String, QRCode, CIQRCodeDescriptor.ErrorCorrectionLevel)] = [
            ("overlay", makeQRCode(overlay: solidOverlay()), .levelH),
            ("no overlay", makeQRCode(), .levelH),
            ("colors", makeQRCode(color: Color(foreground: .blue, background: .yellow)), .levelH),
            ("level L", makeQRCode(correctionLevel: .L), .levelL),
            ("220 pt", makeQRCode(size: CGSize(width: 220, height: 220)), .levelH),
        ]
        for (name, qrCode, level) in cases {
            for scale: CGFloat in [1, 2, 3] {
                let image = try XCTUnwrap(qrCode.image(scale: scale), name)
                let feature = try decode(image)
                XCTAssertEqual(feature.messageString, url.absoluteString, "\(name) at \(scale)x")
                XCTAssertEqual(feature.symbolDescriptor?.errorCorrectionLevel, level, "\(name) at \(scale)x")
            }
        }
    }

    // MARK: - Helpers

    private let url = URL(string: "https://example.com/business-card?referral=REF0001")!

    private static let red = RGBA(r: 255, g: 0, b: 0, a: 255)
    private static let blue = RGBA(r: 0, g: 0, b: 255, a: 255)
    private static let yellow = RGBA(r: 255, g: 255, b: 0, a: 255)
    private static let black = RGBA(r: 0, g: 0, b: 0, a: 255)
    private static let white = RGBA(r: 255, g: 255, b: 255, a: 255)
    private static let clear = RGBA(r: 0, g: 0, b: 0, a: 0)

    private func makeQRCode(
        size: CGSize? = nil,
        correctionLevel: CorrectionLevel = .H,
        color: Color = Color(foreground: .black, background: .white),
        overlay: UIImage? = nil,
        proportion: CGFloat? = nil
    ) -> QRCode {
        let size = size ?? self.size
        return QRCode(
            url: url,
            correctionLevel: correctionLevel,
            size: size,
            color: color,
            overlay: overlay.map { Overlay(image: $0, sizeProportion: proportion ?? overlayEdgeLength / size.width) })
    }

    private func decode(_ image: UIImage, file: StaticString = #filePath, line: UInt = #line) throws -> CIQRCodeFeature {
        let detector = try XCTUnwrap(CIDetector(
            ofType: CIDetectorTypeQRCode,
            context: nil,
            options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]), file: file, line: line)
        let features = detector.features(in: CIImage(cgImage: try XCTUnwrap(image.cgImage, file: file, line: line)))
        XCTAssertEqual(features.count, 1, file: file, line: line)
        return try XCTUnwrap(features.first as? CIQRCodeFeature, "detected \(features.count) features", file: file, line: line)
    }

    private func otherPixelCount(
        in image: UIImage,
        besides allowed: Set<RGBA>,
        excluding isExcluded: (Int, Int) -> Bool = { _, _ in false }
    ) throws -> Int {
        let pixels = try RGBAPixels(image)
        var count = 0
        for y in 0..<pixels.height {
            for x in 0..<pixels.width where !isExcluded(x, y) && !allowed.contains(pixels[x, y]) {
                count += 1
            }
        }
        return count
    }

    private func solidOverlay() -> UIImage {
        overlayImage { context, bounds in
            UIColor.red.setFill()
            context.fill(bounds)
        }
    }

    /// Alternating red/blue columns one device pixel wide: they survive only if the
    /// overlay is drawn at full pixel resolution; any resampling blends them.
    private func pixelStripedOverlay() -> UIImage {
        overlayImage { context, bounds in
            let pixelWidth = 1 / scale
            for column in 0..<Int(bounds.width * scale) {
                (column.isMultiple(of: 2) ? UIColor.red : UIColor.blue).setFill()
                context.fill(CGRect(x: CGFloat(column) * pixelWidth, y: 0, width: pixelWidth, height: bounds.height))
            }
        }
    }

    private func overlayImage(_ draw: (CGContext, CGRect) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.preferredRange = .standard
        let bounds = CGRect(origin: .zero, size: CGSize(width: overlayEdgeLength, height: overlayEdgeLength))
        return UIGraphicsImageRenderer(bounds: bounds, format: format).image { draw($0.cgContext, bounds) }
    }
}

private struct RGBA: Hashable {
    let r, g, b, a: UInt8
}

private struct RGBAPixels {
    let width: Int
    let height: Int
    private let bytes: [UInt8]

    init(_ image: UIImage, file: StaticString = #filePath, line: UInt = #line) throws {
        let cgImage = try XCTUnwrap(image.cgImage, file: file, line: line)
        width = cgImage.width
        height = cgImage.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let context = try XCTUnwrap(CGContext(
            data: &bytes,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue), file: file, line: line)
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        self.bytes = bytes
    }

    /// Top-left origin, matching UIKit.
    subscript(x: Int, y: Int) -> RGBA {
        let offset = (y * width + x) * 4
        return RGBA(r: bytes[offset], g: bytes[offset + 1], b: bytes[offset + 2], a: bytes[offset + 3])
    }

    func contains(_ pixel: RGBA) -> Bool {
        (0..<height).contains { y in (0..<width).contains { x in self[x, y] == pixel } }
    }

    /// Lengths of the runs of identical pixels along a row, left to right.
    func runs(inRow y: Int) -> [Int] {
        var runs = [Int]()
        var length = 1
        for x in 1..<width {
            if self[x, y] == self[x - 1, y] {
                length += 1
            } else {
                runs.append(length)
                length = 1
            }
        }
        runs.append(length)
        return runs
    }
}
