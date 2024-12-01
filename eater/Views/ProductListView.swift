import SwiftUI

struct ProductListView: View {
    let products: [Product]
    let onRefresh: () -> Void
    let onDelete: (Int64) -> Void // Change to accept Int64

    var body: some View {
        List {
            ForEach(products) { product in
                VStack(alignment: .leading) {
                    Text(product.name)
                        .font(.headline)
                    Text("Calories: \(product.calories), Weight: \(product.weight), Ingredients: \(product.ingredients.joined(separator: ", "))")
                        .font(.subheadline)
                }
                .swipeActions {
                    Button {
                        onDelete(product.time)
                    } label: {
                        Text("Remove")
                    }
                    .tint(.red)
                }
            }
        }
        .refreshable {
            onRefresh()
        }
    }
}
