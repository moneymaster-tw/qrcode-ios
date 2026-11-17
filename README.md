# QRCode

A package providing API that makes generating QRCode image easier. It facilitates APIs provided by UIKit (CIFilter, CIImage), therefore, only iOS platform is supported.

This package is maintained by Money Master for internal use in the company's iOS apps.

## Usage

```swift
let qrCode = QRCode(
    url: url,
    size: CGSize(width: 220, height: 220),
    overlay: Overlay(image: logo, sizeProportion: 36 / 220))

imageView.image = qrCode.image()                                        // 3x, sharp on every iPhone
imageView.image = qrCode.image(scale: view.traitCollection.displayScale) // match a screen exactly
```

The image is `size` points large and rendered at `scale` pixels per point (`QRCode.defaultScale`, 3, by default). Modules have whole-pixel edges of equal width; pixels left over when `size × scale` is not a multiple of the module count widen the quiet zone. The overlay is drawn by UIKit at full resolution, so any `UIImage` works, including vector assets, rotated images and images without a `cgImage`.
