import UIKit

extension UIImage {
  /// Shrink for upload. The backend resizes to 512x512 for the model anyway.
  func downscaledForUpload(maxLongEdge: CGFloat = 1536) -> UIImage {
    let pixelWidth = size.width * scale
    let pixelHeight = size.height * scale
    let longest = max(pixelWidth, pixelHeight)
    if longest <= maxLongEdge && imageOrientation == .up {
      return self
    }
    let ratio = min(1, maxLongEdge / max(longest, 1))
    let newSize = CGSize(width: max(1, (size.width * ratio).rounded()), height: max(1, (size.height * ratio).rounded()))
    let format = UIGraphicsImageRendererFormat.default()
    format.scale = 1
    format.opaque = false
    let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
    return renderer.image { _ in
      draw(in: CGRect(origin: .zero, size: newSize))
    }
  }

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
