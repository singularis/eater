import SwiftUI

struct FullScreenPhotoView: View {
    let image: UIImage?
    let foodName: String
    @Binding var isPresented: Bool
    let onDismiss: (() -> Void)?
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastScaleValue: CGFloat = 1.0
    
    init(image: UIImage?, foodName: String, isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil) {
        self.image = image
        self.foodName = foodName
        self._isPresented = isPresented
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        ZStack {
            Color.black
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                // Header with food name and close button
                HStack {
                    Text(foodName)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.leading)
                    
                    Spacer()
                    
                    Button(action: {
                        if let dismiss = onDismiss {
                            dismiss()
                        } else {
                            isPresented = false
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding(.trailing)
                }
                .padding(.top, 10)
                
                Spacer()
                
                // Photo display
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .clipped()
                        .onTapGesture(count: 2) {
                            // Double tap to reset zoom
                            withAnimation(.spring()) {
                                scale = 1.0
                                offset = .zero
                            }
                        }
                        .gesture(
                            SimultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let delta = value / lastScaleValue
                                        lastScaleValue = value
                                        let newScale = scale * delta
                                        scale = max(0.5, min(newScale, 4.0))
                                    }
                                    .onEnded { _ in
                                        lastScaleValue = 1.0
                                        if scale < 1.0 {
                                            withAnimation(.spring()) {
                                                scale = 1.0
                                                offset = .zero
                                            }
                                        }
                                    },
                                
                                DragGesture()
                                    .onChanged { value in
                                        if scale > 1.0 {
                                            offset = value.translation
                                        }
                                    }
                                    .onEnded { _ in
                                        if scale <= 1.0 {
                                            withAnimation(.spring()) {
                                                offset = .zero
                                            }
                                        }
                                    }
                            )
                        )
                } else {
                    // No image placeholder
                    VStack(spacing: 20) {
                        Image(systemName: "photo")
                            .font(.system(size: 80))
                            .foregroundColor(.gray)
                        
                        Text("No photo available")
                            .font(.title3)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                // Instructions text
                Text("Double tap to reset • Pinch to zoom • Drag to pan")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.bottom, 20)
            }
        }
        .onAppear {
            scale = 1.0
            offset = .zero
            lastScaleValue = 1.0
        }
    }
} 