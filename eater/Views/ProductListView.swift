import SwiftUI

struct ProductListView: View {
    let products: [Product]
    let onRefresh: () -> Void
    let onDelete: (Int64) -> Void
    let onModify: (Int64, String, Int32) -> Void
    let deletingProductTime: Int64?

    var sortedProducts: [Product] {
        products.sorted { $0.time > $1.time }
    }

    var body: some View {
        List {
            ForEach(sortedProducts) { product in
                HStack(spacing: 12) {
                    // Food photo
                    if let image = product.image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipped()
                            .cornerRadius(8)
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.name)
                            .font(.headline)
                        
                        Text("\(product.calories) kcal • \(product.weight)g")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(product.ingredients.joined(separator: ", "))
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    if deletingProductTime == product.time {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .scaleEffect(0.8)
                    }
                }
                .padding(.vertical, 8)
                .opacity(deletingProductTime == product.time ? 0.6 : 1.0)
                .onTapGesture {
                    AlertHelper.showPortionSelectionAlert(foodName: product.name) { percentage in
                        onModify(product.time, product.name, percentage)
                    }
                }
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
