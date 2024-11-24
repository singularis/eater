import Foundation

struct Product: Identifiable {
    let id = UUID()
    let name: String
    let calories: Int
    let weight: Int
}
