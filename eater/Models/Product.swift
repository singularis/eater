import Foundation
import UIKit

struct Product: Identifiable {
    let id = UUID()
    let time: Int64
    let name: String
    let calories: Int
    let weight: Int
    let ingredients: [String]
    
    var image: UIImage? {
        return ImageStorageService.shared.loadImage(forTime: time)
    }
    
    var hasImage: Bool {
        return ImageStorageService.shared.imageExists(forTime: time)
    }
}
