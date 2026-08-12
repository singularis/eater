import UIKit

extension UIImage {
  /// Draw the image so `imageOrientation` is baked into the pixel buffer.
  /// Camera JPEGs are often stored landscape with an EXIF flag; without this
  /// the server (and some `jpegData` paths) show the photo rotated 90°.
  func normalizedUp() -> UIImage {
    guard imageOrientation != .up else { return self }
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = scale
    format.opaque = false
    let renderer = UIGraphicsImageRenderer(size: size, format: format)
    return renderer.image { _ in
      draw(in: CGRect(origin: .zero, size: size))
    }
  }
}
