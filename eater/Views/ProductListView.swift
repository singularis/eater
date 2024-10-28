import SwiftUI

struct ProductListView: View {
    let products: [Product]

    var body: some View {
        List(products) { product in
            VStack(alignment: .leading) {
                Text(product.name)
                Text("Proteins: \(product.proteins), Fats: \(product.fats), Carbs: \(product.carbs)")
            }
        }
    }
}
