import SwiftUI

struct ProductListView: View {
    let products: [Product]
    let onRefresh: () -> Void // Add a closure to handle refresh

    var body: some View {
        List(products) { product in
            VStack(alignment: .leading) {
                Text(product.name)
                Text("Calories: \(product.calories), Weight: \(product.weight),  Ingredients: \(product.ingredients.joined(separator: ", "))")
            }
        }
        .refreshable {
            onRefresh()
        }
    }
}
