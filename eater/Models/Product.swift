import Foundation

struct Product: Identifiable {
    let id = UUID()
    let time: Int64
    let name: String
    let calories: Int
    let weight: Int
    let ingredients: [String]
}
