import UIKit

enum PhotoFoodImagePreparer {
    /// Longest side: enough for food recognition, smaller upload/AI image tokens.
    static let uploadMaxPixelSize: CGFloat = 1536
    /// Prefer staying well under this for upload + provider latency.
    static let targetUploadBytes = 450 * 1024
    /// Hard server decoded JPEG limit.
    static let maxUploadBytes = 8 * 1024 * 1024

    static func prepareUploadJPEG(from image: UIImage) -> Data? {
        let oriented = image.normalizedForPhotoStorage()
        let resized = MealPhotoStore.downsampledImage(
            from: oriented,
            maxPixelSize: uploadMaxPixelSize
        )
        var quality: CGFloat = 0.74
        var data = resized.jpegData(compressionQuality: quality)
        while let current = data,
              (current.count > targetUploadBytes && quality > 0.52)
                || (current.count > maxUploadBytes && quality > 0.40) {
            quality -= 0.06
            data = resized.jpegData(compressionQuality: quality)
        }
        guard let data, !data.isEmpty, data.count <= maxUploadBytes else {
            return resized.jpegData(compressionQuality: 0.45)
        }
        return data
    }

    static func previewThumbnail(from image: UIImage) -> UIImage {
        MealPhotoStore.thumbnailImage(
            from: MealPhotoStore.downsampledImage(from: image, maxPixelSize: 512),
            sideLength: MealPhotoStore.formPreviewPixelSize
        )
    }
}
