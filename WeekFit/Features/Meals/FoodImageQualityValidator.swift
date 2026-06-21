import UIKit

enum FoodImageQualityValidator {

  private static let minimumAverageLuminance: CGFloat = 0.12
  private static let sampleSide = 12

  private static let rejectedAssetNames: Set<String> = [
    "plate-dark",
    "plate_dark",
  ]

  private static var assetCache: [String: Bool] = [:]
  private static var imageCache = NSCache<NSString, NSNumber>()

  static func isDisplayableAsset(named name: String) -> Bool {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return false }

    if let cached = assetCache[trimmed] {
      return cached
    }

    guard !isPlaceholderAssetName(trimmed) else {
      assetCache[trimmed] = false
      return false
    }

    guard let image = UIImage(named: trimmed) else {
      assetCache[trimmed] = false
      return false
    }

    let isValid = isDisplayable(image)
    assetCache[trimmed] = isValid
    return isValid
  }

  static func isDisplayable(_ image: UIImage) -> Bool {
    let key = NSString(string: ObjectIdentifier(image).debugDescription)
    if let cached = imageCache.object(forKey: key) {
      return cached.boolValue
    }

    let isValid = validate(image)
    imageCache.setObject(NSNumber(value: isValid), forKey: key)
    return isValid
  }

  static func isPlaceholderAssetName(_ name: String) -> Bool {
    let lower = name.lowercased()
    if rejectedAssetNames.contains(lower) { return true }
    if lower.contains("placeholder") { return true }
    return false
  }

  private static func validate(_ image: UIImage) -> Bool {
    guard let cgImage = image.cgImage else { return false }
    guard cgImage.width >= 8, cgImage.height >= 8 else { return false }
    guard let luminance = averageLuminance(of: image) else { return false }
    return luminance >= minimumAverageLuminance
  }

  private static func averageLuminance(of image: UIImage) -> CGFloat? {
    let size = CGSize(width: sampleSide, height: sampleSide)

    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    format.opaque = true

    let sample = UIGraphicsImageRenderer(size: size, format: format).image { context in
      UIColor.white.setFill()
      context.fill(CGRect(origin: .zero, size: size))
      image.draw(in: CGRect(origin: .zero, size: size))
    }

    guard let cgImage = sample.cgImage else { return nil }

    let width = cgImage.width
    let height = cgImage.height
    let bytesPerPixel = 4
    let bytesPerRow = bytesPerPixel * width
    let totalBytes = height * bytesPerRow

    var pixelData = [UInt8](repeating: 0, count: totalBytes)
    guard let context = CGContext(
      data: &pixelData,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: bytesPerRow,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
      return nil
    }

    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    var totalLuminance: CGFloat = 0
    let pixelCount = width * height

    for index in stride(from: 0, to: pixelData.count, by: bytesPerPixel) {
      let red = CGFloat(pixelData[index]) / 255
      let green = CGFloat(pixelData[index + 1]) / 255
      let blue = CGFloat(pixelData[index + 2]) / 255
      totalLuminance += (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
    }

    return totalLuminance / CGFloat(pixelCount)
  }
}
