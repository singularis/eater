import Foundation

struct Product: Identifiable {
    let id = UUID()
    let name: String
    let proteins: Int
    let fats: Int
    let carbs: Int
}
