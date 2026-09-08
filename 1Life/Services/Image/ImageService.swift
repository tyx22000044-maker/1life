import UIKit

enum ImageService {
    static func compress(_ data: Data, maxBytes: Int = 1_000_000) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        var quality: CGFloat = 0.8
        var compressed = image.jpegData(compressionQuality: quality)
        while let d = compressed, d.count > maxBytes, quality > 0.1 {
            quality -= 0.1
            compressed = image.jpegData(compressionQuality: quality)
        }
        return compressed
    }

    static func thumbnail(_ data: Data, maxDimension: CGFloat = 200) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let ratio = min(maxDimension / image.size.width, maxDimension / image.size.height, 1.0)
        let newSize = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.6)
    }
}
