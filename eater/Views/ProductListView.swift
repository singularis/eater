import SwiftUI

struct ProductListView: View {
    let products: [Product]
    let onRefresh: () -> Void
    let onDelete: (Int64) -> Void
    let deletingProductTime: Int64?

    var body: some View {
        List {
            ForEach(products) { product in
                HStack {
                    VStack(alignment: .leading) {
                        Text(product.name)
                            .font(.headline)
                        Text("Calories: \(product.calories), Weight: \(product.weight), Ingredients: \(product.ingredients.joined(separator: ", "))")
                            .font(.subheadline)
                    }
                    
                    Spacer()
                    
                    if deletingProductTime == product.time {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .scaleEffect(0.8)
                    }
                }
                .opacity(deletingProductTime == product.time ? 0.6 : 1.0)
                .swipeActions {
                    Button {
                        onDelete(product.time)
                    } label: {
                        Text("Remove")
                    }
                    .tint(.red)
                    .disabled(deletingProductTime == product.time)
                }
            }
        }
        .refreshable {
            onRefresh()
        }
    }
}
