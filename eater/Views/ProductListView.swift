import SwiftUI

struct ProductListView: View {
    let products: [Product]
    let onRefresh: () -> Void
    let onDelete: (Int64) -> Void
    let onModify: (Int64, String, Int32) -> Void
    let onPhotoTap: (UIImage?, String) -> Void
    let deletingProductTime: Int64?
    let onShareSuccess: () -> Void

    var sortedProducts: [Product] {
        products.sorted { $0.time > $1.time }
    }

    var body: some View {
        List {
            ForEach(sortedProducts) { product in
                HStack(spacing: 12) {
                    // Food photo - clickable for full screen
                    if let image = product.image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipped()
                            .cornerRadius(8)
                            .onTapGesture {
                                if deletingProductTime != product.time {
                                    onPhotoTap(image, product.name)
                                }
                            }
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                            )
                            .onTapGesture {
                                if deletingProductTime != product.time {
                                    // Try to get image using fallback mechanism
                                    let image = product.image
                                    onPhotoTap(image, product.name)
                                }
                            }
                    }
                    
                    // Food details - clickable for portion modification
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
                    .onTapGesture {
                        AlertHelper.showPortionSelectionAlert(foodName: product.name, originalWeight: product.weight, time: product.time, onPortionSelected: { percentage in
                            onModify(product.time, product.name, percentage)
                        }, onShareSuccess: onShareSuccess)
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
        .scrollContentBackground(.hidden)
        .listStyle(.plain)
        .padding(.top, -2)
        .refreshable {
            onRefresh()
        }
    }
}
